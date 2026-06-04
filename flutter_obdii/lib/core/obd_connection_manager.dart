// Port of OBDConnectionManager.swift — Jim Mittler
// Main OBD-II connection manager singleton.
// Manages vehicle communication via flutter_obd2 library, connection lifecycle,
// and continuous PID data streaming. Integrates with PIDInterestRegistry for
// demand-driven polling. Publishes connection state, diagnostic codes, fuel
// status, MIL status, and per-PID statistics.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'package:permission_handler/permission_handler.dart';

import 'config_data.dart';
import 'logger.dart';
import 'pid_interest_registry.dart';

// ─────────────────────────────────────────────
// MARK: ConnectionState
// ─────────────────────────────────────────────

enum OBDConnectionState {
  disconnected,
  connecting,
  connectedToAdapter,
  settingUpVehicle,
  connected,
  failed,
}

// ─────────────────────────────────────────────
// MARK: PIDStats
// ─────────────────────────────────────────────

class PIDStats {
  final String pid;
  final obd2lib.MeasurementResult latest;
  final double min;
  final double max;
  final int sampleCount;

  PIDStats({required this.pid, required this.latest})
      : min = latest.value,
        max = latest.value,
        sampleCount = 1;

  // Private full constructor used by copyWith
  const PIDStats._({
    required this.pid,
    required this.latest,
    required this.min,
    required this.max,
    required this.sampleCount,
  });

