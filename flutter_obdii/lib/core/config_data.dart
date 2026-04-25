// Port of ConfigData.swift — Jim Mittler
// Global configuration data singleton.
// Manages app-wide settings including WiFi connection details,
// auto-connect preferences, connection type, and measurement units.
// Uses SharedPreferences for persistence (replaces @AppStorage).

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'carplay_bridge.dart';

// ─────────────────────────────────────────────
// MARK: Enums
// ─────────────────────────────────────────────

enum MeasurementUnit {
  metric('Metric'),
  imperial('Imperial');

  const MeasurementUnit(this.displayName);
  final String displayName;

  MeasurementUnit get next =>
      this == MeasurementUnit.metric ? MeasurementUnit.imperial : MeasurementUnit.metric;
}

enum ConnectionType {
  bluetooth('bluetooth'),
  wifi('wifi'),
  demo('demo');

  const ConnectionType(this.rawValue);
  final String rawValue;

  static ConnectionType fromRaw(String raw) =>
      ConnectionType.values.firstWhere((e) => e.rawValue == raw,
          orElse: () => ConnectionType.bluetooth);
}

// ─────────────────────────────────────────────
// MARK: SettingsConfigProviding (protocol)
// ─────────────────────────────────────────────

abstract class SettingsConfigProviding {
  String get wifiHost;
  set wifiHost(String v);
  int get wifiPort;
  set wifiPort(int v);
  bool get autoConnectToOBD;
  set autoConnectToOBD(bool v);
  ConnectionType get connectionType;
  set connectionType(ConnectionType v);
  MeasurementUnit get units;

  void setUnits(MeasurementUnit units);

  // Streams so ViewModels can react
  Stream<MeasurementUnit> get unitsStream;
  Stream<ConnectionType> get connectionTypeStream;
}

// ─────────────────────────────────────────────
// MARK: UnitsProviding (protocol)
// ─────────────────────────────────────────────

abstract class UnitsProviding {
  MeasurementUnit get units;
  Stream<MeasurementUnit> get unitsStream;
}

// ─────────────────────────────────────────────
// MARK: ConfigData singleton
// ─────────────────────────────────────────────

class ConfigData extends ChangeNotifier
    implements SettingsConfigProviding, UnitsProviding {
  static final ConfigData instance = ConfigData._();
  ConfigData._();

  // Persistence keys
  static const _kWifiHost = 'wifiHost';
  static const _kWifiPort = 'wifiPort';
  static const _kAutoConnect = 'autoConnectToOBD';
  static const _kConnectionType = 'connectionType';
  static const _kUnits = 'units';

  // In-memory state
  String _wifiHost = '192.168.0.10';
  int _wifiPort = 35000;
  bool _autoConnectToOBD = true;
  ConnectionType _connectionType = ConnectionType.bluetooth;
  MeasurementUnit _units = MeasurementUnit.metric;

  bool _loaded = false;

  // Broadcast streams (replaces @Published / Combine)
  final _unitsController = ValueNotifier<MeasurementUnit>(MeasurementUnit.metric);
  final _connectionTypeController = ValueNotifier<ConnectionType>(ConnectionType.bluetooth);

  @override
  Stream<MeasurementUnit> get unitsStream =>
      Stream.multi((c) {
        c.add(_unitsController.value);
        void listener() => c.add(_unitsController.value);
        _unitsController.addListener(listener);
        c.onCancel = () => _unitsController.removeListener(listener);
      });

  @override
  Stream<ConnectionType> get connectionTypeStream =>
      Stream.multi((c) {
        c.add(_connectionTypeController.value);
        void listener() => c.add(_connectionTypeController.value);
        _connectionTypeController.addListener(listener);
        c.onCancel = () => _connectionTypeController.removeListener(listener);
      });

  // ── Getters / Setters ────────────────────────

  @override
  String get wifiHost => _wifiHost;
  @override
  set wifiHost(String v) {
    if (v == _wifiHost) return;
    _wifiHost = v;
    _persist(_kWifiHost, v);
    _notifyCarPlaySettingsChanged();
    notifyListeners();
  }

  @override
  int get wifiPort => _wifiPort;
  @override
  set wifiPort(int v) {
    if (v == _wifiPort) return;
    _wifiPort = v;
    _persist(_kWifiPort, v);
    _notifyCarPlaySettingsChanged();
    notifyListeners();
  }

  @override
  bool get autoConnectToOBD => _autoConnectToOBD;
  @override
  set autoConnectToOBD(bool v) {
    if (v == _autoConnectToOBD) return;
    _autoConnectToOBD = v;
    _persist(_kAutoConnect, v);
    _notifyCarPlaySettingsChanged();
    notifyListeners();
  }

  @override
  ConnectionType get connectionType => _connectionType;
  @override
  set connectionType(ConnectionType v) {
    if (v == _connectionType) return;
    _connectionType = v;
    _persist(_kConnectionType, v.rawValue);
    _connectionTypeController.value = v;
    _notifyCarPlaySettingsChanged();
    notifyListeners();
  }

  @override
  MeasurementUnit get units => _units;

  @override
  void setUnits(MeasurementUnit newUnits) {
    if (newUnits == _units) return;
    _units = newUnits;
    _persist(_kUnits, newUnits.name);
    _unitsController.value = newUnits;
    _notifyCarPlaySettingsChanged();
    notifyListeners();
  }

  // ── Load from SharedPreferences ──────────────

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();

    _wifiHost = prefs.getString(_kWifiHost) ?? '192.168.0.10';
    _wifiPort = prefs.getInt(_kWifiPort) ?? 35000;
    _autoConnectToOBD = prefs.getBool(_kAutoConnect) ?? true;

    final rawConn = prefs.getString(_kConnectionType) ?? 'bluetooth';
    _connectionType = ConnectionType.fromRaw(rawConn);

    final rawUnits = prefs.getString(_kUnits) ?? 'metric';
    _units = MeasurementUnit.values
        .firstWhere((e) => e.name == rawUnits, orElse: () => MeasurementUnit.metric);

    _unitsController.value = _units;
    _connectionTypeController.value = _connectionType;

    notifyListeners();
  }

  // ── Helpers ──────────────────────────────────

  Future<void> _persist(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  void _notifyCarPlaySettingsChanged() {
    CarPlayBridge.settingsChanged(
      units: _units,
      connectionType: _connectionType,
      autoConnectToOBD: _autoConnectToOBD,
      wifiHost: _wifiHost,
      wifiPort: _wifiPort,
    );
  }
}
