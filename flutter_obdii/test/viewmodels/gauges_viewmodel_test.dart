// Port of GaugesViewModelTests.swift — Jim Mittler
// Tests tile generation from enabled gauges, tile identity,
// stats association, and unit change rebuild.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/core/pid_store.dart';
import 'package:flutter_obdii/models/obdii_pid.dart';
import 'package:flutter_obdii/viewmodels/gauges_viewmodel.dart';

// ─────────────────────────────────────────────
// Mocks (1:1 with Swift mocks)
// ─────────────────────────────────────────────

class MockPIDProvider implements PidListProviding {
  List<ObdiiPid> _pids = [];
  @override
  List<ObdiiPid> get pids => _pids;

  final _ctrl = StreamController<List<ObdiiPid>>.broadcast();

  @override
  Stream<List<ObdiiPid>> get pidsStream => _ctrl.stream;

  void send(List<ObdiiPid> pids) {
    _pids = pids;
    _ctrl.add(pids);
  }

  void dispose() => _ctrl.close();
}

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

// Helper to build a gauge PID
ObdiiPid makeGaugePid({
  String id = 'pid_rpm',
  bool enabled = true,
  String label = 'RPM',
  String name = 'Engine RPM',
  String pidCommand = '010C',
  String units = 'RPM',
}) {
  return ObdiiPid(
    id: id,
    enabled: enabled,
    label: label,
    name: name,
    pidCommand: pidCommand,
    units: units,
    kind: ObdPidKind.gauge,
  );
}

