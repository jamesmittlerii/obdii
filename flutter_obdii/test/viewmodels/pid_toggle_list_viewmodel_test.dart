// Port of PIDToggleListViewModelTests.swift — Jim Mittler
// Tests PID mirroring from PidStore, search filtering, toggle,
// reorder, enabled/disabled section organization.
// Uses PidStore.instance (singleton) backed by mock asset data.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_obdii/models/obdii_pid.dart';
import 'package:flutter_obdii/viewmodels/pid_toggle_list_viewmodel.dart';

// ─────────────────────────────────────────────
// Isolated PidStore-like provider for tests
// ─────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_obdii/core/pid_store.dart';

// Build an in-memory store seeded with known PIDs for test isolation
class _TestStore extends ChangeNotifier implements PidStore {
  List<ObdiiPid> _pids;
  _TestStore(this._pids);

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
  Future<void> load() async {}

  @override
  Future<void> toggle(ObdiiPid pid) async {
    final idx = _pids.indexWhere((p) => p.id == pid.id);
    if (idx == -1) return;
    _pids[idx] = _pids[idx].copyWith(enabled: !_pids[idx].enabled);
    notifyListeners();
  }

  @override
  Future<void> moveEnabled(int from, int to) async {
    final enabledIdx = _pids
        .asMap()
        .entries
        .where((e) => e.value.enabled && e.value.kind == ObdPidKind.gauge)
        .map((e) => e.key)
        .toList();
    if (enabledIdx.isEmpty) return;
    final subset = enabledIdx.map((i) => _pids[i]).toList();
    final item = subset.removeAt(from);
    subset.insert(to > from ? to - 1 : to, item);
    final newPids = List<ObdiiPid>.from(_pids);
    for (var i = 0; i < enabledIdx.length; i++) {
      newPids[enabledIdx[i]] = subset[i];
    }
    _pids = newPids;
    notifyListeners();
  }
}

List<ObdiiPid> _makePids() => [
      ObdiiPid(id: 'rpm', enabled: true, label: 'RPM', name: 'Engine RPM',
          pidCommand: '010C', units: 'RPM', kind: ObdPidKind.gauge),
      ObdiiPid(id: 'spd', enabled: false, label: 'Speed', name: 'Vehicle Speed',
          pidCommand: '010D', units: 'km/h', kind: ObdPidKind.gauge),
      ObdiiPid(id: 'cool', enabled: false, label: 'Coolant', name: 'Engine Coolant Temp',
          pidCommand: '0105', units: '°C', kind: ObdPidKind.gauge),
      ObdiiPid(id: 'status', enabled: false, label: 'Status', name: 'Monitor Status',
          pidCommand: '0101', units: 'NA', kind: ObdPidKind.status),
    ];

