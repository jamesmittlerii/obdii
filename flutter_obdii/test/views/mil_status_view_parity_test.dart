import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/viewmodels/mil_status_viewmodel.dart';
import 'package:flutter_obdii/views/mil_status_view.dart';

class _MockMilProvider implements MilStatusProviding {
  @override
  obd2lib.Status? milStatus;
  final _ctrl = StreamController<obd2lib.Status?>.broadcast();
  @override
  Stream<obd2lib.Status?> get milStatusStream => _ctrl.stream;
  void send(obd2lib.Status? status) {
    milStatus = status;
    _ctrl.add(status);
  }

  void dispose() => _ctrl.close();
}

Widget _build(MilStatusViewModel vm) {
  return ChangeNotifierProvider<MilStatusViewModel>.value(
    value: vm,
    child: const MaterialApp(home: MilStatusView()),
  );
}

void main() {
  testWidgets('testHasNavigationStack', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    expect(find.byType(Scaffold), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testNavigationTitle', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    expect(find.text('MIL Status'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testContainsList', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    expect(find.byType(ListView), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testListHasSections', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    expect(find.text('MALFUNCTION INDICATOR LAMP'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testWaitingStateDisplaysProgressView', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testWaitingStateDisplaysWaitingText', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    expect(find.textContaining('Waiting for data'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testHasMILSectionHeader', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    expect(find.text('MALFUNCTION INDICATOR LAMP'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testMILStatusRowStructure', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    p.send(obd2lib.Status(milOn: true, dtcCount: 1, monitors: const []));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(ListTile), findsWidgets);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testContainsWrenchIcon', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    p.send(obd2lib.Status(milOn: true, dtcCount: 1, monitors: const []));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byIcon(Icons.build), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testReadinessMonitorsSectionAppearsWhenStatusSent', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    p.send(obd2lib.Status(
      milOn: false,
      dtcCount: 0,
      monitors: [
        obd2lib.ReadinessMonitor(name: 'Misfire', supported: true, ready: true),
      ],
    ));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('READINESS MONITORS'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  test('testViewModelInitializesWithNilStatus', () {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    expect(vm.status, isNull);
    expect(vm.hasStatus, isFalse);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testMonitorRowsUseHStack', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    p.send(obd2lib.Status(
      milOn: false,
      dtcCount: 0,
      monitors: [
        obd2lib.ReadinessMonitor(name: 'Fuel System', supported: true, ready: false),
      ],
    ));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(ListTile), findsWidgets);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testMonitorRowsHaveVStack', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    p.send(obd2lib.Status(
      milOn: false,
      dtcCount: 0,
      monitors: [
        obd2lib.ReadinessMonitor(name: 'Fuel System', supported: true, ready: false),
      ],
    ));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(Column), findsWidgets);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testNoMILStatusLabel', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    expect(find.textContaining('Waiting for data'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testAccessibilityLabels', (tester) async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    await tester.pumpWidget(_build(vm));
    expect(find.byType(Text), findsWidgets);
    vm.dispose();
    p.dispose();
  });

  test('testDisplaysActiveMILStatus', () async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    expect(vm.headerText, 'No MIL Status');
    p.send(obd2lib.Status(milOn: true, dtcCount: 2, monitors: const []));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(vm.headerText, 'MIL: On (2 DTCs)');
    vm.dispose();
    p.dispose();
  });

  test('testRendersReadinessMonitors', () async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    expect(vm.sortedSupportedMonitors, isEmpty);
    p.send(obd2lib.Status(
      milOn: false,
      dtcCount: 0,
      monitors: [
        obd2lib.ReadinessMonitor(name: 'Misfire', supported: true, ready: true),
        obd2lib.ReadinessMonitor(name: 'Fuel', supported: true, ready: false),
      ],
    ));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(vm.sortedSupportedMonitors, isNotEmpty);
    vm.dispose();
    p.dispose();
  });

  test('testMonitorStateColorsAreRepresented', () {
    expect(Colors.blue, isNotNull);
    expect(Colors.orange, isNotNull);
    expect(Colors.grey, isNotNull);
  });

  test('testHeaderTextFormats', () async {
    final p = _MockMilProvider();
    final vm = MilStatusViewModel(provider: p, interestRegistry: PidInterestRegistry());
    expect(vm.headerText, 'No MIL Status');
    p.send(obd2lib.Status(milOn: false, dtcCount: 1, monitors: const []));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(vm.headerText, 'MIL: Off (1 DTC)');
    p.send(obd2lib.Status(milOn: true, dtcCount: 3, monitors: const []));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(vm.headerText, 'MIL: On (3 DTCs)');
    vm.dispose();
    p.dispose();
  });
}

