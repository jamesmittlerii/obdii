// Port of ConfigDataTests.swift — Jim Mittler
// Unit tests for ConfigData singleton.
// Tests initial values, property updates, connection type switching,
// unit switching, auto-connect toggle, and persistence to SharedPreferences.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/constants.dart';

void main() {
  setUp(() async {
    // SharedPreferences.setMockInitialValues must be called before each test
    SharedPreferences.setMockInitialValues({});
    // Reset to defaults manually since ConfigData is a singleton
    final cd = ConfigData.instance;
    cd.wifiHost = defaultWifiHost;
    cd.wifiPort = 35000;
    cd.autoConnectToOBD = true;
    cd.connectionType = ConnectionType.bluetooth;
    cd.setUnits(MeasurementUnit.metric);
    cd.hasCompletedOnboarding = false;
  });

  test('testSingletonInstanceExists', () {
    expect(ConfigData.instance, isNotNull);
  });

  // ── Initial values ──────────────────────────────

  group('initial values', () {
    test('testWifihostDefault', () {
      expect(ConfigData.instance.wifiHost, defaultWifiHost);
    });

    test('testWifiportDefault', () {
      expect(ConfigData.instance.wifiPort, 35000);
    });

    test('testAutoconnecttoobdDefault', () {
      expect(ConfigData.instance.autoConnectToOBD, isTrue);
    });
  });

  // ── WiFi Host ───────────────────────────────────

  test('testWifihostUpdates', () {
    const newHost = '192.168.1.100';
    ConfigData.instance.wifiHost = newHost;
    expect(ConfigData.instance.wifiHost, newHost);
  });

  // ── WiFi Port ───────────────────────────────────

  test('testWifiportUpdates', () {
    const newPort = 35001;
    ConfigData.instance.wifiPort = newPort;
    expect(ConfigData.instance.wifiPort, newPort);
  });

  test('testWifiportValidRange', () {
    const validPort = 8080;
    ConfigData.instance.wifiPort = validPort;
    expect(ConfigData.instance.wifiPort, validPort);
    expect(ConfigData.instance.wifiPort, greaterThan(0));
    expect(ConfigData.instance.wifiPort, lessThanOrEqualTo(65535));
  });

  // ── Connection Type ─────────────────────────────

  test('testConnectiontypeDefaultIsBluetooth', () {
    expect(ConfigData.instance.connectionType, ConnectionType.bluetooth);
  });

  test('testConnectiontypeSwitchesThroughAllValues', () {
    ConfigData.instance.connectionType = ConnectionType.wifi;
    expect(ConfigData.instance.connectionType, ConnectionType.wifi);

    ConfigData.instance.connectionType = ConnectionType.demo;
    expect(ConfigData.instance.connectionType, ConnectionType.demo);

    ConfigData.instance.connectionType = ConnectionType.bluetooth;
    expect(ConfigData.instance.connectionType, ConnectionType.bluetooth);
  });

  // ── Units ───────────────────────────────────────

  test('testUnitsDefaultIsMetric', () {
    expect(ConfigData.instance.units, MeasurementUnit.metric);
  });

  test('testUnitsSwitchesToImperialAndBack', () {
    ConfigData.instance.setUnits(MeasurementUnit.imperial);
    expect(ConfigData.instance.units, MeasurementUnit.imperial);

    ConfigData.instance.setUnits(MeasurementUnit.metric);
    expect(ConfigData.instance.units, MeasurementUnit.metric);
  });

  // ── Auto-connect ────────────────────────────────

  test('testAutoconnecttoobdToggles', () {
    ConfigData.instance.autoConnectToOBD = false;
    expect(ConfigData.instance.autoConnectToOBD, isFalse);

    ConfigData.instance.autoConnectToOBD = true;
    expect(ConfigData.instance.autoConnectToOBD, isTrue);
  });

  // ── Persistence via SharedPreferences ──────────

  test('testWifihostPersists', () async {
    const testHost = '10.0.0.1';
    ConfigData.instance.wifiHost = testHost;

    // Allow async persist to complete
    await Future.delayed(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('wifiHost'), testHost);
  });

  test('testConnectiontypePersistsRawValue', () async {
    ConfigData.instance.connectionType = ConnectionType.wifi;

    await Future.delayed(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('connectionType'), ConnectionType.wifi.rawValue);
  });

  test('testUnitsPersistsName', () async {
    ConfigData.instance.setUnits(MeasurementUnit.imperial);

    await Future.delayed(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('units'), MeasurementUnit.imperial.name);
  });

  // ── Streams ─────────────────────────────────────

  test('testUnitsstreamEmitsWhenUnitsChange', () async {
    final values = <MeasurementUnit>[];
    final sub = ConfigData.instance.unitsStream.listen(values.add);

    ConfigData.instance.setUnits(MeasurementUnit.imperial);
    await Future.delayed(const Duration(milliseconds: 50));
    sub.cancel();

    expect(values, contains(MeasurementUnit.imperial));
  });

  test('testConnectiontypestreamEmitsWhenTypeChanges', () async {
    final values = <ConnectionType>[];
    final sub = ConfigData.instance.connectionTypeStream.listen(values.add);

    ConfigData.instance.connectionType = ConnectionType.wifi;
    await Future.delayed(const Duration(milliseconds: 50));
    sub.cancel();

    expect(values, contains(ConnectionType.wifi));
  });

  test('testSettingSameUnitsValueKeepsValueStable', () async {
    ConfigData.instance.setUnits(MeasurementUnit.metric);
    await Future.delayed(const Duration(milliseconds: 10));
    expect(ConfigData.instance.units, MeasurementUnit.metric);
  });

  test('testAutoconnecttoobdPersists', () async {
    ConfigData.instance.autoConnectToOBD = false;
    await Future.delayed(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('autoConnectToOBD'), isFalse);
  });

  test('onboarding completion persists in backing store', () async {
    ConfigData.instance.hasCompletedOnboarding = true;
    await Future.delayed(const Duration(milliseconds: 100));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasCompletedOnboarding'), isTrue);
    expect(ConfigData.instance.hasCompletedOnboarding, isTrue);
  });
}