  /// Returns a NEW PIDStats instance with accumulated min/max/sampleCount.
  /// Using a new object (not mutation) is critical: GaugesViewModel's
  /// _tilesEqual() compares stats by value, but when the same object is
  /// mutated both old and new tiles see identical fields and updates are
  /// silently dropped.
  PIDStats copyWith(obd2lib.MeasurementResult measurement) {
    final v = measurement.value;
    return PIDStats._(
      pid: pid,
      latest: measurement,
      min: v < min ? v : min,
      max: v > max ? v : max,
      sampleCount: sampleCount + 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PIDStats &&
      other.pid == pid &&
      other.latest.value == latest.value &&
      other.min == min &&
      other.max == max &&
      other.sampleCount == sampleCount;

  @override
  int get hashCode => Object.hash(pid, latest.value, min, max, sampleCount);
}


// ─────────────────────────────────────────────
// MARK: Provider protocols (replaces Swift protocols)
// ─────────────────────────────────────────────

abstract class PidStatsProviding {
  Map<String, PIDStats> get pidStats;
  PIDStats? statsFor(String pidCommand);
  Stream<Map<String, PIDStats>> get pidStatsStream;
}

abstract class DiagnosticsProviding {
  List<obd2lib.TroubleCodeMetadata>? get troubleCodes;
  Stream<List<obd2lib.TroubleCodeMetadata>?> get diagnosticsStream;
}

abstract class FuelStatusProviding {
  List<obd2lib.StatusCodeMetadata?>? get fuelStatus;
  Stream<List<obd2lib.StatusCodeMetadata?>?> get fuelStatusStream;
}

abstract class MilStatusProviding {
  obd2lib.Status? get milStatus;
  Stream<obd2lib.Status?> get milStatusStream;
}

abstract class OBDConnectionControlling {
  OBDConnectionState get connectionState;
  void updateConnectionDetails();
  Future<void> connect();
  void disconnect();
  Stream<OBDConnectionState> get connectionStateStream;
}

// ─────────────────────────────────────────────
// MARK: OBDConnectionManager singleton
// ─────────────────────────────────────────────

class OBDConnectionManager extends ChangeNotifier
    implements
        PidStatsProviding,
        DiagnosticsProviding,
        FuelStatusProviding,
        MilStatusProviding,
        OBDConnectionControlling {
  static final OBDConnectionManager instance = OBDConnectionManager._();
  OBDConnectionManager._();
  static const bool _querySupportedPids = true;

  /// When non-null (tests only), skips the real FlutterBluePlus lookup.
  @visibleForTesting
  static Future<bool> Function()? debugBluetoothIsSupportedOverride;

  /// When non-null (tests only), skips waiting on [FlutterBluePlus.adapterState].
  @visibleForTesting
  static Future<BluetoothAdapterState> Function()?
      debugBluetoothInitialAdapterStateOverride;

  // ── Published state ─────────────────────────────

  @override
  OBDConnectionState connectionState = OBDConnectionState.disconnected;

  /// Current DTCs. null = not yet received, [] = loaded but none.
  @override
  List<obd2lib.TroubleCodeMetadata>? troubleCodes;

  /// FI/O2 fuel system status. null = not yet received.
  @override
  List<obd2lib.StatusCodeMetadata?>? fuelStatus;

  /// MIL/Check Engine status. null = not yet received.
  @override
  obd2lib.Status? milStatus;

  /// Bluetooth peripheral name, or null for WiFi/Demo.
  String? connectedPeripheralName;

  @override
  Map<String, PIDStats> pidStats = {};

  // ── Internal ─────────────────────────────────────

  obd2lib.Obd2Service? _obdService;
  StreamSubscription? _connectionStateSub;
  StreamSubscription? _dataSub;
  StreamSubscription? _interestSub;
  StreamSubscription? _unitsSub;
  Set<String> _lastStreamingPids = {};
  Set<String> _supportedMode1Pids = {};
  bool _hasSupportedMode1Snapshot = false;
  int _connectionAttemptId = 0;

  // ── Notifiers (replaces Combine @Published) ──────

  final _connStateNotifier =
      ValueNotifier<OBDConnectionState>(OBDConnectionState.disconnected);
  final _pidStatsNotifier = ValueNotifier<Map<String, PIDStats>>({});

  @override
  Stream<OBDConnectionState> get connectionStateStream =>
      _valueNotifierStream(_connStateNotifier);

  @override
  Stream<Map<String, PIDStats>> get pidStatsStream =>
      _valueNotifierStream(_pidStatsNotifier);

  @override
  Stream<List<obd2lib.TroubleCodeMetadata>?> get diagnosticsStream =>
      _changeNotifierStream(() => troubleCodes);

  @override
  Stream<List<obd2lib.StatusCodeMetadata?>?> get fuelStatusStream =>
      _changeNotifierStream(() => fuelStatus);

  @override
  Stream<obd2lib.Status?> get milStatusStream =>
      _changeNotifierStream(() => milStatus);

  // ── Bootstrap ────────────────────────────────────

  void initialize() {
    _rebuildService();
    _bindInterestRegistry();
    _bindUnitChanges();
  }

  void _rebuildService() {
    final config = ConfigData.instance;
    final libConn = _toLibConnType(config.connectionType);
    _obdService = obd2lib.Obd2Service(
      connectionType: libConn,
      host: config.wifiHost,
      port: config.wifiPort,
    );
    _connectionStateSub?.cancel();
    _connectionStateSub =
        _obdService!.connectionStatePublisher.listen(_handleServiceState);
  }

  void _bindInterestRegistry() {
    _interestSub?.cancel();
    _interestSub =
        PidInterestRegistry.instance.interestedStream.listen((interested) {
      if (connectionState == OBDConnectionState.connected) {
        _restartContinuousUpdates(interested);
      } else {
        _dataSub?.cancel();
        _lastStreamingPids = {};
      }
    });
  }

  void _bindUnitChanges() {
    _unitsSub?.cancel();
    _unitsSub = ConfigData.instance.unitsStream.listen((_) {
      if (connectionState == OBDConnectionState.connected) {
        obdInfo(
          'Units changed to ${ConfigData.instance.units.name}; resetting stats and restarting updates.',
          category: LogCategory.service,
        );
        _resetAllStats();
        _lastStreamingPids = {};
        _restartContinuousUpdates(PidInterestRegistry.instance.interested);
      } else {
        _resetAllStats();
      }
    });
  }

  // ── Connection ───────────────────────────────────

  @override
  Future<void> connect() async {
    if (_shouldIgnoreConnectBecauseAlreadyConnecting()) return;

    final attemptId = ++_connectionAttemptId;
    if (_obdService == null) {
      _rebuildService();
    }
    final service = _obdService!;
    _setConnectionState(OBDConnectionState.connecting);

    final config = ConfigData.instance;
    if (config.connectionType == ConnectionType.bluetooth) {
      final ready = await _prepareBluetoothForConnection(attemptId, service);
      if (!ready) return;
    }

    await _establishObdConnectionSession(attemptId, service);
  }

  bool _shouldIgnoreConnectBecauseAlreadyConnecting() {
    if (connectionState == OBDConnectionState.connected ||
        connectionState == OBDConnectionState.connecting) {
      obdWarning('Connection attempt ignored, already connected or connecting.',
          category: LogCategory.service);
      return true;
    }
    return false;
  }

  /// Sets [failed] if this connection attempt is still current; otherwise no-op.
  void _markBluetoothPrepFailedIfStillActive(
    int attemptId,
    obd2lib.Obd2Service service,
  ) {
    if (!_isActiveConnectionAttempt(attemptId, service)) return;
    _setConnectionState(OBDConnectionState.failed);
  }

  Future<bool> _readFlutterBluePlusIsSupported() async {
    final override = debugBluetoothIsSupportedOverride;
    if (override != null) return override();
    return FlutterBluePlus.isSupported;
  }

  Future<BluetoothAdapterState> _readFlutterBluePlusInitialAdapterState() async {
    final override = debugBluetoothInitialAdapterStateOverride;
    if (override != null) return override();
    return FlutterBluePlus.adapterState.first;
  }

  Future<bool> _bluetoothPermissionsAndHardwareReady(
    int attemptId,
    obd2lib.Obd2Service service,
  ) async {
    if (!await _ensureBluetoothPermissions()) {
      _markBluetoothPrepFailedIfStillActive(attemptId, service);
      return false;
    }
    if (!_isActiveConnectionAttempt(attemptId, service)) return false;
    if (!await _readFlutterBluePlusIsSupported()) {
      _markBluetoothPrepFailedIfStillActive(attemptId, service);
      return false;
    }
    return _isActiveConnectionAttempt(attemptId, service);
  }

  Future<bool> _ensureBluetoothAdapterOnForSession(
    int attemptId,
    obd2lib.Obd2Service service,
  ) async {
    final adapterState = await _readFlutterBluePlusInitialAdapterState();
    if (!_isActiveConnectionAttempt(attemptId, service)) return false;
    if (adapterState == BluetoothAdapterState.on) return true;

    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      _markBluetoothPrepFailedIfStillActive(attemptId, service);
      return false;
    }
    return _isActiveConnectionAttempt(attemptId, service);
  }

  /// Returns false if [connect] should stop (failure or superseded attempt).
  Future<bool> _prepareBluetoothForConnection(
    int attemptId,
    obd2lib.Obd2Service service,
  ) async {
    if (!await _bluetoothPermissionsAndHardwareReady(attemptId, service)) {
      return false;
    }
    return _ensureBluetoothAdapterOnForSession(attemptId, service);
  }

  Future<void> _establishObdConnectionSession(
    int attemptId,
    obd2lib.Obd2Service service,
  ) async {
    try {
      await _runStartConnectionHandshake(attemptId, service);
    } catch (e) {
      _handleStartConnectionFailure(e, attemptId, service);
    }
  }

  Future<void> _runStartConnectionHandshake(
    int attemptId,
    obd2lib.Obd2Service service,
  ) async {
    await obd2lib.Commands.ensureInitialized();
    if (!_isActiveConnectionAttempt(attemptId, service)) return;
    final info = await service.startConnection(
      timeout: 30.0,
      querySupportedPIDs: _querySupportedPids,
    );
    if (!_isActiveConnectionAttempt(attemptId, service)) return;
    _captureSupportedMode1Pids(info);
  }

  void _captureSupportedMode1Pids(obd2lib.ObdInfo info) {
    if (!_querySupportedPids) return;

    final pids = info.supportedPIDs;
    if (pids == null) return;

    _supportedMode1Pids = pids
        .map((cmd) => cmd.properties.command)
        .where((cmd) => cmd.startsWith('01'))
        .toSet();
    _hasSupportedMode1Snapshot = true;
    obdInfo('OBD-II connected successfully.', category: LogCategory.service);
  }

  void _handleStartConnectionFailure(
    Object e,
    int attemptId,
    obd2lib.Obd2Service service,
  ) {
    if (!_isActiveConnectionAttempt(attemptId, service)) {
      obdDebug(
        'Ignoring stale connection failure: $e',
        category: LogCategory.service,
      );
      return;
    }
    _setConnectionState(OBDConnectionState.failed);
    obdError('connect failed: $e', category: LogCategory.service);
  }

  bool _isActiveConnectionAttempt(int attemptId, obd2lib.Obd2Service service) =>
      attemptId == _connectionAttemptId && identical(service, _obdService);

  Future<bool> _ensureBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      final missingBluetoothPerm = statuses.entries.any(
        (entry) => !entry.value.isGranted,
      );
      if (missingBluetoothPerm) {
        obdError(
          'bluetooth permission denied: '
          '${statuses.map((k, v) => MapEntry(k.toString(), v.toString()))}',
          category: LogCategory.service,
        );
        return false;
      }

      // Some Android devices still gate scan results behind location access.
      final locationStatus = await Permission.locationWhenInUse.status;
      if (!locationStatus.isGranted) {
        final requested = await Permission.locationWhenInUse.request();
        if (!requested.isGranted) {
          obdWarning('location permission denied: $requested',
              category: LogCategory.service);
        }
      }
    } catch (e) {
      obdError('permission request failed: $e', category: LogCategory.service);
      return false;
    }

