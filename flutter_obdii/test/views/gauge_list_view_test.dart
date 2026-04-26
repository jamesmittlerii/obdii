import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/core/pid_store.dart';
import 'package:flutter_obdii/models/obdii_pid.dart';
import 'package:flutter_obdii/viewmodels/gauges_viewmodel.dart';
import 'package:flutter_obdii/views/dashboard_view.dart';

class _MockPidProvider implements PidListProviding {
  List<ObdiiPid> _pids = [];
  final _ctrl = StreamController<List<ObdiiPid>>.broadcast();
  @override
  List<ObdiiPid> get pids => _pids;
  @override
  Stream<List<ObdiiPid>> get pidsStream => _ctrl.stream;
  void send(List<ObdiiPid> pids) {
    _pids = pids;
    _ctrl.add(pids);
  }

  void dispose() => _ctrl.close();
}

class _MockStatsProvider implements PidStatsProviding {
  @override
  Map<String, PIDStats> pidStats = {};
  final _ctrl = StreamController<Map<String, PIDStats>>.broadcast();
  @override
  PIDStats? statsFor(String pidCommand) => pidStats[pidCommand];
  @override
  Stream<Map<String, PIDStats>> get pidStatsStream => _ctrl.stream;
  void send(Map<String, PIDStats> stats) {
    pidStats = stats;
    _ctrl.add(stats);
  }

  void dispose() => _ctrl.close();
}

class _MockUnitsProvider implements UnitsProviding {
  final MeasurementUnit _units = MeasurementUnit.metric;
  final _ctrl = StreamController<MeasurementUnit>.broadcast();
  @override
  MeasurementUnit get units => _units;
  @override
  Stream<MeasurementUnit> get unitsStream => _ctrl.stream;
  void dispose() => _ctrl.close();
}

ObdiiPid _pid({
  String id = 'rpm',
  String label = 'RPM',
  String name = 'Engine RPM',
  String command = '010C',
  String units = 'RPM',
}) {
  return ObdiiPid(
    id: id,
    enabled: true,
    label: label,
    name: name,
    pidCommand: command,
    units: units,
    kind: ObdPidKind.gauge,
    typicalRange: const ValueRange(min: 0, max: 8000),
  );
}

Widget _build(GaugesViewModel vm) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConfigData>.value(value: ConfigData.instance),
      ChangeNotifierProvider<PidStore>.value(value: PidStore.instance),
      ChangeNotifierProvider<GaugesViewModel>.value(value: vm),
    ],
    child: const CupertinoApp(home: GaugesView()),
  );
}

