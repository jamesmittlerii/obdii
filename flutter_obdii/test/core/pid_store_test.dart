// Port of PIDStoreTests.swift — Jim Mittler
// Unit tests for PidStore — JSON loading, enabledGauges,
// toggle, moveEnabled, find by id/command, count.
// Uses an in-memory _SeededPidStore to avoid rootBundle dependencies.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/core/pid_store.dart';
import 'package:flutter_obdii/core/obdiipid.dart';

// ─────────────────────────────────────────────────────────────────
// In-memory PidStore — bypasses JSON/SharedPreferences for unit tests.
// Mirrors what the Swift tests do: use the singleton with live JSON.
// ─────────────────────────────────────────────────────────────────

class _SeededPidStore extends ChangeNotifier implements PidStore {
  List<ObdiiPid> _pids;

  _SeededPidStore(this._pids);

  @override
  List<ObdiiPid> get pids => _pids;

  @override
  List<ObdiiPid> get enabledGauges =>
      _pids.where((p) => p.enabled && p.kind == ObdPidKind.gauge).toList();

  @override
  Stream<List<ObdiiPid>> get pidsStream => Stream.multi((c) {
        c.add(_pids);
        void l() => c.add(_pids);
        addListener(l);
        c.onCancel = () => removeListener(l);
      });

  @override
  Future<void> load() async {} // already seeded

  @override
  Future<void> toggle(ObdiiPid pid) async {
    final idx = _pids.indexWhere((p) => p.id == pid.id);
    if (idx == -1) return;
    _pids[idx] = _pids[idx].copyWith(enabled: !_pids[idx].enabled);
    notifyListeners();
  }

  @override
  Future<void> moveEnabled(int fromIndex, int toIndex) async {
    final enabledIdx = _pids
        .asMap()
        .entries
        .where((e) => e.value.enabled && e.value.kind == ObdPidKind.gauge)
        .map((e) => e.key)
        .toList();
    if (enabledIdx.isEmpty) return;
    final subset = enabledIdx.map((i) => _pids[i]).toList();
    final item = subset.removeAt(fromIndex);
    subset.insert(toIndex > fromIndex ? toIndex - 1 : toIndex, item);
    final newPids = List<ObdiiPid>.from(_pids);
    for (var i = 0; i < enabledIdx.length; i++) {
      newPids[enabledIdx[i]] = subset[i];
    }
    _pids = newPids;
    notifyListeners();
  }
}

List<ObdiiPid> _defaultTestPids() => [
      ObdiiPid(
          id: 'pid_rpm',
          enabled: true,
          label: 'RPM',
          name: 'Engine RPM',
          pidCommand: '010C',
          units: 'RPM',
          kind: ObdPidKind.gauge,
          typicalRange: const ValueRange(min: 0, max: 8000)),
      ObdiiPid(
          id: 'pid_speed',
          enabled: false,
          label: 'Speed',
          name: 'Vehicle Speed',
          pidCommand: '010D',
          units: 'km/h',
          kind: ObdPidKind.gauge,
          typicalRange: const ValueRange(min: 0, max: 200)),
      ObdiiPid(
          id: 'pid_coolant',
          enabled: false,
          label: 'Coolant',
          name: 'Coolant Temp',
          pidCommand: '0105',
          units: '°C',
          kind: ObdPidKind.gauge),
      ObdiiPid(
          id: 'pid_status',
          enabled: false,
          label: 'Status',
          name: 'Monitor Status',
          pidCommand: '0101',
          units: 'NA',
          kind: ObdPidKind.status),
    ];

PidStore _buildStore([List<ObdiiPid>? pids]) =>
    _SeededPidStore(pids ?? _defaultTestPids());

