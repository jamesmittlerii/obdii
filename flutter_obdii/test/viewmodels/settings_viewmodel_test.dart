// Port of SettingsViewModelTests.swift — Jim Mittler
// Tests SettingsViewModel: initial state, WiFi debounce, connection type
// switching, unit switching, auto-connect, connect button states,
// publisher bindings, and formatter.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/logger.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/viewmodels/settings_viewmodel.dart';

// ─────────────────────────────────────────────
// Mock SettingsConfigProviding
// ─────────────────────────────────────────────

class MockSettingsConfig implements SettingsConfigProviding {
  @override
  String wifiHost = '192.168.0.10';
  @override
  int wifiPort = 35000;
  @override
  bool autoConnectToOBD = false;
  @override
  ConnectionType connectionType = ConnectionType.bluetooth;
  @override
  MeasurementUnit units = MeasurementUnit.metric;

  @override
  void setUnits(MeasurementUnit u) => units = u;

  final _unitsCtrl = StreamController<MeasurementUnit>.broadcast();
  final _connTypeCtrl = StreamController<ConnectionType>.broadcast();

  @override
  Stream<MeasurementUnit> get unitsStream => _unitsCtrl.stream;
  @override
  Stream<ConnectionType> get connectionTypeStream => _connTypeCtrl.stream;

  void pushUnits(MeasurementUnit u) => _unitsCtrl.add(u);
  void pushConnectionType(ConnectionType t) => _connTypeCtrl.add(t);

  void dispose() {
    _unitsCtrl.close();
    _connTypeCtrl.close();
  }
}

// ─────────────────────────────────────────────
// Mock OBDConnectionControlling
// ─────────────────────────────────────────────

class MockOBDConnection implements OBDConnectionControlling {
  @override
  OBDConnectionState connectionState = OBDConnectionState.disconnected;

  int updateConnectionDetailsCallCount = 0;
  int connectCallCount = 0;
  int disconnectCallCount = 0;

  @override
  void updateConnectionDetails() => updateConnectionDetailsCallCount++;

  @override
  Future<void> connect() async => connectCallCount++;

  @override
  void disconnect() => disconnectCallCount++;

  final _stateCtrl = StreamController<OBDConnectionState>.broadcast();

  @override
  Stream<OBDConnectionState> get connectionStateStream => _stateCtrl.stream;

  void pushState(OBDConnectionState s) {
    connectionState = s;
    _stateCtrl.add(s);
  }

  void dispose() => _stateCtrl.close();
}

// ─────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────