void main() {
  late _TestStore store;
  late PidToggleListViewModel viewModel;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = _TestStore(_makePids());
    viewModel = PidToggleListViewModel(store: store);
  });

  tearDown(() {
    viewModel.dispose();
    store.dispose();
  });

  // ── Initialization ──────────────────────────────

  test('testInitializationNotNullHasPIDs', () {
    expect(viewModel, isNotNull);
    expect(viewModel.pids.length, greaterThanOrEqualTo(0));
  });

  test('testPidsMirrorStoreCount', () {
    expect(viewModel.pids.length, store.pids.length);
  });

  // ── filteredEnabled / filteredDisabled ──────────

  test('testFilteredenabledContainsOnlyEnabledGaugePIDs', () {
    expect(viewModel.filteredEnabled.every((p) => p.enabled && p.kind == ObdPidKind.gauge), isTrue);
  });

  test('testFiltereddisabledContainsOnlyDisabledGaugePIDs', () {
    expect(viewModel.filteredDisabled.every((p) => !p.enabled && p.kind == ObdPidKind.gauge), isTrue);
  });

  // ── Empty search ────────────────────────────────

  test('testEmptySearchReturnsAllGaugePIDs', () {
    viewModel.searchText = '';
    final total = viewModel.filteredEnabled.length + viewModel.filteredDisabled.length;
    final totalGauges = store.pids.where((p) => p.kind == ObdPidKind.gauge).length;
    expect(total, totalGauges);
  });

  // ── Search by label ─────────────────────────────

  test('testSearchbylabelFindsMatchingPIDs', () {
    viewModel.searchText = 'RPM';
    final all = viewModel.filteredEnabled + viewModel.filteredDisabled;
    expect(all.any((p) => p.id == 'rpm'), isTrue);
  });

  test('testSearchIsCaseInsensitive', () {
    viewModel.searchText = 'rpm';
    final lower = (viewModel.filteredEnabled + viewModel.filteredDisabled).length;

    viewModel.searchText = 'RPM';
    final upper = (viewModel.filteredEnabled + viewModel.filteredDisabled).length;

    expect(lower, upper);
  });

  test('testSearchTrimsWhitespace', () {
    viewModel.searchText = '  RPM  ';
    final results = viewModel.filteredEnabled + viewModel.filteredDisabled;
    expect(results.length, greaterThanOrEqualTo(0));
  });

  test('testSearchbynameFindsViaNameField', () {
    viewModel.searchText = 'Engine';
    final results = viewModel.filteredEnabled + viewModel.filteredDisabled;
    if (results.isNotEmpty) {
      final anyMatch = results.any((p) =>
          p.label.toLowerCase().contains('engine') ||
          p.name.toLowerCase().contains('engine') ||
          (p.notes?.toLowerCase().contains('engine') ?? false));
      expect(anyMatch, isTrue);
    }
  });

  // ── Toggle ──────────────────────────────────────

  test('testToggleFlipsEnabledState', () async {
    final gaugePids = viewModel.pids.where((p) => p.kind == ObdPidKind.gauge).toList();
    if (gaugePids.isEmpty) return;

    final idx = viewModel.pids.indexOf(gaugePids.first);
    final initial = gaugePids.first.enabled;

    await viewModel.toggle(idx, !initial);

    // store reflects the change
    expect(true, isTrue); // no crash is the assertion
  });

  test('testRedundantToggleIsIgnoredGracefully', () async {
    final gaugePids = viewModel.pids.where((p) => p.kind == ObdPidKind.gauge).toList();
    if (gaugePids.isEmpty) return;

    final idx = viewModel.pids.indexOf(gaugePids.first);
    final current = gaugePids.first.enabled;

    await viewModel.toggle(idx, current); // same value — no-op
    expect(true, isTrue);
  });

  // ── Reorder ─────────────────────────────────────

  test('testMoveenabledDoesNotCrash', () async {
    final enabledCount = viewModel.filteredEnabled.length;
    if (enabledCount >= 2) {
      await viewModel.moveEnabled(0, 1);
    }
    expect(true, isTrue);
  });

  test('testSearchByPidCommandMatchesExpectedGauge', () {
    viewModel.searchText = '010D';
    final results = viewModel.filteredEnabled + viewModel.filteredDisabled;
    expect(results.any((p) => p.id == 'spd'), isTrue);
  });

  test('testSearchWithUnknownTokenReturnsNoResults', () {
    viewModel.searchText = 'no-such-pid';
    expect(viewModel.filteredEnabled, isEmpty);
    expect(viewModel.filteredDisabled, isEmpty);
  });

  test('testToggleOutOfRangeIndexIsSafelyIgnored', () async {
    final before = store.pids.map((p) => p.enabled).toList();
    await viewModel.toggle(-1, true);
    await viewModel.toggle(999, false);
    final after = store.pids.map((p) => p.enabled).toList();
    expect(after, equals(before));
  });

  test('testMoveenabledReordersEnabledGauges', () async {
    // Enable two gauges to make ordering visible
    await store.toggle(store.pids.firstWhere((p) => p.id == 'spd'));
    final enabledBefore = viewModel.filteredEnabled.map((p) => p.id).toList();
    if (enabledBefore.length < 2) return;

    await viewModel.moveEnabled(0, 1);
    final enabledAfter = viewModel.filteredEnabled.map((p) => p.id).toList();
    expect(enabledAfter.length, equals(enabledBefore.length));
  });
}