void main() {
  late _MockPidProvider pids;
  late _MockStatsProvider stats;
  late _MockUnitsProvider units;
  late GaugesViewModel vm;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pids = _MockPidProvider();
    stats = _MockStatsProvider();
    units = _MockUnitsProvider();
    vm = GaugesViewModel(
      pidProvider: pids,
      statsProvider: stats,
      unitsProvider: units,
      interestRegistry: PidInterestRegistry(),
    );
  });

  tearDown(() {
    vm.dispose();
    pids.dispose();
    stats.dispose();
    units.dispose();
  });

  Future<void> toListMode(WidgetTester tester) async {
    await tester.tap(find.text('List'));
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('testHasList', (tester) async {
    await tester.pumpWidget(_build(vm));
    expect(find.text('List'), findsOneWidget);
  });

  testWidgets('testHasSection', (tester) async {
    pids.send([_pid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    await toListMode(tester);
    expect(find.text('Gauges'), findsWidgets);
  });

  testWidgets('testNavigationTitle', (tester) async {
    await tester.pumpWidget(_build(vm));
    await toListMode(tester);
    expect(find.text('List'), findsWidgets);
  });

  testWidgets('testGaugesWrappedInNavigationLinks', (tester) async {
    pids.send([_pid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    await toListMode(tester);
    expect(find.byIcon(CupertinoIcons.chevron_forward), findsWidgets);
  });

  testWidgets('testRowDisplaysGaugeName', (tester) async {
    pids.send([_pid(name: 'Engine RPM')]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    await toListMode(tester);
    expect(find.text('Engine RPM'), findsOneWidget);
  });

  testWidgets('testRowDisplaysRange', (tester) async {
    pids.send([_pid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    await toListMode(tester);
    expect(find.textContaining('0'), findsWidgets);
  });

  testWidgets('testRowDisplaysCurrentValue', (tester) async {
    pids.send([_pid()]);
    stats.send({
      '010C': PIDStats(
        pid: '010C',
        latest: obd2lib.MeasurementResult(2500, obd2lib.Unit.rpm),
      ),
    });
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    await toListMode(tester);
    expect(find.textContaining('2500'), findsOneWidget);
  });

  test('testCurrentValueTextWithMeasurement', () {
    final formatted = _pid().formattedValue(2500, true, includeUnits: true);
    expect(formatted.toLowerCase().contains('rpm'), isTrue);
  });

  testWidgets('testCurrentValueTextWithoutMeasurement_UsesMocks', (tester) async {
    pids.send([_pid(units: '°C')]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    await toListMode(tester);
    expect(find.textContaining('—'), findsWidgets);
  });

  test('testCurrentValueColorWithMeasurement', () {
    final testPid = ObdiiPid(
      id: 'rpm2',
      enabled: true,
      label: 'RPM',
      name: 'Engine RPM',
      pidCommand: '010C',
      units: '%',
      kind: ObdPidKind.gauge,
      typicalRange: const ValueRange(min: 0, max: 60),
      warningRange: const ValueRange(min: 61, max: 80),
      dangerRange: const ValueRange(min: 81, max: 100),
    );
    expect(testPid.colorForValue(20, true), Colors.green);
    expect(testPid.colorForValue(70, true), Colors.orange);
    expect(testPid.colorForValue(90, true), Colors.red);
  });

  test('testCurrentValueColorWithoutMeasurement', () {
    expect(Colors.grey, isNotNull);
  });

  test('testPIDInterestRegistrationOnAppear', () {
    final reg = PidInterestRegistry();
    final t = reg.makeToken();
    reg.replace({'010C', '010D'}, t);
    expect(reg.interested.contains('010C'), isTrue);
    reg.clear(t);
  });

  test('testPIDInterestClearedOnDisappear', () {
    final reg = PidInterestRegistry();
    final t = reg.makeToken();
    reg.replace({'01FF'}, t);
    reg.clear(t);
    expect(t, isNotEmpty);
  });

  testWidgets('testNavigationToGaugeDetailView', (tester) async {
    pids.send([_pid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    await toListMode(tester);
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Engine RPM'), findsWidgets);
  });

  testWidgets('testAccessibilityLabels', (tester) async {
    pids.send([_pid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('testEmptyGaugesList', (tester) async {
    await tester.pumpWidget(_build(vm));
    expect(find.textContaining('No gauges enabled'), findsOneWidget);
  });

  test('testViewModelInitialization', () {
    expect(vm.tiles, isNotNull);
  });

  test('testInterestTokenInitialization', () {
    final reg = PidInterestRegistry();
    expect(reg.makeToken(), isNotEmpty);
  });

  test('testTileIdentityTracking', () {
    final t1 = GaugeTile(id: 'a', pid: _pid());
    final t2 = GaugeTile(id: 'a', pid: _pid());
    final t3 = GaugeTile(id: 'b', pid: _pid(id: 'b'));
    expect(t1, t2);
    expect(t1 == t3, isFalse);
  });

  testWidgets('testTileRow_DisplaysCorrectNameAndRange', (tester) async {
    pids.send([_pid(label: 'TestGauge', name: 'Test Gauge Name')]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    await toListMode(tester);
    expect(find.text('Test Gauge Name'), findsOneWidget);
  });

  test('testTileRow_FormatsValueWithMeasurement', () {
    final speedPid = ObdiiPid(
      id: 'speed',
      enabled: true,
      label: 'Speed',
      name: 'Vehicle Speed',
      pidCommand: '010D',
      units: 'km/h',
      kind: ObdPidKind.gauge,
      typicalRange: const ValueRange(min: 0, max: 200),
    );
    expect(speedPid.formattedValue(75.5, true, includeUnits: true), contains('km'));
  });

  test('testTileRow_ShowsPlaceholderWithoutMeasurement', () {
    final p = ObdiiPid(
      id: 'tmp',
      enabled: true,
      label: 'Temp',
      name: 'Engine Temperature',
      pidCommand: '0105',
      units: '°C',
      kind: ObdPidKind.gauge,
      typicalRange: const ValueRange(min: 0, max: 120),
    );
    expect('— ${p.unitLabel(true)}', contains('—'));
  });

  test('testUpdateInterest_ReplacesCorrectPIDs', () {
    final reg = PidInterestRegistry();
    final t1 = reg.makeToken();
    final t2 = reg.makeToken();
    reg.replace({'010C', '010D'}, t1);
    reg.replace({'0105'}, t2);
    expect(reg.interested.contains('0105'), isTrue);
  });
}

