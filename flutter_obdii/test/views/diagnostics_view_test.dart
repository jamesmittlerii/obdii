import 'dart:async';

import 'package:flutter/material.dart';
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

Widget _build( DiagnosticsViewModel vm, OBDConnectionManager mgr) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DiagnosticsViewModel>.value(value: vm),
      ChangeNotifierProvider<OBDConnectionManager>.value(value: mgr),
    ],
    child: const MaterialApp(home: DiagnosticsView()),
  );
}

void main() {
  testWidgets('testShowsWaitingStateAndConnectHintWhenDisconnected', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );
    final mgr = OBDConnectionManager.instance;
    mgr.connectionState = OBDConnectionState.disconnected;

    await tester.pumpWidget(_build(vm, mgr));

    expect(find.text('Waiting for data…'), findsOneWidget);
    expect(find.text('Connect to a vehicle in Settings.'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testShowsEmptyStateWhenCodesLoadAsEmptyList', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );
    final mgr = OBDConnectionManager.instance;
    mgr.connectionState = OBDConnectionState.connected;

    await tester.pumpWidget(_build(vm, mgr));
    provider.send([]);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('No Trouble Codes Found'), findsOneWidget);
    expect(find.text('All systems normal.'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testRendersGroupedSectionHeadersAndRowsForLoadedCodes', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );
    final mgr = OBDConnectionManager.instance;
    mgr.connectionState = OBDConnectionState.connected;

    await tester.pumpWidget(_build(vm, mgr));
    provider.send([_dtc('P0001', 'High'), _dtc('P0002', 'Critical')]);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.textContaining('P0001'), findsOneWidget);
    expect(find.textContaining('P0002'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testTappingADTCRowOpensDetailView', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );
    final mgr = OBDConnectionManager.instance;
    mgr.connectionState = OBDConnectionState.connected;

    await tester.pumpWidget(_build(vm, mgr));
    provider.send([_dtc('P0001', 'High')]);
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.textContaining('P0001'));
    await tester.pumpAndSettle();

    expect(find.text('P0001'), findsWidgets);
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('DESCRIPTION'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testDoesNotShowConnectHintWhileConnectedAndWaiting', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );
    final mgr = OBDConnectionManager.instance;
    mgr.connectionState = OBDConnectionState.connected;

    await tester.pumpWidget(_build(vm, mgr));
    await tester.pump();

    expect(find.text('Waiting for data…'), findsOneWidget);
    expect(find.text('Connect to a vehicle in Settings.'), findsNothing);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testDetailViewRendersCausesAndRemediesHeaders', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );
    final mgr = OBDConnectionManager.instance;
    mgr.connectionState = OBDConnectionState.connected;

    await tester.pumpWidget(_build(vm, mgr));
    provider.send([_dtc('P0008', 'Moderate')]);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.textContaining('P0008'));
    await tester.pumpAndSettle();

    expect(find.text('POTENTIAL CAUSES'), findsOneWidget);
    expect(find.text('POSSIBLE REMEDIES'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testSeverityIconAppearsForRenderedDTCRow', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );
    final mgr = OBDConnectionManager.instance;
    mgr.connectionState = OBDConnectionState.connected;

    await tester.pumpWidget(_build(vm, mgr));
    provider.send([_dtc('P0010', 'Critical')]);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testDetailShowsLabeledRowsForCodeAndSeverity', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );
    final mgr = OBDConnectionManager.instance;
    mgr.connectionState = OBDConnectionState.connected;

    await tester.pumpWidget(_build(vm, mgr));
    provider.send([_dtc('P0012', 'High')]);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.textContaining('P0012'));
    await tester.pumpAndSettle();

    expect(find.text('Code'), findsOneWidget);
    expect(find.text('Severity'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testRowSubtitleContainsSeverityText', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );
    final mgr = OBDConnectionManager.instance;
    mgr.connectionState = OBDConnectionState.connected;

    await tester.pumpWidget(_build(vm, mgr));
    provider.send([_dtc('P0013', 'Low')]);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Low'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });
}
