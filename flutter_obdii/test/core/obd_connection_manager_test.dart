import 'dart:io';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/logger.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  ObdLogger.instance.mutesConsole = true;

  final manager = OBDConnectionManager.instance;

  setUp(() {
    OBDConnectionManager.debugBluetoothIsSupportedOverride = null;
    OBDConnectionManager.debugBluetoothInitialAdapterStateOverride = null;

    // Setup the log bridge to handle the 'Setting up vehicle' transition in tests
    obd2lib.ObdLog.setHandler((
      message, {
      level = 'info',
      category = 'Communication',
    }) {
      if (message.contains('Setting up vehicle')) {
        OBDConnectionManager.instance.setSettingUpVehicle();
      }
    });

    manager.disconnect();
    ConfigData.instance.connectionType = ConnectionType.demo;
    manager.initialize();
  });

  test('testSharedInstanceExists', () {
    expect(OBDConnectionManager.instance, isNotNull);
  });

  test('testInitialStateDisconnected', () {
    expect(manager.connectionState, OBDConnectionState.disconnected);
  });

  test('testInitialPublishedStatesNil', () {
    expect(manager.troubleCodes, isNull);
    expect(manager.fuelStatus, isNull);
    expect(manager.milStatus, isNull);
    expect(manager.connectedPeripheralName, isNull);
  });

  test('testInitialPidStatsEmpty', () {
    expect(manager.pidStats, isEmpty);
  });

  test('testConnectInDemoMode', () async {
    ConfigData.instance.connectionType = ConnectionType.demo;
    manager.updateConnectionDetails();
    await manager.connect();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(manager.connectionState, OBDConnectionState.connected);
  });

  test('testDisconnectFromConnectedState', () async {
    ConfigData.instance.connectionType = ConnectionType.demo;
    manager.updateConnectionDetails();
    await manager.connect();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    manager.disconnect();
    expect(manager.connectionState, OBDConnectionState.disconnected);
    expect(manager.pidStats, isEmpty);
  });

  test('testMultipleConnectAttempts', () async {
    ConfigData.instance.connectionType = ConnectionType.demo;
    manager.updateConnectionDetails();
    await manager.connect();
    await manager.connect();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(manager.connectionState, OBDConnectionState.connected);
  });

  test('testUpdateConnectionDetails', () {
    ConfigData.instance.connectionType = ConnectionType.wifi;
    manager.updateConnectionDetails();
    expect(manager.connectionState, OBDConnectionState.disconnected);
  });

  test('testStatsForPIDWithNoData', () {
    expect(manager.statsFor('010C'), isNull);
  });

  test('testConnectionStateEquality', () {
    expect(OBDConnectionState.connected, OBDConnectionState.connected);
    expect(OBDConnectionState.connected == OBDConnectionState.failed, isFalse);
  });

  test('testPIDStatsCreation', () {
    final stats = PIDStats(
      pid: '010C',
      latest: obd2lib.MeasurementResult(2500, obd2lib.Unit.rpm),
    );
    expect(stats.pid, '010C');
    expect(stats.latest.value, 2500);
    expect(stats.min, 2500);
    expect(stats.max, 2500);
    expect(stats.sampleCount, 1);
  });

  test('testPIDStatsUpdate', () {
    var stats = PIDStats(
      pid: '010C',
      latest: obd2lib.MeasurementResult(2500, obd2lib.Unit.rpm),
    );
    stats = stats.copyWith(obd2lib.MeasurementResult(3000, obd2lib.Unit.rpm));
    expect(stats.latest.value, 3000);
    expect(stats.min, 2500);
    expect(stats.max, 3000);
    expect(stats.sampleCount, 2);
  });

  test('testPIDStatsEquality', () {
    final s1 = PIDStats(
      pid: '010C',
      latest: obd2lib.MeasurementResult(2500, obd2lib.Unit.rpm),
    );
    final s2 = PIDStats(
      pid: '010C',
      latest: obd2lib.MeasurementResult(2500, obd2lib.Unit.rpm),
    );
    expect(s1, s2);
  });

  test('testPIDStatsHashCodeAndMinUpdate', () {
    final original = PIDStats(
      pid: '010C',
      latest: obd2lib.MeasurementResult(2500, obd2lib.Unit.rpm),
    );
    final updated = original.copyWith(
      obd2lib.MeasurementResult(2000, obd2lib.Unit.rpm),
    );

    expect(updated.min, 2000);
    expect(updated.max, 2500);
    expect(updated.hashCode, isA<int>());
    expect(updated == original, isFalse);
  });

  test('testSetSettingUpVehicleOnlyChangesFromAdapterState', () {
    manager.connectionState = OBDConnectionState.disconnected;
    manager.setSettingUpVehicle();
    expect(manager.connectionState, OBDConnectionState.disconnected);

    manager.connectionState = OBDConnectionState.connectedToAdapter;
    manager.setSettingUpVehicle();
    expect(manager.connectionState, OBDConnectionState.settingUpVehicle);
  });

  test('testStateStreamsEmitInitialValues', () async {
    expect(
      await manager.connectionStateStream.first,
      OBDConnectionState.disconnected,
    );
    expect(await manager.pidStatsStream.first, isEmpty);
    expect(await manager.diagnosticsStream.first, isNull);
    expect(await manager.fuelStatusStream.first, isNull);
    expect(await manager.milStatusStream.first, isNull);
  });

  test('testDisconnectClearsTerminalStateData', () {
    manager.pidStats = {
      '010C': PIDStats(
        pid: '010C',
        latest: obd2lib.MeasurementResult(2500, obd2lib.Unit.rpm),
      ),
    };
    manager.troubleCodes = const [];
    manager.fuelStatus = const [];
    manager.connectedPeripheralName = 'Demo Adapter';

    manager.disconnect();

    expect(manager.pidStats, isEmpty);
    expect(manager.troubleCodes, isNull);
    expect(manager.fuelStatus, isNull);
    expect(manager.milStatus, isNull);
    expect(manager.connectedPeripheralName, isNull);
    expect(manager.connectionState, OBDConnectionState.disconnected);
  });

  test('testConnectIsIgnoredWhenAlreadyConnecting', () async {
    manager.connectionState = OBDConnectionState.connecting;

    await manager.connect();

    expect(manager.connectionState, OBDConnectionState.connecting);
  });

  test('testConnectIsIgnoredWhenAlreadyConnected', () async {
    manager.connectionState = OBDConnectionState.connected;

    await manager.connect();

    expect(manager.connectionState, OBDConnectionState.connected);
  });

  test('testWifiConnectRefusedSetsFailedState', () async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final closedPort = socket.port;
    await socket.close();

    ConfigData.instance.connectionType = ConnectionType.wifi;
    ConfigData.instance.wifiHost = '127.0.0.1';
    ConfigData.instance.wifiPort = closedPort;

    manager.updateConnectionDetails();
    await manager.connect();

    expect(manager.connectionState, OBDConnectionState.failed);
  });

  /// Covers LE-unsupported prereq without loading the FlutterBluePlus platform.
  test('testBluetoothPrepFailedWhenLeUnsupportedOverride', () async {
    OBDConnectionManager.debugBluetoothIsSupportedOverride = () async => false;

    ConfigData.instance.connectionType = ConnectionType.bluetooth;
    manager.updateConnectionDetails();
    await manager.connect();

    expect(manager.connectionState, OBDConnectionState.failed);
  });

  /// Adapter already on: skips plugin adapter stream and exercises handshake entry.
  test('testBluetoothPrepWithAdapterOnOverride', () async {
    OBDConnectionManager.debugBluetoothIsSupportedOverride = () async => true;
    OBDConnectionManager.debugBluetoothInitialAdapterStateOverride =
        () async => BluetoothAdapterState.on;

    ConfigData.instance.connectionType = ConnectionType.bluetooth;
    manager.updateConnectionDetails();
    await manager.connect().timeout(const Duration(seconds: 60));

    expect(manager.connectionState, OBDConnectionState.failed);
  });

  /// Adapter off path: turnOn() is unavailable in tests and should fail gracefully.
  test('testBluetoothPrepFailsWhenAdapterOffAndTurnOnUnavailable', () async {
    OBDConnectionManager.debugBluetoothIsSupportedOverride = () async => true;
    OBDConnectionManager.debugBluetoothInitialAdapterStateOverride =
        () async => BluetoothAdapterState.off;

    ConfigData.instance.connectionType = ConnectionType.bluetooth;
    manager.updateConnectionDetails();
    await manager.connect();

    expect(manager.connectionState, OBDConnectionState.failed);
  });
}
