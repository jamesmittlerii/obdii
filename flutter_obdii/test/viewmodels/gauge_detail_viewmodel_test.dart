// Port of GaugeDetailViewModelTests.swift — Jim Mittler
// Tests PID statistics tracking, Combine → Stream subscriptions,
// units change handling, and deduplication.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/models/obdii_pid.dart';
import 'package:flutter_obdii/viewmodels/gauge_detail_viewmodel.dart';

// ─────────────────────────────────────────────
// Mocks
// ─────────────────────────────────────────────

class MockStatsProvider implements PidStatsProviding {
  @override
  Map<String, PIDStats> pidStats = {};

  final _ctrl = StreamController<Map<String, PIDStats>>.broadcast();

  @override
  Stream<Map<String, PIDStats>> get pidStatsStream => _ctrl.stream;

  @override
  PIDStats? statsFor(String cmd) => pidStats[cmd];

  void send(Map<String, PIDStats> stats) {
    pidStats = stats;
    _ctrl.add(stats);
  }

  void dispose() => _ctrl.close();
}

class MockUnitsProvider implements UnitsProviding {
  MeasurementUnit _units = MeasurementUnit.metric;

  @override
  MeasurementUnit get units => _units;

  final _ctrl = StreamController<MeasurementUnit>.broadcast();

  @override
  Stream<MeasurementUnit> get unitsStream => _ctrl.stream;

  void send(MeasurementUnit u) {
    _units = u;
    _ctrl.add(u);
  }

  void dispose() => _ctrl.close();
}

// ─────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────

void main() {
  late MockStatsProvider statsProvider;
  late MockUnitsProvider unitsProvider;
  late GaugeDetailViewModel viewModel;
  late ObdiiPid testPid;

  setUp(() {
    testPid = ObdiiPid(
      id: 'rpm_test',
      enabled: true,
      label: 'RPM',
      name: 'Engine RPM',
      pidCommand: '010C',
      units: 'RPM',
      typicalRange: const ValueRange(min: 0, max: 8000),
    );

    statsProvider = MockStatsProvider();
    unitsProvider = MockUnitsProvider();

    viewModel = GaugeDetailViewModel(
      pid: testPid,
      statsProvider: statsProvider,
      unitsProvider: unitsProvider,
    );
  });

  tearDown(() {
    viewModel.dispose();
    statsProvider.dispose();
    unitsProvider.dispose();
  });

  // ── Initialization ──────────────────────────────

  test('testInitializationPidStoredCorrectly', () {
    expect(viewModel, isNotNull);
    expect(viewModel.pid.id, testPid.id);
    expect(viewModel.pid.label, 'RPM');
  });

  test('testPidReferenceIsCorrect', () {
    expect(viewModel.pid.id, testPid.id);
    expect(viewModel.pid.name, 'Engine RPM');
  });

  // ── Initial stats ───────────────────────────────

  test('testStatsAreNullInitiallyWhenProviderHasNoData', () {
    expect(viewModel.stats, isNull);
  });

  // ── Stats from provider ─────────────────────────

  test('testReceivesStatsFromProvider', () async {
    final result = obd2lib.MeasurementResult(1500.0, obd2lib.Unit.rpm);
    final stat = PIDStats(pid: '010C', latest: result);
    statsProvider.send({'010C': stat});

    await Future.delayed(const Duration(milliseconds: 100));

    expect(viewModel.stats, isNotNull);
    expect(viewModel.stats?.latest.value, closeTo(1500.0, 0.001));
  });

  test('testStatsStructureIsValidAfterUpdate', () async {
    final result = obd2lib.MeasurementResult(2200.0, obd2lib.Unit.rpm);
    final stat = PIDStats(pid: '010C', latest: result);
    statsProvider.send({'010C': stat});

    await Future.delayed(const Duration(milliseconds: 100));

    final s = viewModel.stats;
    expect(s, isNotNull);
    expect(s!.sampleCount, greaterThanOrEqualTo(1));
    expect(s.max, greaterThanOrEqualTo(s.min));
  });

  // ── PID command ─────────────────────────────────

  test('testPidCommandMatchesExpectedHex', () {
    expect(viewModel.pid.pidCommand, '010C');
  });

  // ── Unit change refresh ─────────────────────────

  test('testUnitChangeRefreshesStatsWithoutAlteringLatestValue', () async {
    final result = obd2lib.MeasurementResult(1800.0, obd2lib.Unit.rpm);
    final stat = PIDStats(pid: '010C', latest: result);
    statsProvider.send({'010C': stat});

    await Future.delayed(const Duration(milliseconds: 100));
    final before = viewModel.stats?.latest.value;

    unitsProvider.send(MeasurementUnit.imperial);
    await Future.delayed(const Duration(milliseconds: 100));
    final after = viewModel.stats?.latest.value;

    expect(before, equals(after));
  });

  // ── Deduplication ───────────────────────────────

  test('testIdenticalStatsDoNotChangeValue', () async {
    final result1 = obd2lib.MeasurementResult(2000.0, obd2lib.Unit.rpm);
    final stat1 = PIDStats(pid: '010C', latest: result1);
    statsProvider.send({'010C': stat1});
    await Future.delayed(const Duration(milliseconds: 100));

    // Re-send same stats
    statsProvider.send({'010C': stat1});
    await Future.delayed(const Duration(milliseconds: 100));

    expect(viewModel.stats?.latest.value, closeTo(2000.0, 0.001));
  });

  test('testUpdatesOnlyWhenMatchingPIDCommandAppearsInStatsMap', () async {
    final other = PIDStats(
      pid: '010D',
      latest: obd2lib.MeasurementResult(88.0, obd2lib.Unit.kilometersPerHour),
    );
    statsProvider.send({'010D': other});
    await Future.delayed(const Duration(milliseconds: 100));
    expect(viewModel.stats, isNull);
  });

  test('testStatsCanTransitionBackToNullWhenProviderRemovesPID', () async {
    final first = PIDStats(
      pid: '010C',
      latest: obd2lib.MeasurementResult(900.0, obd2lib.Unit.rpm),
    );
    statsProvider.send({'010C': first});
    await Future.delayed(const Duration(milliseconds: 100));
    expect(viewModel.stats, isNotNull);

    statsProvider.send({});
    await Future.delayed(const Duration(milliseconds: 100));
    expect(viewModel.stats, isNull);
  });
}
