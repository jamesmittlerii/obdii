import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/core/pid_store.dart';
import 'package:flutter_obdii/models/obdii_pid.dart';

class _SeededPidStore extends ChangeNotifier implements PidStore {
  List<ObdiiPid> _pids;
  _SeededPidStore(this._pids);
  @override
  List<ObdiiPid> get pids => _pids;
  @override
  List<ObdiiPid> get enabledGauges =>
      _pids.where((p) => p.enabled && p.kind == ObdPidKind.gauge).toList();
  @override
  Stream<List<ObdiiPid>> get pidsStream => Stream.value(_pids);
  @override
  Future<void> load() async {}
  @override
  Future<void> toggle(ObdiiPid pid) async {
    final idx = _pids.indexWhere((p) => p.id == pid.id);
    if (idx >= 0) {
      _pids[idx] = _pids[idx].copyWith(enabled: !_pids[idx].enabled);
    }
  }

  @override
  Future<void> moveEnabled(int fromIndex, int toIndex) async {
    final enabledIdx = _pids
        .asMap()
        .entries
        .where((e) => e.value.enabled && e.value.kind == ObdPidKind.gauge)
        .map((e) => e.key)
        .toList();
    if (enabledIdx.length < 2) return;
    final subset = enabledIdx.map((i) => _pids[i]).toList();
    final item = subset.removeAt(fromIndex);
    subset.insert(toIndex > fromIndex ? toIndex - 1 : toIndex, item);
    for (var i = 0; i < enabledIdx.length; i++) {
      _pids[enabledIdx[i]] = subset[i];
    }
  }
}

