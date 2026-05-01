// Port of SettingsViewModel.swift — Jim Mittler
// ViewModel for settings screen.
// Manages connection state display, WiFi config with 500ms debounce,
// unit switching, and the connect/disconnect button action.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/config_data.dart';
import '../core/obd_connection_manager.dart';
import 'base_view_model.dart';

class SettingsViewModel extends BaseViewModel {
  final SettingsConfigProviding _config;
  final OBDConnectionControlling _connection;

  // Mirrored, writable properties (bound to UI text fields / toggles)
  String wifiHost;
  int wifiPort;
  bool autoConnectToOBD;
  ConnectionType connectionType;
  MeasurementUnit units;

  OBDConnectionState connectionState;

  // Debounce timers for WiFi host/port (mirrors Swift Combine debounce .seconds(0.5))
  Timer? _hostDebounce;
  Timer? _portDebounce;

  StreamSubscription? _connectionStateSub;
  StreamSubscription? _unitsStreamSub;
  StreamSubscription? _connTypeStreamSub;

  SettingsViewModel({
    SettingsConfigProviding? config,
    OBDConnectionControlling? connection,
  })  : _config = config ?? ConfigData.instance,
        _connection = connection ?? OBDConnectionManager.instance,
        wifiHost = (config ?? ConfigData.instance).wifiHost,
        wifiPort = (config ?? ConfigData.instance).wifiPort,
        autoConnectToOBD = (config ?? ConfigData.instance).autoConnectToOBD,
        connectionType = (config ?? ConfigData.instance).connectionType,
        units = (config ?? ConfigData.instance).units,
        connectionState = (connection ?? OBDConnectionManager.instance).connectionState {
    _bindConnectionState();
    _bindExternalPublishers();
  }

  // ── Binding ─────────────────────────────────────

  void _bindConnectionState() {
    _connectionStateSub =
        _connection.connectionStateStream.listen((newState) {
      connectionState = newState;
      notifyListeners();
    });
  }

  void _bindExternalPublishers() {
    // If another part of the app changes units (e.g. CarPlay), keep in sync
    _unitsStreamSub = _config.unitsStream.listen((newUnits) {
      units = newUnits;
      notifyListeners();
    });

    _connTypeStreamSub = _config.connectionTypeStream.listen((newType) {
      connectionType = newType;
      notifyListeners();
    });
  }

  // ── WiFi Host (debounced) ────────────────────────

  void onWifiHostChanged(String newHost) {
    wifiHost = newHost;
    notifyListeners();
    _hostDebounce?.cancel();
    _hostDebounce = Timer(const Duration(milliseconds: 500), () {
      _config.wifiHost = wifiHost;
      if (connectionType == ConnectionType.wifi) {
        _connection.updateConnectionDetails();
      }
    });
  }

  // ── WiFi Port (debounced) ────────────────────────

  void onWifiPortChanged(int newPort) {
    wifiPort = newPort;
    notifyListeners();
    _portDebounce?.cancel();
    _portDebounce = Timer(const Duration(milliseconds: 500), () {
      _config.wifiPort = wifiPort;
      if (connectionType == ConnectionType.wifi) {
        _connection.updateConnectionDetails();
      }
    });
  }

  // ── Connection type ──────────────────────────────

  void onConnectionTypeChanged(ConnectionType newType) {
    if (newType == connectionType) return;
    connectionType = newType;
    _config.connectionType = newType;
    _connection.updateConnectionDetails();
    notifyListeners();
  }

  // ── Units ────────────────────────────────────────

  void onUnitsChanged(MeasurementUnit newUnits) {
    if (newUnits == units) return;
    units = newUnits;
    _config.setUnits(newUnits);
    notifyListeners();
  }

  // ── Auto connect ─────────────────────────────────

  void onAutoConnectChanged(bool value) {
    autoConnectToOBD = value;
    _config.autoConnectToOBD = value;
    notifyListeners();
  }

  // ── Connect button ───────────────────────────────

  bool get isConnectButtonDisabled =>
      connectionState == OBDConnectionState.connecting;

  void handleConnectionButtonTap() {
    switch (connectionState) {
      case OBDConnectionState.disconnected:
      case OBDConnectionState.failed:
        _connection.connect();
        break;
      case OBDConnectionState.connected:
        _connection.disconnect();
        break;
      case OBDConnectionState.connecting:
        // Do nothing while connecting
        break;
    }
  }

  // ── Diagnostics ──────────────────────────────────

  Future<Map<String, dynamic>> generateDiagnosticLogs() async {
    final info = await PackageInfo.fromPlatform();
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'appVersion': '${info.version}+${info.buildNumber}',
      'connectionType': _config.connectionType.toString(),
      'units': _config.units.toString(),
      'connectionState': _connection.connectionState.toString(),
      'wifiHost': _config.wifiHost,
      'wifiPort': _config.wifiPort,
    };
  }

  // ── Number formatter (for port text field) ───────

  static final TextInputFormatter numberFormatter =
      FilteringTextInputFormatter.digitsOnly;

  // ── Dispose ──────────────────────────────────────

  @override
  void dispose() {
    _hostDebounce?.cancel();
    _portDebounce?.cancel();
    _connectionStateSub?.cancel();
    _unitsStreamSub?.cancel();
    _connTypeStreamSub?.cancel();
    super.dispose();
  }
}