void main() {
  ObdLogger.instance.mutesConsole = true;
  late MockSettingsConfig mockConfig;
  late MockOBDConnection mockConn;
  late SettingsViewModel viewModel;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'OBDII',
      packageName: 'com.rheosoft.obdii',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    mockConfig = MockSettingsConfig();
    mockConn = MockOBDConnection();
    viewModel = SettingsViewModel(config: mockConfig, connection: mockConn);
  });

  tearDown(() async {
    // Wait a microtask to allow async constructor work (_loadAppVersion) to finish
    await Future.delayed(Duration.zero);
    viewModel.dispose();
    mockConfig.dispose();
    mockConn.dispose();
  });

  // ── Initialization ──────────────────────────────

  test('testInitializationSeedsFromConfigAndConnection', () {
    expect(viewModel, isNotNull);
    expect(viewModel.wifiHost, '192.168.0.10');
    expect(viewModel.wifiPort, 35000);
    expect(viewModel.autoConnectToOBD, false);
    expect(viewModel.connectionType, ConnectionType.bluetooth);
    expect(viewModel.units, MeasurementUnit.metric);
    expect(viewModel.connectionState, OBDConnectionState.disconnected);
  });

  // ── WiFi Host (debounced) ───────────────────────

  test('testWifihostUpdatesAfter500msDebounce', () async {
    viewModel.onWifiHostChanged('192.168.1.100');
    await Future.delayed(const Duration(milliseconds: 600));
    expect(viewModel.wifiHost, '192.168.1.100');
    expect(mockConfig.wifiHost, '192.168.1.100');
  });

  test('testWifihostDebounceDoesNotCallUpdateConnectionDetailsForBluetooth', () async {
    expect(viewModel.connectionType, ConnectionType.bluetooth);
    mockConn.updateConnectionDetailsCallCount = 0;
    viewModel.onWifiHostChanged('10.0.0.1');
    await Future.delayed(const Duration(milliseconds: 600));
    expect(mockConn.updateConnectionDetailsCallCount, 0);
  });

  test('testWifihostDebounceCallsUpdateConnectionDetailsWhenWiFiActive', () async {
    viewModel.onConnectionTypeChanged(ConnectionType.wifi);
    mockConn.updateConnectionDetailsCallCount = 0;
    viewModel.onWifiHostChanged('10.0.0.1');
    await Future.delayed(const Duration(milliseconds: 600));
    expect(mockConn.updateConnectionDetailsCallCount, greaterThanOrEqualTo(1));
  });

  // ── WiFi Port (debounced) ───────────────────────

  test('testWifiportUpdatesAfter500msDebounce', () async {
    viewModel.onWifiPortChanged(35001);
    await Future.delayed(const Duration(milliseconds: 600));
    expect(viewModel.wifiPort, 35001);
    expect(mockConfig.wifiPort, 35001);
  });

  // ── Connection type ─────────────────────────────

  test('testOnconnectiontypechangedUpdatesConfigAndCallsUpdateConnectionDetails', () {
    viewModel.onConnectionTypeChanged(ConnectionType.wifi);
    expect(viewModel.connectionType, ConnectionType.wifi);
    expect(mockConfig.connectionType, ConnectionType.wifi);
    expect(mockConn.updateConnectionDetailsCallCount, 1);
  });

  test('testRedundantConnectionTypeChangeDoesNotCallUpdateConnectionDetails', () {
    mockConn.updateConnectionDetailsCallCount = 0;
    viewModel.onConnectionTypeChanged(ConnectionType.bluetooth); // already bluetooth
    expect(mockConn.updateConnectionDetailsCallCount, 0);
  });

  // ── Units ───────────────────────────────────────

  test('testOnunitschangedUpdatesConfig', () {
    viewModel.onUnitsChanged(MeasurementUnit.imperial);
    expect(viewModel.units, MeasurementUnit.imperial);
    expect(mockConfig.units, MeasurementUnit.imperial);
  });

  test('testRedundantUnitsChangeIsHandled', () {
    final initial = viewModel.units;
    viewModel.onUnitsChanged(initial);
    expect(viewModel.units, initial);
  });

  // ── Auto-connect ────────────────────────────────

  test('testOnautoconnectchangedUpdatesConfig', () {
    viewModel.onAutoConnectChanged(true);
    expect(viewModel.autoConnectToOBD, true);
    expect(mockConfig.autoConnectToOBD, true);
  });

  // ── Connection state from stream ────────────────

  test('testConnectionstateUpdatesFromStream', () async {
    mockConn.pushState(OBDConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(viewModel.connectionState, OBDConnectionState.connecting);
  });

  test('testConnectionstateProgression', () async {
    mockConn.pushState(OBDConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.connectionState, OBDConnectionState.connecting);

    mockConn.pushState(OBDConnectionState.connected);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.connectionState, OBDConnectionState.connected);

    mockConn.pushState(OBDConnectionState.disconnected);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.connectionState, OBDConnectionState.disconnected);
  });

  // ── isConnectButtonDisabled ─────────────────────

  test('testIsconnectbuttondisabledFalseWhenDisconnected', () {
    expect(viewModel.isConnectButtonDisabled, isFalse);
  });

  test('testIsconnectbuttondisabledTrueWhenConnecting', () async {
    final vm2 = SettingsViewModel(
      config: MockSettingsConfig(),
      connection: MockOBDConnection()..connectionState = OBDConnectionState.connecting,
    );
    expect(vm2.isConnectButtonDisabled, isTrue);
    await Future.delayed(Duration.zero);
    vm2.dispose();
  });

  // ── External publisher sync ─────────────────────

  test('testUnitsstreamFromConfigUpdatesViewModel', () async {
    mockConfig.pushUnits(MeasurementUnit.imperial);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(viewModel.units, MeasurementUnit.imperial);
  });

  test('testConnectiontypestreamFromConfigUpdatesViewModel', () async {
    mockConfig.pushConnectionType(ConnectionType.wifi);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(viewModel.connectionType, ConnectionType.wifi);
  });

  // ── handleConnectionButtonTap ───────────────────

  test('testHandleconnectionbuttontapWhenDisconnectedCallsConnect', () async {
    mockConn.connectionState = OBDConnectionState.disconnected;
    viewModel = SettingsViewModel(config: mockConfig, connection: mockConn);
    viewModel.handleConnectionButtonTap();
    await Future.delayed(const Duration(milliseconds: 100));
    expect(mockConn.connectCallCount, 1);
  });

  test('testHandleconnectionbuttontapWhenConnectedCallsDisconnect', () {
    mockConn.connectionState = OBDConnectionState.connected;
    viewModel = SettingsViewModel(config: mockConfig, connection: mockConn);
    viewModel.handleConnectionButtonTap();
    expect(mockConn.disconnectCallCount, 1);
  });

  test('testHandleconnectionbuttontapWhenConnectingDoesNothing', () async {
    mockConn.connectionState = OBDConnectionState.connecting;
    viewModel = SettingsViewModel(config: mockConfig, connection: mockConn);
    viewModel.handleConnectionButtonTap();
    await Future.delayed(const Duration(milliseconds: 100));
    expect(mockConn.connectCallCount, 0);
    expect(mockConn.disconnectCallCount, 0);
  });

  test('testHandleconnectionbuttontapWhenFailedCallsConnect', () async {
    mockConn.connectionState = OBDConnectionState.failed;
    viewModel = SettingsViewModel(config: mockConfig, connection: mockConn);
    viewModel.handleConnectionButtonTap();
    await Future.delayed(const Duration(milliseconds: 100));
    expect(mockConn.connectCallCount, 1);
  });

  test('testWifiportDebounceDoesNotCallUpdateConnectionDetailsForBluetooth', () async {
    mockConn.updateConnectionDetailsCallCount = 0;
    viewModel.onWifiPortChanged(33000);
    await Future.delayed(const Duration(milliseconds: 600));
    expect(mockConn.updateConnectionDetailsCallCount, 0);
  });

  test('testWifiportDebounceCallsUpdateConnectionDetailsForWifi', () async {
    viewModel.onConnectionTypeChanged(ConnectionType.wifi);
    mockConn.updateConnectionDetailsCallCount = 0;
    viewModel.onWifiPortChanged(33001);
    await Future.delayed(const Duration(milliseconds: 600));
    expect(mockConn.updateConnectionDetailsCallCount, greaterThanOrEqualTo(1));
  });

  test('testAutoconnectCanToggleFalseThenTrue', () {
    viewModel.onAutoConnectChanged(false);
    expect(viewModel.autoConnectToOBD, isFalse);
    viewModel.onAutoConnectChanged(true);
    expect(viewModel.autoConnectToOBD, isTrue);
  });

  test('testNumberformatterAllowsOnlyDigits', () {
    final formatted = SettingsViewModel.numberFormatter.formatEditUpdate(
      const TextEditingValue(text: '12'),
      const TextEditingValue(text: '12ab34'),
    );
    expect(formatted.text, '1234');
  });
}