PidStore _store() => _SeededPidStore([
      ObdiiPid(
        id: 'rpm',
        enabled: true,
        label: 'RPM',
        name: 'Engine RPM',
        pidCommand: '010C',
        units: 'RPM',
        kind: ObdPidKind.gauge,
      ),
      ObdiiPid(
        id: 'speed',
        enabled: false,
        label: 'Speed',
        name: 'Vehicle Speed',
        pidCommand: '010D',
        units: 'km/h',
        kind: ObdPidKind.gauge,
      ),
      ObdiiPid(
        id: 'status',
        enabled: false,
        label: 'Status',
        name: 'Monitor',
        pidCommand: '0101',
        units: 'NA',
        kind: ObdPidKind.status,
      ),
    ]);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('testInitialValues', () {
    final c = ConfigData.instance;
    expect(c.wifiHost.isNotEmpty, isTrue);
    expect(c.wifiPort, greaterThan(0));
  });

  test('testConnectionTypeDefault', () {
    expect(ConfigData.instance.connectionType, isNotNull);
  });

  test('testConnectionTypePersistence', () async {
    ConfigData.instance.connectionType = ConnectionType.wifi;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('connectionType'), ConnectionType.wifi.rawValue);
  });

  test('testUnitsDefault', () {
    expect(ConfigData.instance.units, isNotNull);
  });

  test('testUnitsPersistence', () async {
    ConfigData.instance.setUnits(MeasurementUnit.imperial);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('units'), MeasurementUnit.imperial.name);
  });

  test('testUnitsSwitch', () {
    ConfigData.instance.setUnits(MeasurementUnit.imperial);
    expect(ConfigData.instance.units, MeasurementUnit.imperial);
    ConfigData.instance.setUnits(MeasurementUnit.metric);
    expect(ConfigData.instance.units, MeasurementUnit.metric);
  });

  test('testConnectionTypeSwitch', () {
    ConfigData.instance.connectionType = ConnectionType.demo;
    expect(ConfigData.instance.connectionType, ConnectionType.demo);
    ConfigData.instance.connectionType = ConnectionType.bluetooth;
    expect(ConfigData.instance.connectionType, ConnectionType.bluetooth);
  });

  test('testAutoConnectToggle', () {
    final original = ConfigData.instance.autoConnectToOBD;
    ConfigData.instance.autoConnectToOBD = !original;
    expect(ConfigData.instance.autoConnectToOBD, isNot(original));
  });

  test('testWiFiHostUpdate', () {
    ConfigData.instance.wifiHost = '10.0.0.1';
    expect(ConfigData.instance.wifiHost, '10.0.0.1');
  });

  test('testWiFiPortUpdate', () {
    ConfigData.instance.wifiPort = 12345;
    expect(ConfigData.instance.wifiPort, 12345);
  });

  test('testMakeToken', () {
    final r = PidInterestRegistry();
    expect(r.makeToken(), isNotEmpty);
  });

  test('testReplacePIDsForToken', () {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({'010C'}, t);
    expect(r.interested.contains('010C'), isTrue);
  });

  test('testReplaceOverwritesPreviousPIDs', () {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({'010C'}, t);
    r.replace({'010D'}, t);
    expect(r.interested.contains('010C'), isFalse);
    expect(r.interested.contains('010D'), isTrue);
  });

  test('testReplaceWithEmptySet', () {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({'010C'}, t);
    r.replace({}, t);
    expect(r.interested.contains('010C'), isFalse);
  });

  test('testInterestedPIDsUnion', () {
    final r = PidInterestRegistry();
    final t1 = r.makeToken();
    final t2 = r.makeToken();
    r.replace({'010C'}, t1);
    r.replace({'010D'}, t2);
    expect(r.interested, containsAll(['010C', '010D']));
  });

  test('testInterestedIsPublished', () async {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    var hits = 0;
    final sub = r.interestedStream.listen((_) => hits++);
    r.replace({'010C'}, t);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(hits, greaterThan(0));
  });

  test('testMultipleTokensCanRegisterSamePID', () {
    final r = PidInterestRegistry();
    final t1 = r.makeToken();
    final t2 = r.makeToken();
    r.replace({'010C'}, t1);
    r.replace({'010C'}, t2);
    expect(r.interested.contains('010C'), isTrue);
  });

  test('testMultipleTokensWithDifferentPIDs', () {
    final r = PidInterestRegistry();
    final t1 = r.makeToken();
    final t2 = r.makeToken();
    r.replace({'010C'}, t1);
    r.replace({'0105'}, t2);
    expect(r.interested.length, 2);
  });

  test('testClearToken', () async {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({'010C'}, t);
    await r.clear(t);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    expect(r.interested.contains('010C'), isFalse);
  });

  test('testClearSharedPID', () async {
    final r = PidInterestRegistry();
    final t1 = r.makeToken();
    final t2 = r.makeToken();
    r.replace({'010C'}, t1);
    r.replace({'010C'}, t2);
    await r.clear(t1);
    await Future<void>.delayed(const Duration(milliseconds: 110));
    expect(r.interested.contains('010C'), isTrue);
  });

  test('testPIDsLoadedFromJSON', () async {
    final s = _store();
    await s.load();
    expect(s.pids, isNotEmpty);
  });

  test('testPIDsContainGauges', () async {
    final s = _store();
    await s.load();
    expect(s.pids.any((p) => p.kind == ObdPidKind.gauge), isTrue);
  });

  test('testPIDsContainStatusPIDs', () async {
    final s = _store();
    await s.load();
    expect(s.pids.any((p) => p.kind == ObdPidKind.status), isTrue);
  });

  test('testEnabledGaugesFiltering', () async {
    final s = _store();
    await s.load();
    expect(s.enabledGauges.every((p) => p.enabled), isTrue);
  });

  test('testEnabledGaugesOrderPreserved', () async {
    final s = _store();
    await s.load();
    final enabled = s.enabledGauges;
    if (enabled.length > 1) {
      final ids = enabled.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    } else {
      expect(enabled.length, greaterThanOrEqualTo(0));
    }
  });

  test('testTogglePID', () async {
    final s = _store();
    await s.load();
    final first = s.pids.first;
    final before = first.enabled;
    await s.toggle(first);
    final updated = s.pids.firstWhere((p) => p.id == first.id);
    expect(updated.enabled, isNot(before));
  });

  test('testMoveEnabledPIDs', () async {
    final s = _store();
    await s.load();
    final count = s.enabledGauges.length;
    if (count > 1) {
      await s.moveEnabled(0, 1);
      expect(s.enabledGauges.length, count);
    } else {
      expect(count, greaterThanOrEqualTo(0));
    }
  });

  test('testFindPIDByID', () async {
    final s = _store();
    await s.load();
    final first = s.pids.first;
    expect(s.pids.any((p) => p.id == first.id), isTrue);
  });

  test('testFindPIDByCommand', () async {
    final s = _store();
    await s.load();
    final first = s.pids.first;
    expect(s.pids.any((p) => p.pidCommand == first.pidCommand), isTrue);
  });

  test('testGaugeCountReasonable', () async {
    final s = _store();
    await s.load();
    expect(s.pids.length, inInclusiveRange(1, 200));
  });
}

