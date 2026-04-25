import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final manager = OBDConnectionManager.instance;

  setUp(() {
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
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(manager.connectionState, OBDConnectionState.connected);
  });

  test('testDisconnectFromConnectedState', () async {
    ConfigData.instance.connectionType = ConnectionType.demo;
    manager.updateConnectionDetails();
    await manager.connect();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    manager.disconnect();
    expect(manager.connectionState, OBDConnectionState.disconnected);
    expect(manager.pidStats, isEmpty);
  });

  test('testMultipleConnectAttempts', () async {
    ConfigData.instance.connectionType = ConnectionType.demo;
    manager.updateConnectionDetails();
    await manager.connect();
    await manager.connect();
    await Future<void>.delayed(const Duration(milliseconds: 400));
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
}