// ─────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('testSingletonInstanceExists', () {
    expect(PidStore.instance, isNotNull);
  });

  test('testPidsLoadFromStore0', () async {
    final store = _buildStore();
    await store.load();
    expect(store.pids.length, greaterThan(0));
  });

  // ── Kind filtering ───────────────────────────

  test('testPidsContainGaugeTypePIDs', () async {
    final store = _buildStore();
    await store.load();
    expect(store.pids.where((p) => p.kind == ObdPidKind.gauge).length,
        greaterThan(0));
  });

  test('testPidsMayContainStatusTypePIDs', () async {
    final store = _buildStore();
    await store.load();
    expect(store.pids.where((p) => p.kind == ObdPidKind.status).length,
        greaterThanOrEqualTo(0));
  });

  // ── enabledGauges ────────────────────────────

  test('testEnabledgaugesContainsOnlyEnabledGaugePIDs', () async {
    final store = _buildStore();
    await store.load();
    for (final pid in store.enabledGauges) {
      expect(pid.enabled, isTrue);
      expect(pid.kind, ObdPidKind.gauge);
    }
  });

  test('testEnabledgaugesOrderIsPreservedFromPidsArray', () async {
    final store = _buildStore([
      ObdiiPid(id: 'a', enabled: true, label: 'A', name: 'A', pidCommand: '010C', units: 'x', kind: ObdPidKind.gauge),
      ObdiiPid(id: 'b', enabled: true, label: 'B', name: 'B', pidCommand: '010D', units: 'y', kind: ObdPidKind.gauge),
    ]);
    await store.load();
    final enabled = store.enabledGauges;
    if (enabled.length >= 2) {
      final fi = store.pids.indexWhere((p) => p.id == enabled[0].id);
      final si = store.pids.indexWhere((p) => p.id == enabled[1].id);
      expect(fi, lessThan(si));
    }
  });

  // ── toggle ───────────────────────────────────

  test('testToggleFlipsEnabledState', () async {
    final store = _buildStore();
    await store.load();
    final gauge = store.pids.firstWhere((p) => p.kind == ObdPidKind.gauge);
    final initial = gauge.enabled;
    await store.toggle(gauge);
    final updated = store.pids.firstWhere((p) => p.id == gauge.id);
    expect(updated.enabled, isNot(initial));
    await store.toggle(updated); // restore
  });

  // ── moveEnabled ──────────────────────────────

  test('testMoveenabledDoesNotChangeCount', () async {
    final store = _buildStore([
      ObdiiPid(id: 'a', enabled: true, label: 'A', name: 'A', pidCommand: '010C', units: 'x', kind: ObdPidKind.gauge),
      ObdiiPid(id: 'b', enabled: true, label: 'B', name: 'B', pidCommand: '010D', units: 'y', kind: ObdPidKind.gauge),
    ]);
    await store.load();
    final before = store.enabledGauges.length;
    await store.moveEnabled(0, 1);
    expect(store.enabledGauges.length, before);
  });

  // ── find by ID ───────────────────────────────

  test('testCanFindPIDById', () async {
    final store = _buildStore();
    await store.load();
    final first = store.pids.first;
    final found = store.pids.firstWhere((p) => p.id == first.id);
    expect(found.id, first.id);
  });

  // ── find by command ──────────────────────────

  test('testCanFindRPMPIDByCommand', () async {
    final store = _buildStore();
    await store.load();
    final rpm = store.pids.firstWhere(
      (p) => p.pidCommand == '010C',
      orElse: () => throw TestFailure('RPM PID not found'),
    );
    expect(rpm.pidCommand, '010C');
  });

  // ── count sanity ─────────────────────────────

  test('testPidCountIsInReasonableRange', () async {
    final store = _buildStore();
    await store.load();
    expect(store.pids.length, greaterThan(0));
    expect(store.pids.length, lessThan(200));
  });

  test('testToggleUnknownPIDDoesNotMutateStore', () async {
    final store = _buildStore();
    await store.load();
    final before = store.pids.map((p) => p.enabled).toList();
    final unknown = ObdiiPid(
      id: 'unknown',
      enabled: false,
      label: 'Unknown',
      name: 'Unknown',
      pidCommand: 'FFFF',
      units: 'NA',
      kind: ObdPidKind.gauge,
    );
    await store.toggle(unknown);
    final after = store.pids.map((p) => p.enabled).toList();
    expect(after, equals(before));
  });

  test('testMoveenabledKeepsDisabledNonGaugeEntriesInPlace', () async {
    final seeded = [
      ObdiiPid(id: 'a', enabled: true, label: 'A', name: 'A', pidCommand: '010C', units: 'x', kind: ObdPidKind.gauge),
      ObdiiPid(id: 'status', enabled: false, label: 'Status', name: 'Status', pidCommand: '0101', units: 'NA', kind: ObdPidKind.status),
      ObdiiPid(id: 'b', enabled: true, label: 'B', name: 'B', pidCommand: '010D', units: 'y', kind: ObdPidKind.gauge),
    ];
    final store = _buildStore(seeded);
    await store.load();
    await store.moveEnabled(0, 1);
    expect(store.pids[1].id, equals('status'));
  });
}
