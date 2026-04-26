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
  MeasurementUnit _units = MeasurementUnit.metric;
  final _ctrl = StreamController<MeasurementUnit>.broadcast();

  @override
  MeasurementUnit get units => _units;

  @override
  Stream<MeasurementUnit> get unitsStream => _ctrl.stream;

  void send(MeasurementUnit u) {
    _units = u;
    _ctrl.add(u);
  }

  void dispose() => _ctrl.close();
}

ObdiiPid _gaugePid({
  required String id,
  required String label,
  required String name,
  required String command,
}) {
  return ObdiiPid(
    id: id,
    enabled: true,
    label: label,
    name: name,
    pidCommand: command,
    units: 'RPM',
    kind: ObdPidKind.gauge,
  );
}

Widget _build(GaugesViewModel vm) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConfigData>.value(value: ConfigData.instance),
      ChangeNotifierProvider<GaugesViewModel>.value(value: vm),
    ],
    child: const CupertinoApp(home: GaugesView()),
  );
}

void main() {
  late _MockPidProvider pidProvider;
  late _MockStatsProvider statsProvider;
  late _MockUnitsProvider unitsProvider;
  late GaugesViewModel viewModel;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    pidProvider = _MockPidProvider();
    statsProvider = _MockStatsProvider();
    unitsProvider = _MockUnitsProvider();
    viewModel = GaugesViewModel(
      pidProvider: pidProvider,
      statsProvider: statsProvider,
      unitsProvider: unitsProvider,
      interestRegistry: PidInterestRegistry(),
    );
  });

  tearDown(() {
    viewModel.dispose();
    pidProvider.dispose();
    statsProvider.dispose();
    unitsProvider.dispose();
  });

  testWidgets('testShowsEmptyStateWhenNoEnabledGaugesExist', (tester) async {
    await tester.pumpWidget(_build(viewModel));
    await tester.pump();

    expect(find.textContaining('No gauges enabled'), findsOneWidget);
  });

  testWidgets('testShowsGaugeTileContentWhenEnabledGaugeExists', (tester) async {
    pidProvider.send([
      _gaugePid(
        id: 'rpm',
        label: 'RPM',
        name: 'Engine RPM',
        command: '010C',
      ),
    ]);
    statsProvider.send({
      '010C': PIDStats(
        pid: '010C',
        latest: obd2lib.MeasurementResult(1200.0, obd2lib.Unit.rpm),
      ),
    });

    await tester.pumpWidget(_build(viewModel));
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('RPM'), findsWidgets);
  });

  testWidgets('testSwitchingSegmentedControlChangesTitleToList', (tester) async {
    pidProvider.send([
      _gaugePid(
        id: 'rpm',
        label: 'RPM',
        name: 'Engine RPM',
        command: '010C',
      ),
    ]);

    await tester.pumpWidget(_build(viewModel));
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(find.text('List'), findsWidgets);
    expect(find.text('GAUGES'), findsOneWidget);
  });

  testWidgets('testListModeShowsRowWithFullGaugeName', (tester) async {
    pidProvider.send([
      _gaugePid(
        id: 'rpm',
        label: 'RPM',
        name: 'Engine RPM',
        command: '010C',
      ),
    ]);

    await tester.pumpWidget(_build(viewModel));
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(find.text('Engine RPM'), findsOneWidget);
  });

  testWidgets('testAppBarTitleDefaultsToGaugesInGaugesMode', (tester) async {
    await tester.pumpWidget(_build(viewModel));
    await tester.pump();
    expect(find.text('Gauges'), findsWidgets);
  });

  testWidgets('testSwitchingBackFromListReturnsGaugesTitle', (tester) async {
    pidProvider.send([
      _gaugePid(id: 'rpm', label: 'RPM', name: 'Engine RPM', command: '010C'),
    ]);
    await tester.pumpWidget(_build(viewModel));
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gauges'));
    await tester.pumpAndSettle();

    expect(find.text('Gauges'), findsWidgets);
  });

  testWidgets('testListModeShowsSectionHeader', (tester) async {
    pidProvider.send([
      _gaugePid(id: 'rpm', label: 'RPM', name: 'Engine RPM', command: '010C'),
    ]);
    await tester.pumpWidget(_build(viewModel));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();

    expect(find.text('GAUGES'), findsOneWidget);
  });

  testWidgets('testSegmentedControlRendersBothOptions', (tester) async {
    await tester.pumpWidget(_build(viewModel));
    await tester.pump();
    expect(find.text('Gauges'), findsWidgets);
    expect(find.text('List'), findsOneWidget);
  });

  testWidgets('testEmptyStateIconIsRenderedWhenNoGauges', (tester) async {
    await tester.pumpWidget(_build(viewModel));
    await tester.pump();
    expect(find.byIcon(CupertinoIcons.speedometer), findsOneWidget);
  });
}
