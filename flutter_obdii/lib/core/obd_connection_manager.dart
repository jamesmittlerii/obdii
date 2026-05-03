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
import 'pid_interest_registry.dart';

// ─────────────────────────────────────────────
// MARK: ConnectionState
// ─────────────────────────────────────────────

enum OBDConnectionState {
  disconnected,
  connecting,
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
    if (connectionState == OBDConnectionState.connected ||
        connectionState == OBDConnectionState.connecting) {
      return;
    }

    _setConnectionState(OBDConnectionState.connecting);

    final config = ConfigData.instance;

    // Bluetooth: check adapter
    if (config.connectionType == ConnectionType.bluetooth) {
      if (!await _ensureBluetoothPermissions()) {
        _setConnectionState(OBDConnectionState.failed);
        return;
      }
      if (!await FlutterBluePlus.isSupported) {
        _setConnectionState(OBDConnectionState.failed);
        return;
      }
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {
          _setConnectionState(OBDConnectionState.failed);
          return;
        }
      }
    }

    try {
      await obd2lib.Commands.ensureInitialized();
      await _obdService!.startConnection(
        timeout: 30.0,
        querySupportedPIDs: _querySupportedPids,
      );
      if (_querySupportedPids) {
        try {
          final supported = await _obdService!.getSupportedPIDs();
          _supportedMode1Pids = supported
              .map((cmd) => cmd.properties.command)
              .where((cmd) => cmd.startsWith('01'))
              .toSet();
          _hasSupportedMode1Snapshot = true;
        } catch (e) {
          _supportedMode1Pids = {};
          _hasSupportedMode1Snapshot = false;
          debugPrint('OBDConnectionManager: failed to query supported PIDs: $e');
        }
      }
    } catch (e) {
      _setConnectionState(OBDConnectionState.failed);
      debugPrint('OBDConnectionManager: connect failed: $e');
    }
  }

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
        debugPrint(
          'OBDConnectionManager: bluetooth permission denied: '
          '${statuses.map((k, v) => MapEntry(k.toString(), v.toString()))}',
        );
        return false;
      }

      // Some Android devices still gate scan results behind location access.
      final locationStatus = await Permission.locationWhenInUse.status;
      if (!locationStatus.isGranted) {
        final requested = await Permission.locationWhenInUse.request();
        if (!requested.isGranted) {
          debugPrint(
            'OBDConnectionManager: location permission denied: $requested',
          );
        }
      }
    } catch (e) {
      debugPrint('OBDConnectionManager: permission request failed: $e');
      return false;
    }

    return true;
  }

  @override
  void disconnect() {
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
        _clearForTerminalState();
        _setConnectionState(OBDConnectionState.disconnected);
        break;
      case obd2lib.ConnectionState.error:
        _clearForTerminalState();
        _setConnectionState(OBDConnectionState.failed);
        break;
      case obd2lib.ConnectionState.connecting:
      case obd2lib.ConnectionState.connectedToAdapter:
        if (connectionState != OBDConnectionState.connecting) {
          _setConnectionState(OBDConnectionState.connecting);
        }
        break;
      case obd2lib.ConnectionState.connectedToVehicle:
        if (connectionState != OBDConnectionState.connected) {
          _setConnectionState(OBDConnectionState.connected);
          _startContinuousUpdates(PidInterestRegistry.instance.interested);
        }
        break;
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

    if (commands.isEmpty) return;

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
      final cmdStr = entry.key.properties.command;
      final decode = entry.value;

      // Fuel status (mode1 0103)
      if (cmdStr == '0103' && decode.codeResult != null) {
        fuelStatus = decode.codeResult;
        changed = true;
        continue;
      }

      // MIL status (mode1 0101)
      if (cmdStr == '0101' && decode.statusResult != null) {
        milStatus = decode.statusResult;
        changed = true;
        continue;
      }

      // DTCs (mode3)
      if (cmdStr == '03' && decode.troubleCodes != null) {
        troubleCodes = decode.troubleCodes;
        changed = true;
        continue;
      }

      // Generic gauge
      if (decode.measurementResult != null) {
        final existing = pidStats[cmdStr];
        pidStats[cmdStr] = existing != null
            ? existing.copyWith(decode.measurementResult!)
            : PIDStats(pid: cmdStr, latest: decode.measurementResult!);
        changed = true;
      }
    }

    if (changed) {
      _pidStatsNotifier.value = Map.from(pidStats);
      notifyListeners();
    }
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