    return true;
  }

  @override
  void disconnect() {
    _connectionAttemptId++;
    _obdService?.stopConnection();
    _dataSub?.cancel();
    _clearForTerminalState();
    _setConnectionState(OBDConnectionState.disconnected);
  }

  @override
  void updateConnectionDetails() {
    if (connectionState != OBDConnectionState.disconnected) disconnect();
    _rebuildService();
  }

  // ── State machine ────────────────────────────────

  void _handleServiceState(obd2lib.ConnectionState serviceState) {
    switch (serviceState) {
      case obd2lib.ConnectionState.disconnected:
        if (connectionState == OBDConnectionState.disconnected) {
          return;
        }
        obdDebug('Mirrored service disconnect to manager state and cleared data.',
            category: LogCategory.service);
        _clearForTerminalState();
        _setConnectionState(OBDConnectionState.disconnected);
        break;
      case obd2lib.ConnectionState.error:
        _clearForTerminalState();
        _setConnectionState(OBDConnectionState.failed);
        break;
      case obd2lib.ConnectionState.connecting:
        _setConnectionState(OBDConnectionState.connecting);
        break;
      case obd2lib.ConnectionState.connectedToAdapter:
        _setConnectionState(OBDConnectionState.connectedToAdapter);
        break;
      case obd2lib.ConnectionState.connectedToVehicle:
        if (connectionState != OBDConnectionState.connected) {
          obdInfo('Connected to vehicle.', category: LogCategory.service);
          _setConnectionState(OBDConnectionState.connected);
          _startContinuousUpdates(PidInterestRegistry.instance.interested);
        }
        break;
    }
  }

  /// Externally trigger the vehicle setup state (usually via log interception).
  void setSettingUpVehicle() {
    if (connectionState == OBDConnectionState.connectedToAdapter) {
      _setConnectionState(OBDConnectionState.settingUpVehicle);
    }
  }

  void _clearForTerminalState() {
    _dataSub?.cancel();
    _lastStreamingPids = {};
    _supportedMode1Pids = {};
    _hasSupportedMode1Snapshot = false;
    pidStats = {};
    fuelStatus = null;
    milStatus = null;
    troubleCodes = null;
    connectedPeripheralName = null;
    _pidStatsNotifier.value = {};
  }

  void _setConnectionState(OBDConnectionState s) {
    connectionState = s;
    _connStateNotifier.value = s;
    notifyListeners();
  }

  // ── Data streaming ───────────────────────────────

  void _startContinuousUpdates(Set<String> interested) {
    if (_obdService == null) return;
    final enabledNow = _filterInterestedPids(interested);
    if (enabledNow.isEmpty) return;
    if (setEquals(enabledNow, _lastStreamingPids)) return;

    _dataSub?.cancel();
    _lastStreamingPids = enabledNow;

    final isMetric = ConfigData.instance.units == MeasurementUnit.metric;
    final unit = isMetric
        ? obd2lib.MeasurementUnit.metric
        : obd2lib.MeasurementUnit.imperial;

    final commands = enabledNow
        .map((cmd) => obd2lib.Commands.allCommands[cmd])
        .whereType<obd2lib.ObdCommand>()
        .toList();

    if (commands.isEmpty) {
      obdInfo('No interested PIDs to monitor.', category: LogCategory.service);
      return;
    }

    obdInfo(
      'Starting continuous updates for ${commands.length} PIDs.',
      category: LogCategory.service,
    );

    _dataSub = _obdService!
        .startContinuousUpdates(pids: commands, unit: unit)
        .listen(_handleUpdateBatch);
  }

  void _restartContinuousUpdates(Set<String> interested) {
    _dataSub?.cancel();
    _lastStreamingPids = {};
    _startContinuousUpdates(interested);
  }

  Set<String> _filterInterestedPids(Set<String> interested) {
    if (!_querySupportedPids || !_hasSupportedMode1Snapshot) return interested;

    return interested.where((cmd) {
      if (!cmd.startsWith('01')) return true;
      return _supportedMode1Pids.contains(cmd);
    }).toSet();
  }

  void _handleUpdateBatch(
      Map<obd2lib.ObdCommand, obd2lib.DecodeResult> batch) {
    bool changed = false;

    for (final entry in batch.entries) {
      if (_processDecodeResult(entry.key.properties.command, entry.value)) {
        changed = true;
      }
    }

    if (changed) {
      _pidStatsNotifier.value = Map.from(pidStats);
      notifyListeners();
    }
  }

  bool _processDecodeResult(String cmdStr, obd2lib.DecodeResult decode) {
    if (cmdStr == '0103' && decode.codeResult != null) {
      fuelStatus = decode.codeResult;
      return true;
    }
    if (cmdStr == '0101' && decode.statusResult != null) {
      milStatus = decode.statusResult;
      return true;
    }
    if (cmdStr == '03' && decode.troubleCodes != null) {
      troubleCodes = decode.troubleCodes;
      return true;
    }
    if (decode.measurementResult != null) {
      final existing = pidStats[cmdStr];
      pidStats[cmdStr] = existing != null
          ? existing.copyWith(decode.measurementResult!)
          : PIDStats(pid: cmdStr, latest: decode.measurementResult!);
      return true;
    }
    return false;
  }


  // ── Stats helpers ─────────────────────────────────

  @override
  PIDStats? statsFor(String pidCommand) => pidStats[pidCommand];

  void _resetAllStats() {
    pidStats = {
      for (final e in pidStats.entries)
        e.key: PIDStats(pid: e.key, latest: e.value.latest)
    };
    _pidStatsNotifier.value = Map.from(pidStats);
  }

  // ── Stream helpers ────────────────────────────────

  Stream<T> _valueNotifierStream<T>(ValueNotifier<T> notifier) =>
      Stream.multi((c) {
        c.add(notifier.value);
        void l() => c.add(notifier.value);
        notifier.addListener(l);
        c.onCancel = () => notifier.removeListener(l);
      });

  Stream<T> _changeNotifierStream<T>(T Function() getter) =>
      Stream.multi((c) {
        c.add(getter());
        void l() => c.add(getter());
        addListener(l);
        c.onCancel = () => removeListener(l);
      });

  // ── Conversion helper ─────────────────────────────

  static obd2lib.ConnectionType _toLibConnType(ConnectionType t) {
    switch (t) {
      case ConnectionType.wifi:
        return obd2lib.ConnectionType.wifi;
      case ConnectionType.demo:
        return obd2lib.ConnectionType.demo;
      case ConnectionType.bluetooth:
        return obd2lib.ConnectionType.bluetooth;
    }
  }
}
