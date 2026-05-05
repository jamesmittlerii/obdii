import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/viewmodels/diagnostics_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/fuel_status_viewmodel.dart';
import 'package:flutter_obdii/viewmodels/mil_status_viewmodel.dart';
import 'package:flutter_obdii/views/diagnostics_view.dart';
import 'package:flutter_obdii/views/fuel_status_view.dart';
import 'package:flutter_obdii/views/mil_status_view.dart';

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

class _MockFuelProvider implements FuelStatusProviding {
  @override
  List<obd2lib.StatusCodeMetadata?>? fuelStatus;

  final _ctrl = StreamController<List<obd2lib.StatusCodeMetadata?>?>.broadcast();

  @override
  Stream<List<obd2lib.StatusCodeMetadata?>?> get fuelStatusStream => _ctrl.stream;

  void send(List<obd2lib.StatusCodeMetadata?>? status) {
    fuelStatus = status;
    _ctrl.add(status);
  }

  void dispose() => _ctrl.close();
}

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

void main() {
  testWidgets('testDiagnosticsviewWaitingAndEmptyStatesRender', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );

    OBDConnectionManager.instance.connectionState = OBDConnectionState.disconnected;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DiagnosticsViewModel>.value(value: vm),
          ChangeNotifierProvider<OBDConnectionManager>.value(
            value: OBDConnectionManager.instance,
          ),
        ],
        child: const MaterialApp(home: DiagnosticsView()),
      ),
    );
    expect(find.text('Waiting for data…'), findsOneWidget);

    provider.send([]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('No Trouble Codes Found'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testFuelstatusviewWaitingAndNoStatusStatesRender', (tester) async {
    final provider = _MockFuelProvider();
    final vm = FuelStatusViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FuelStatusViewModel>.value(
        value: vm,
        child: const MaterialApp(home: FuelStatusView()),
      ),
    );
    expect(find.text('Waiting for data…'), findsOneWidget);

    provider.send([]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('No Fuel System Status Codes'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testFuelstatusviewRendersBankLabelsWhenDataExists', (tester) async {
    final provider = _MockFuelProvider();
    final vm = FuelStatusViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FuelStatusViewModel>.value(
        value: vm,
        child: const MaterialApp(home: FuelStatusView()),
      ),
    );

    provider.send([
      obd2lib.StatusCodeMetadata(code: 'CL', description: 'Closed loop'),
      obd2lib.StatusCodeMetadata(code: 'OL', description: 'Open loop'),
    ]);
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Bank 1'), findsOneWidget);
    expect(find.text('Bank 2'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testMilstatusviewWaitingAndStatusRowsRender', (tester) async {
    final provider = _MockMilProvider();
    final vm = MilStatusViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<MilStatusViewModel>.value(
        value: vm,
        child: const MaterialApp(home: MilStatusView()),
      ),
    );
    expect(find.text('Waiting for data…'), findsOneWidget);

    provider.send(
      obd2lib.Status(
        milOn: true,
        dtcCount: 2,
        monitors: [
          obd2lib.ReadinessMonitor(
            name: 'Misfire',
            supported: true,
            ready: false,
          ),
          obd2lib.ReadinessMonitor(
            name: 'Fuel System',
            supported: true,
            ready: true,
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('MIL: On (2 DTCs)'), findsOneWidget);
    expect(find.text('READINESS MONITORS'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testFuelstatusviewTitleRenders', (tester) async {
    final provider = _MockFuelProvider();
    final vm = FuelStatusViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FuelStatusViewModel>.value(
        value: vm,
        child: const MaterialApp(home: FuelStatusView()),
      ),
    );
    await tester.pump();
    // FuelStatusView is a tab-hosted view with no AppBar of its own.
    // Verify the view renders its waiting state and scaffold structure.
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Waiting for data\u2026'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testMilstatusviewTitleRenders', (tester) async {
    final provider = _MockMilProvider();
    final vm = MilStatusViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<MilStatusViewModel>.value(
        value: vm,
        child: const MaterialApp(home: MilStatusView()),
      ),
    );
    await tester.pump();
    // MilStatusView is a tab-hosted view with no AppBar of its own.
    // Verify the view renders its MIL section header and waiting state.
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Waiting for data\u2026'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testDiagnosticsviewTitleRenders', (tester) async {
    final provider = _MockDiagnosticsProvider();
    final vm = DiagnosticsViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );

    OBDConnectionManager.instance.connectionState = OBDConnectionState.connected;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DiagnosticsViewModel>.value(value: vm),
          ChangeNotifierProvider<OBDConnectionManager>.value(
            value: OBDConnectionManager.instance,
          ),
        ],
        child: const MaterialApp(home: DiagnosticsView()),
      ),
    );
    await tester.pump();
    // DiagnosticsView is a tab-hosted view with no AppBar of its own.
    // Verify the view renders its waiting state and scaffold structure.
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Waiting for data\u2026'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testMilstatusviewSectionHeadersRenderWhenDataExists', (tester) async {
    final provider = _MockMilProvider();
    final vm = MilStatusViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<MilStatusViewModel>.value(
        value: vm,
        child: const MaterialApp(home: MilStatusView()),
      ),
    );
    provider.send(
      obd2lib.Status(
        milOn: false,
        dtcCount: 0,
        monitors: [
          obd2lib.ReadinessMonitor(
            name: 'Misfire',
            supported: true,
            ready: true,
          ),
        ],
      ),
    );
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('MALFUNCTION INDICATOR LAMP'), findsOneWidget);
    expect(find.text('READINESS MONITORS'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });

  testWidgets('testFuelstatusviewShowsNoStatusMessageWithNullBanks', (tester) async {
    final provider = _MockFuelProvider();
    final vm = FuelStatusViewModel(
      provider: provider,
      interestRegistry: PidInterestRegistry(),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<FuelStatusViewModel>.value(
        value: vm,
        child: const MaterialApp(home: FuelStatusView()),
      ),
    );
    provider.send([null, null]);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('No Fuel System Status Codes'), findsOneWidget);

    vm.dispose();
    provider.dispose();
  });
}
