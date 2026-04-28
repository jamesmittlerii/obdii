// Port of OBDConnectionManager.swift — Jim Mittler
// Main OBD-II connection manager singleton.
// Manages vehicle communication via flutter_obd2 library, connection lifecycle,
// and continuous PID data streaming. Integrates with PIDInterestRegistry for
// demand-driven polling. Publishes connection state, diagnostic codes, fuel
// status, MIL status, and per-PID statistics.

import 'dart:async';
import 'dart:io';
import 'dart:math';

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
  Timer? _demoTimer;
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
        _demoTimer?.cancel();
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
    _demoTimer?.cancel();
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
        if (connectionState != OBDConnectionState.connecting) {
          _setConnectionState(OBDConnectionState.connecting);
        }
        break;
      case obd2lib.ConnectionState.connectedToAdapter:
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
    _demoTimer?.cancel();
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

    for (final cmd in commands) {
      _obdService!.addPID(cmd);
    }

    _dataSub = _obdService!
        .startContinuousUpdates(unit: unit)
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

  // ── Demo mode ─────────────────────────────────────
  //
  // Port of MOCKComm.makeMockResponse() in SwiftOBD2/mockManager.swift.
  // Uses the same speed→RPM model and time-based warmup curves so the
  // Flutter demo behaves identically to the original Swift app.

  // ignore: unused_element
  void _startDemoData() {
    _demoTimer?.cancel();
    final sessionStart = DateTime.now();
    DateTime? lastTick;
    double accumulatedSeconds = 0;
    double accumulatedMeters = 0;

    // ── helpers ───────────────────────────────────────
    double sessionElapsed() {
      final now = DateTime.now();
      final elapsed = now.difference(sessionStart).inMilliseconds / 1000.0;
      final dt = lastTick != null
          ? now.difference(lastTick!).inMilliseconds / 1000.0
          : 0.0;
      lastTick = now;
      accumulatedSeconds += dt.clamp(0.0, 5.0);
      return elapsed;
    }

    double smoothNoise(double seed, double scale) {
      final t = sessionElapsed();
      final n = sin((t + seed) * 0.2) * 0.6 +
          sin((t * 0.07) + seed * 3.1) * 0.4;
      return n * scale;
    }

    double mockSpeed() {
      final elapsed = sessionElapsed();
      const rampDuration = 15.0, minSpeed = 20.0, maxSpeed = 70.0;
      if (elapsed < rampDuration) {
        return (elapsed / rampDuration * minSpeed).clamp(0.0, minSpeed);
      } else {
        const midpoint = (minSpeed + maxSpeed) / 2.0;
        const amplitude = (maxSpeed - minSpeed) / 2.0;
        const period = 30.0;
        final phase = 2.0 *
            pi *
            ((elapsed - rampDuration) % period / period);
        return midpoint + amplitude * sin(phase);
      }
    }

    double mockRpm(double speed) {
      if (speed <= 0.5) return 800.0;
      if (speed < 20.0) return 800.0 + 360.0 * speed;
      if (speed < 50.0) return 1500.0 + (6500.0 / 30.0) * (speed - 20.0);
      return 1800.0 + 310.0 * (speed - 50.0);
    }

    _demoTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final t = sessionElapsed();
      final speed = mockSpeed();
      final rpm = mockRpm(speed).clamp(800.0, 8000.0);
      final rpmN = ((rpm - 800.0) / (8000.0 - 800.0)).clamp(0.0, 1.0);

      // Warmup: 0→100°C over 60 s
      final warmupT = (t / 60.0).clamp(0.0, 1.0);
      final coolantC = warmupT * 100.0;
      // Intake temp: 0→70°C over 60 s
      final intakeTempC = (t / 60.0).clamp(0.0, 1.0) * 70.0 - 40.0 + 40.0;

      // Derived signals
      final load = (0.1 + 0.8 * rpmN + smoothNoise(4, 0.03)).clamp(0.0, 1.0);
      final throttlePct = (0.15 + 0.45 * rpmN * rpmN +
              smoothNoise(5.5, 0.015))
          .clamp(0.0, 1.0);
      final mapKPa = (25.0 + load * 70.0 + smoothNoise(8, 2.0)).clamp(20.0, 100.0);
      final mafGs = (2.0 + rpmN * 118.0 * (0.8 + 0.4 * rpmN) +
              smoothNoise(2, 3.0))
          .clamp(2.0, 200.0);
      final timingDeg =
          (10.0 + rpmN * 25.0 - load * 12.0 + smoothNoise(7, 1.0)).clamp(2.0, 45.0);
      final voltageV =
          (13.6 + smoothNoise(1, 0.15)).clamp(12.2, 14.6);
      final fuelLevelPct =
          (90.0 - (t / 10.0)).clamp(0.0, 100.0);
      final baroKPa = (101.0 + smoothNoise(9, 0.6)).clamp(95.0, 105.0);
      final fuelPresKPa =
          (400.0 + smoothNoise(6, 25.0)).clamp(200.0, 600.0);
      final shortFuelTrim = (smoothNoise(10, 0.05) * 100.0).clamp(-25.0, 25.0);
      final longFuelTrim = (smoothNoise(11, 0.02) * 100.0).clamp(-25.0, 25.0);
      final o2Voltage = (0.5 + smoothNoise(14, 0.3)).clamp(0.1, 0.9);
      final catTempC =
          (300.0 + 250.0 * (0.5 + 0.5 * sin(t * 0.1)) + smoothNoise(27, 15.0))
              .clamp(200.0, 900.0);
      final absLoad = (load * 100.0).clamp(0.0, 100.0);
      final lambda = (1.0 + smoothNoise(29, 0.03)).clamp(0.9, 1.1);
      final relThrottle = (throttlePct * 100.0).clamp(0.0, 100.0);
      final engineLoadPct = (load * 100.0).clamp(0.0, 100.0);
      final runTimeSec = accumulatedSeconds.clamp(0.0, 65535.0);
      final distKm = (accumulatedMeters / 1000.0).clamp(0.0, 65535.0);
      accumulatedMeters += (speed / 3.6) * 0.5; // integrate 500ms tick
      final evapPurgePct =
          (0.1 + 0.3 * sin(t * 0.2)).clamp(0.0, 100.0);
      final commandedEGRPct =
          (0.2 + 0.2 * sin(t * 0.3)).clamp(0.0, 100.0);
      final hybridSOCPct = (90.0 - t / 600.0).clamp(50.0, 100.0);

      // ── OBD hex command → MeasurementResult map ──────
      final updates = <String, obd2lib.MeasurementResult>{
        // Tier-1 (always enabled by default)
        '010C': obd2lib.MeasurementResult(rpm, obd2lib.Unit.rpm),
        '010D': obd2lib.MeasurementResult(speed, obd2lib.Unit.kilometersPerHour),
        '0105': obd2lib.MeasurementResult(coolantC, obd2lib.Unit.celsius),
        '010F': obd2lib.MeasurementResult(intakeTempC, obd2lib.Unit.celsius),
        '0142': obd2lib.MeasurementResult(voltageV, obd2lib.Unit.volts),
        // Gauges (disabled by default; generated anyway so they work when enabled)
        '0111': obd2lib.MeasurementResult(throttlePct * 100, obd2lib.Unit.percent),
        '0104': obd2lib.MeasurementResult(engineLoadPct, obd2lib.Unit.percent),
        '0143': obd2lib.MeasurementResult(absLoad, obd2lib.Unit.percent),
        '010B': obd2lib.MeasurementResult(mapKPa, obd2lib.Unit.kilopascals),
        '0110': obd2lib.MeasurementResult(mafGs, obd2lib.Unit.gramsPerSecond),
        '010E': obd2lib.MeasurementResult(timingDeg, obd2lib.Unit.degrees),
        '0146': obd2lib.MeasurementResult(25.0, obd2lib.Unit.celsius), // ambient
        '012F': obd2lib.MeasurementResult(fuelLevelPct, obd2lib.Unit.percent),
        '0133': obd2lib.MeasurementResult(baroKPa, obd2lib.Unit.kilopascals),
        '010A': obd2lib.MeasurementResult(fuelPresKPa, obd2lib.Unit.kilopascals),
        '0159': obd2lib.MeasurementResult(fuelPresKPa, obd2lib.Unit.kilopascals),
        '0122': obd2lib.MeasurementResult(fuelPresKPa, obd2lib.Unit.kilopascals),
        '0123': obd2lib.MeasurementResult(fuelPresKPa, obd2lib.Unit.kilopascals),
        '0106': obd2lib.MeasurementResult(shortFuelTrim, obd2lib.Unit.percent),
        '0107': obd2lib.MeasurementResult(longFuelTrim, obd2lib.Unit.percent),
        '0108': obd2lib.MeasurementResult(shortFuelTrim * 0.9, obd2lib.Unit.percent),
        '0109': obd2lib.MeasurementResult(longFuelTrim * 0.9, obd2lib.Unit.percent),
        '0114': obd2lib.MeasurementResult(o2Voltage, obd2lib.Unit.volts),
        '0115': obd2lib.MeasurementResult(o2Voltage * 1.05, obd2lib.Unit.volts),
        '0118': obd2lib.MeasurementResult(o2Voltage * 0.96, obd2lib.Unit.volts),
        '0119': obd2lib.MeasurementResult(o2Voltage * 1.02, obd2lib.Unit.volts),
        '013C': obd2lib.MeasurementResult(catTempC, obd2lib.Unit.celsius),
        '013D': obd2lib.MeasurementResult(catTempC * 0.98, obd2lib.Unit.celsius),
        '013E': obd2lib.MeasurementResult(catTempC * 0.97, obd2lib.Unit.celsius),
        '013F': obd2lib.MeasurementResult(catTempC * 0.95, obd2lib.Unit.celsius),
        '0144': obd2lib.MeasurementResult(lambda, obd2lib.Unit.ratio),
        '0145': obd2lib.MeasurementResult(relThrottle, obd2lib.Unit.percent),
        '0147': obd2lib.MeasurementResult(relThrottle * 0.98, obd2lib.Unit.percent),
        '0148': obd2lib.MeasurementResult(relThrottle * 0.97, obd2lib.Unit.percent),
        '0149': obd2lib.MeasurementResult(relThrottle * 0.96, obd2lib.Unit.percent),
        '014A': obd2lib.MeasurementResult(relThrottle * 0.95, obd2lib.Unit.percent),
        '014B': obd2lib.MeasurementResult(relThrottle * 0.94, obd2lib.Unit.percent),
        '014C': obd2lib.MeasurementResult(relThrottle * 0.93, obd2lib.Unit.percent),
        '011F': obd2lib.MeasurementResult(runTimeSec, obd2lib.Unit.seconds),
        '0121': obd2lib.MeasurementResult(distKm, obd2lib.Unit.kilometers),
        '0131': obd2lib.MeasurementResult(distKm, obd2lib.Unit.kilometers),
        '012E': obd2lib.MeasurementResult(evapPurgePct, obd2lib.Unit.percent),
        '012C': obd2lib.MeasurementResult(commandedEGRPct, obd2lib.Unit.percent),
        '015A': obd2lib.MeasurementResult(relThrottle, obd2lib.Unit.percent),
        '015B': obd2lib.MeasurementResult(hybridSOCPct, obd2lib.Unit.percent),
      };

      final interested = PidInterestRegistry.instance.interested;
      for (final entry in updates.entries) {
        if (interested.isNotEmpty && !interested.contains(entry.key)) continue;
        final existing = pidStats[entry.key];
        pidStats[entry.key] = existing != null
            ? existing.copyWith(entry.value)
            : PIDStats(pid: entry.key, latest: entry.value);
      }

      // Non-gauge tabs (Fuel / MIL / DTCs) need synthetic payloads in demo mode.
      // Gate these by current interest to mirror demand-driven polling.
      if (interested.isEmpty || interested.contains('0103')) {
        // Match SwiftOBD2 mock fuel-status behavior:
        // 1 = Open Loop (cold engine)
        // 2 = Closed Loop (normal operation)
        // 3 = Open Loop (load/fuel cut)
        final int fuelCode;
        if (coolantC < 60.0) {
          fuelCode = 1;
        } else if (throttlePct < 3.0) {
          fuelCode = 3;
        } else {
          fuelCode = 2;
        }
        final fuelDescription = switch (fuelCode) {
          1 => 'Open Loop (cold engine)',
          2 => 'Closed Loop (normal operation)',
          3 => 'Open Loop (load/fuel cut)',
          _ => 'Unavailable',
        };

        // Swift mock returns the same status byte for both banks.
        fuelStatus = [
          obd2lib.StatusCodeMetadata(
            code: fuelCode.toString(),
            description: fuelDescription,
          ),
          obd2lib.StatusCodeMetadata(
            code: fuelCode.toString(),
            description: fuelDescription,
          ),
        ];
      }

      if (interested.isEmpty || interested.contains('0101')) {
        final stageTimeSeconds = t.clamp(0.0, 120.0);
        final stages = (stageTimeSeconds / 12.0).floor();
        bool readyAtStage(int requiredStage) => stages >= requiredStage;
        milStatus = obd2lib.Status(
          milOn: true,
          dtcCount: 7,
          // Mirrors SwiftOBD2 mock progression in mockManager.swift:
          // 10 gasoline monitors become ready across 120 seconds.
          monitors: [
            obd2lib.ReadinessMonitor(
              name: 'Misfire',
              supported: true,
              ready: readyAtStage(3),
            ),
            obd2lib.ReadinessMonitor(
              name: 'Fuel System',
              supported: true,
              ready: readyAtStage(2),
            ),
            obd2lib.ReadinessMonitor(
              name: 'Comprehensive Components',
              supported: true,
              ready: readyAtStage(1),
            ),
            obd2lib.ReadinessMonitor(
              name: 'Catalyst',
              supported: true,
              ready: readyAtStage(6),
            ),
            obd2lib.ReadinessMonitor(
              name: 'Heated Catalyst',
              supported: true,
              ready: readyAtStage(10),
            ),
            obd2lib.ReadinessMonitor(
              name: 'Evaporative System',
              supported: true,
              ready: readyAtStage(7),
            ),
            obd2lib.ReadinessMonitor(
              name: 'Secondary Air System',
              supported: true,
              ready: readyAtStage(9),
            ),
            obd2lib.ReadinessMonitor(
              name: 'O₂ Sensor',
              supported: true,
              ready: readyAtStage(5),
            ),
            obd2lib.ReadinessMonitor(
              name: 'O₂ Heater',
              supported: true,
              ready: readyAtStage(4),
            ),
            obd2lib.ReadinessMonitor(
              name: 'EGR/VVT System',
              supported: true,
              ready: readyAtStage(8),
            ),
          ],
        );
      }

      if (interested.isEmpty || interested.contains('03')) {
        // Mirrors SwiftOBD2 mock Mode 03 response list in mockManager.swift.
        troubleCodes = [
          _demoTroubleCode('P0300'),
          _demoTroubleCode('P0170'),
          _demoTroubleCode('P0101'),
          _demoTroubleCode('P0104'),
          _demoTroubleCode('P0207'),
          _demoTroubleCode('P0411'),
          _demoTroubleCode('P0420'),
        ];
      }

      _pidStatsNotifier.value = Map.from(pidStats);
      notifyListeners();
    });
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

  obd2lib.TroubleCodeMetadata _demoTroubleCode(String code) {
    final fromDictionary = obd2lib.troubleCodeDictionary[code];
    if (fromDictionary != null) return fromDictionary;
    return obd2lib.TroubleCodeMetadata(
      code: code,
      title: 'Diagnostic Trouble Code',
      description: 'Simulated demo DTC',
      severity: 'Moderate',
      causes: const ['Unknown'],
      remedies: const ['Inspect vehicle'],
    );
  }
}
