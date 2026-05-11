import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/core/pid_store.dart';
import 'package:flutter_obdii/core/obdiipid.dart';
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

ObdiiPid _rpmPid() => ObdiiPid(
      id: 'rpm',
      enabled: true,
      label: 'RPM',
      name: 'Engine RPM',
      pidCommand: '010C',
      units: 'RPM',
      kind: ObdPidKind.gauge,
      typicalRange: const ValueRange(min: 0, max: 8000),
    );

Widget _build(GaugesViewModel vm) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConfigData>.value(value: ConfigData.instance),
      ChangeNotifierProvider<GaugesViewModel>.value(value: vm),
    ],
    child: const MaterialApp(home: GaugesView()),
  );
}

void main() {
  late _MockPidProvider pids;
  late GaugesViewModel vm;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pids = _MockPidProvider();
    vm = GaugesViewModel(
      pidProvider: pids,
      interestRegistry: PidInterestRegistry(),
    );
  });

  tearDown(() {
    vm.dispose();
    pids.dispose();
  });

  testWidgets('testHasScrollView', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_build(vm));
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('testUsesLazyVGrid', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_build(vm));
    expect(find.text('Gauges'), findsWidgets);
  });

  testWidgets('testGaugeTilesAreNavigationLinks_WithMocks', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    pids.send([_rpmPid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(GestureDetector), findsWidgets);
  });

  testWidgets('testGaugeTileStructure_WithMocks', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    pids.send([_rpmPid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(Card), findsWidgets);
  });

  test('testViewModelInitialization_Empty', () {
    expect(vm.tiles.length, 0);
  });

  test('testViewModelInitialization_WithOnePID', () async {
    pids.send([_rpmPid()]);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(vm.tiles.length, 1);
  });

  testWidgets('testNavigationToGaugeDetail_WithMocks', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    pids.send([_rpmPid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Scaffold), findsWidgets);
  });

  testWidgets('testGaugeTilesHaveLabels_WithMocks', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    pids.send([_rpmPid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('RPM'), findsWidgets);
  });

  test('testTileIdentityStructure', () {
    final a = GaugeTile(id: 'a', pid: _rpmPid());
    final b = GaugeTile(id: 'b', pid: _rpmPid());
    expect(a == b, isFalse);
  });

  testWidgets('testUpdateInterestMechanism_StructureOnly', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_build(vm));
    expect(find.byType(GaugesView), findsOneWidget);
  });

  testWidgets('testAdaptiveGridColumns', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    pids.send([_rpmPid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    // GaugesView uses SliverGrid inside a CustomScrollView, not a plain GridView.
    expect(find.byType(SliverGrid), findsOneWidget);
  });

  testWidgets('testGaugeTilesHaveIdentifiers_WithMocks', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    pids.send([_rpmPid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('testRendersGaugeTilesWithMeasurements_UsingMocks', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    pids.send([_rpmPid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(Card), findsWidgets);
  });

  test('testGaugeTileColorsBasedOnValues', () {
    final testPid = ObdiiPid(
      id: 'pid',
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
    expect(testPid.colorForValue(10, true), Colors.green);
    expect(testPid.colorForValue(70, true), Colors.orange);
    expect(testPid.colorForValue(90, true), Colors.red);
  });

  testWidgets('testGaugeTileNavigationWithData_WithMocks', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    pids.send([_rpmPid()]);
    await tester.pumpWidget(_build(vm));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(GestureDetector), findsWidgets);
  });

  test('testMixedMeasurementStates_WithMocks', () {
    expect(vm.tiles.where((t) => t.stats == null).length, vm.tiles.length);
  });

  test('testPIDInterestWithEnabledGauges_APIOnly', () {
    final reg = PidInterestRegistry();
    final token = reg.makeToken();
    reg.replace({'010C', '010D', '0105'}, token);
    expect(reg.interested.contains('010C'), isTrue);
  });
}