void main() {
  late MockPIDProvider pidProvider;
  late MockStatsProvider statsProvider;
  late MockUnitsProvider unitsProvider;
  late PidInterestRegistry interestRegistry;
  late GaugesViewModel viewModel;

  setUp(() {
    pidProvider = MockPIDProvider();
    statsProvider = MockStatsProvider();
    unitsProvider = MockUnitsProvider();
    interestRegistry = PidInterestRegistry();
    viewModel = GaugesViewModel(
      pidProvider: pidProvider,
      statsProvider: statsProvider,
      unitsProvider: unitsProvider,
      interestRegistry: interestRegistry,
    );
  });

  tearDown(() {
    viewModel.dispose();
    pidProvider.dispose();
    statsProvider.dispose();
    unitsProvider.dispose();
  });

  // ── Initialization ──────────────────────────────

  test('testInitializationNotNullStartsEmpty', () {
    expect(viewModel, isNotNull);
    expect(viewModel.tiles, isEmpty);
  });

  // ── Tiles match enabled gauges ──────────────────

  test('testTilesIncludeOnlyEnabledGauges', () async {
    final pidEnabled = makeGaugePid(id: 'rpm', pidCommand: '010C');
    final pidDisabled =
        makeGaugePid(id: 'spd', enabled: false, label: 'Speed', pidCommand: '010D');
    pidProvider.send([pidEnabled, pidDisabled]);

    await Future.delayed(const Duration(milliseconds: 100));

    expect(viewModel.tiles.length, 1);
    expect(viewModel.tiles.first.pid.id, 'rpm');
  });

  test('testAllTilesHaveEnabledGaugePIDs', () async {
    final pid1 = makeGaugePid(id: 'a', pidCommand: '010C');
    final pid2 = makeGaugePid(id: 'b', pidCommand: '010D');
    pidProvider.send([pid1, pid2]);

    await Future.delayed(const Duration(milliseconds: 100));

    for (final tile in viewModel.tiles) {
      expect(tile.pid.enabled, isTrue);
      expect(tile.pid.kind, ObdPidKind.gauge);
    }
  });

  // ── Tile identity ───────────────────────────────

  test('testAllTileIDsAreNonEmpty', () async {
    pidProvider.send([makeGaugePid()]);
    await Future.delayed(const Duration(milliseconds: 100));

    for (final tile in viewModel.tiles) {
      expect(tile.id.isNotEmpty, isTrue);
    }
  });

  test('testAllTileIDsAreUnique', () async {
    pidProvider.send([
      makeGaugePid(id: 'x', pidCommand: '010C'),
      makeGaugePid(id: 'y', pidCommand: '010D'),
      makeGaugePid(id: 'z', pidCommand: '0105'),
    ]);
    await Future.delayed(const Duration(milliseconds: 100));

    final ids = viewModel.tiles.map((t) => t.id).toSet();
    expect(ids.length, viewModel.tiles.length);
  });

  // ── Stats association ───────────────────────────

  test('testTilesHaveMatchingStatsWhenProviderEmitsThem', () async {
    pidProvider.send([makeGaugePid(id: 'rpm', pidCommand: '010C')]);

    final result = obd2lib.MeasurementResult(1500.0, obd2lib.Unit.rpm);
    final stats = PIDStats(pid: '010C', latest: result);
    statsProvider.send({'010C': stats});

    await Future.delayed(const Duration(milliseconds: 100));

    expect(viewModel.tiles.length, 1);
    expect(viewModel.tiles.first.stats?.latest.value, closeTo(1500.0, 0.001));
  });

  // ── Unit change ─────────────────────────────────

  test('testUnitChangeRebuildsTilesWithSameIDs', () async {
    final pid = makeGaugePid(id: 'spd', pidCommand: '010D', units: 'km/h');
    pidProvider.send([pid]);

    final result = obd2lib.MeasurementResult(100.0, obd2lib.Unit.kilometersPerHour);
    statsProvider.send({'010D': PIDStats(pid: '010D', latest: result)});

    await Future.delayed(const Duration(milliseconds: 100));
    final firstIds = viewModel.tiles.map((t) => t.id).toList();

    unitsProvider.send(MeasurementUnit.imperial);
    await Future.delayed(const Duration(milliseconds: 100));

    final secondIds = viewModel.tiles.map((t) => t.id).toList();
    expect(firstIds, equals(secondIds));
    expect(viewModel.tiles.first.stats, isNotNull);
  });

  // ── Visibility-driven interest registration ─────

  test('testSetvisibleTrueRegistersEnabledGaugePIDInterests', () async {
    pidProvider.send([
      makeGaugePid(id: 'rpm', pidCommand: '010C'),
      makeGaugePid(id: 'spd', pidCommand: '010D'),
    ]);
    await Future.delayed(const Duration(milliseconds: 50));

    viewModel.setVisible(true);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(interestRegistry.interested, containsAll(<String>{'010C', '010D'}));
  });

  test('testSetvisibleFalseClearsPreviouslyRegisteredInterests', () async {
    pidProvider.send([makeGaugePid(id: 'rpm', pidCommand: '010C')]);
    await Future.delayed(const Duration(milliseconds: 50));
    viewModel.setVisible(true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested.contains('010C'), isTrue);

    viewModel.setVisible(false);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested.contains('010C'), isFalse);
  });

  test('testHiddenViewDoesNotRetainInterestsAfterPIDListChanges', () async {
    viewModel.setVisible(false);
    pidProvider.send([makeGaugePid(id: 'rpm', pidCommand: '010C')]);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested, isEmpty);
  });

  test('testSetvisibleTrueWithNoTilesKeepsInterestEmpty', () async {
    viewModel.setVisible(true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested, isEmpty);
  });

  test('testStatsUpdateForUnknownPIDDoesNotCreateExtraTile', () async {
    pidProvider.send([makeGaugePid(id: 'rpm', pidCommand: '010C')]);
    statsProvider.send({
      '010D': PIDStats(
        pid: '010D',
        latest: obd2lib.MeasurementResult(40, obd2lib.Unit.kilometersPerHour),
      ),
    });
    await Future.delayed(const Duration(milliseconds: 100));
    expect(viewModel.tiles.length, 1);
    expect(viewModel.tiles.first.pid.pidCommand, '010C');
  });
}
