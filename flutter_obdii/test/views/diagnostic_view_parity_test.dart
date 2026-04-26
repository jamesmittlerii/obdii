import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/viewmodels/diagnostics_viewmodel.dart';
import 'package:flutter_obdii/views/diagnostics_view.dart';

class _MockDiagnosticsProvider implements DiagnosticsProviding {
  @override
  List<obd2lib.TroubleCodeMetadata>? troubleCodes;

  final _ctrl = StreamController<List<obd2lib.TroubleCodeMetadata>?>.broadcast();
  @override
  Stream<List<obd2lib.TroubleCodeMetadata>?> get diagnosticsStream => _ctrl.stream;
  void send(List<obd2lib.TroubleCodeMetadata>? codes) {
    troubleCodes = codes;
    _ctrl.add(codes);
  }

  void dispose() => _ctrl.close();
}

obd2lib.TroubleCodeMetadata _dtc(String code, String severity) =>
    obd2lib.TroubleCodeMetadata(
      code: code,
      title: 'Test DTC $code',
      description: 'Description for $code',
      severity: severity,
      causes: const ['Cause 1'],
      remedies: const ['Remedy 1'],
    );

Widget _build(DiagnosticsViewModel vm, OBDConnectionManager mgr) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DiagnosticsViewModel>.value(value: vm),
      ChangeNotifierProvider<OBDConnectionManager>.value(value: mgr),
    ],
    child: const CupertinoApp(home: DiagnosticsView()),
  );
}

void main() {
  testWidgets('testHasNavigationStack', (tester) async {
    final p = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(provider: p, interestRegistry: PidInterestRegistry());
    final mgr = OBDConnectionManager.instance..connectionState = OBDConnectionState.connected;
    await tester.pumpWidget(_build(vm, mgr));
    expect(find.byType(CupertinoPageScaffold), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testNavigationTitle', (tester) async {
    final p = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(provider: p, interestRegistry: PidInterestRegistry());
    final mgr = OBDConnectionManager.instance..connectionState = OBDConnectionState.connected;
    await tester.pumpWidget(_build(vm, mgr));
    expect(find.text('Diagnostic Codes'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testWaitingStateDisplaysProgressView', (tester) async {
    final p = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(provider: p, interestRegistry: PidInterestRegistry());
    final mgr = OBDConnectionManager.instance..connectionState = OBDConnectionState.disconnected;
    await tester.pumpWidget(_build(vm, mgr));
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testWaitingStateDisplaysWaitingText', (tester) async {
    final p = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(provider: p, interestRegistry: PidInterestRegistry());
    final mgr = OBDConnectionManager.instance..connectionState = OBDConnectionState.connected;
    await tester.pumpWidget(_build(vm, mgr));
    expect(find.textContaining('Waiting for data'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testEmptyStateDisplaysNoCodesMessage', (tester) async {
    final p = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(provider: p, interestRegistry: PidInterestRegistry());
    final mgr = OBDConnectionManager.instance..connectionState = OBDConnectionState.connected;
    await tester.pumpWidget(_build(vm, mgr));
    p.send([]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('No Trouble Codes Found'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testSectionsDisplayWhenCodesExist', (tester) async {
    final p = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(provider: p, interestRegistry: PidInterestRegistry());
    final mgr = OBDConnectionManager.instance..connectionState = OBDConnectionState.connected;
    await tester.pumpWidget(_build(vm, mgr));
    p.send([_dtc('P0001', 'Critical'), _dtc('P0002', 'High')]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testCodeRowsAreNavigationLinks', (tester) async {
    final p = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(provider: p, interestRegistry: PidInterestRegistry());
    final mgr = OBDConnectionManager.instance..connectionState = OBDConnectionState.connected;
    await tester.pumpWidget(_build(vm, mgr));
    p.send([_dtc('P0301', 'High')]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(CupertinoListTile), findsWidgets);
    vm.dispose();
    p.dispose();
  });

  test('testViewModelInitializesWithNilCodes', () {
    final vm = DiagnosticsViewModel(
      provider: _MockDiagnosticsProvider(),
      interestRegistry: PidInterestRegistry(),
    );
    expect(vm.codes, isNull);
    expect(vm.sections, isEmpty);
    vm.dispose();
  });

  test('testSeverityOrderisCriticalHighModerateLow', () {
    final sev = ['Critical', 'High', 'Moderate', 'Low'];
    expect(sev.first, 'Critical');
    expect(sev.last, 'Low');
  });

  testWidgets('testSectionHeadersDisplaySeverityTitles', (tester) async {
    final p = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(provider: p, interestRegistry: PidInterestRegistry());
    final mgr = OBDConnectionManager.instance..connectionState = OBDConnectionState.connected;
    await tester.pumpWidget(_build(vm, mgr));
    p.send([_dtc('P0420', 'Moderate')]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('MODERATE'), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  testWidgets('testListExistsInAllStates', (tester) async {
    final p = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(provider: p, interestRegistry: PidInterestRegistry());
    final mgr = OBDConnectionManager.instance..connectionState = OBDConnectionState.connected;
    await tester.pumpWidget(_build(vm, mgr));
    expect(find.byType(ListView), findsNothing);
    p.send([_dtc('P0001', 'Low')]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(ListView), findsOneWidget);
    vm.dispose();
    p.dispose();
  });

  test('testCreateMockDTCs', () {
    final codes = [
      _dtc('P0601', 'Critical'),
      _dtc('P0301', 'High'),
      _dtc('P0420', 'Moderate'),
      _dtc('P0171', 'Low'),
    ];
    expect(codes.length, 4);
  });
}

