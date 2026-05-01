// Port of PIDStore.swift — Jim Mittler
// PID storage and ordering manager singleton.
// Loads all PIDs from JSON, manages enabled/disabled state, and persists
// user preferences including gauge ordering. Supports drag-and-drop reordering
// of enabled gauges. Uses SharedPreferences (replaces UserDefaults).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'carplay_bridge.dart';
import '../core/obdiipid.dart';

// ─────────────────────────────────────────────
// MARK: PidListProviding (protocol)
// ─────────────────────────────────────────────

abstract class PidListProviding {
  List<ObdiiPid> get pids;
  Stream<List<ObdiiPid>> get pidsStream;
}

// ─────────────────────────────────────────────
// MARK: PidStore abstract interface
// Used by tests to inject mock stores.
// ─────────────────────────────────────────────

abstract class PidStore extends ChangeNotifier implements PidListProviding {
  /// App-wide singleton.
  static final PidStore instance = _PidStoreImpl._();

  /// Returns a fresh, non-singleton instance suitable for unit tests.
  static PidStore forTesting() => _PidStoreImpl._();

  List<ObdiiPid> get enabledGauges;
  Future<void> load();
  Future<void> toggle(ObdiiPid pid);
  Future<void> moveEnabled(int fromIndex, int toIndex);
}

// ─────────────────────────────────────────────
// MARK: _PidStoreImpl — concrete implementation
// ─────────────────────────────────────────────

class _PidStoreImpl extends ChangeNotifier implements PidStore {
  _PidStoreImpl._();

  static const _kEnabledKey = 'PIDStore.enabledByCommand';
  static const _kEnabledOrderKey = 'PIDStore.enabledGaugesOrder';
  static const _kDisabledOrderKey = 'PIDStore.disabledGaugesOrder';

  List<ObdiiPid> _pids = [];

  @override
  List<ObdiiPid> get pids => _pids;

  @override
  List<ObdiiPid> get enabledGauges =>
      _pids.where((p) => p.kind == ObdPidKind.gauge && p.enabled).toList();

  bool _loaded = false;

  @override
  Stream<List<ObdiiPid>> get pidsStream => Stream.multi((c) {
        c.add(_pids);
        void listener() => c.add(_pids);
        addListener(listener);
        c.onCancel = () => removeListener(listener);
      });

  // ── Init ─────────────────────────────────────

  @override
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    // 1. Load PIDs from JSON
    var all = await ObdiiPidLibrary.loadFromJSON();

    final prefs = await SharedPreferences.getInstance();

    // 2. Restore enabled/disabled flags
    final enabledJson = prefs.getString(_kEnabledKey);
    if (enabledJson != null) {
      final Map<String, dynamic> saved = json.decode(enabledJson);
      all = all.map((pid) {
        final flag = saved[pid.pidCommand] as bool?;
        return flag != null ? pid.copyWith(enabled: flag) : pid;
      }).toList();
    }

    // 3. Restore ordering
    final enabledOrderJson = prefs.getString(_kEnabledOrderKey);
    final disabledOrderJson = prefs.getString(_kDisabledOrderKey);

    final enabledOrder = enabledOrderJson != null
        ? List<String>.from(json.decode(enabledOrderJson))
        : null;
    final disabledOrder = disabledOrderJson != null
        ? List<String>.from(json.decode(disabledOrderJson))
        : null;

    if (enabledOrder != null || disabledOrder != null) {
      all = _applySavedOrdering(all,
          enabledOrder: enabledOrder, disabledOrder: disabledOrder);
    }

    _pids = all;

    // 4. Persist state on first boot to lock in structure
    await _persistEnabledFlags(_pids);
    await _persistGaugeOrders(_pids);

    notifyListeners();
  }

  // ── Toggle ───────────────────────────────────

  @override
  Future<void> toggle(ObdiiPid pid) async {
    final idx = _pids.indexWhere((p) => p.id == pid.id);
    if (idx == -1) return;

    _pids[idx] = _pids[idx].copyWith(enabled: !_pids[idx].enabled);
    _pids = _reordered(_pids);

    await _persistEnabledFlags(_pids);
    await _persistGaugeOrders(_pids);
    await CarPlayBridge.gaugePreferencesChanged();
    notifyListeners();
  }

  // ── Reorder enabled gauges ────────────────────

  @override
  Future<void> moveEnabled(int fromIndex, int toIndex) async {
    final enabledIndices = _pids
        .asMap()
        .entries
        .where((e) => e.value.kind == ObdPidKind.gauge && e.value.enabled)
        .map((e) => e.key)
        .toList();

    if (enabledIndices.isEmpty) return;
    if (fromIndex < 0 || fromIndex >= enabledIndices.length) return;
    if (toIndex < 0 || toIndex >= enabledIndices.length) return;
    if (fromIndex == toIndex) return;

    var subset = enabledIndices.map((i) => _pids[i]).toList();
    final item = subset.removeAt(fromIndex);
    subset.insert(toIndex, item);

    final newPids = List<ObdiiPid>.from(_pids);
    for (var i = 0; i < enabledIndices.length; i++) {
      newPids[enabledIndices[i]] = subset[i];
    }

    _pids = newPids;
    await _persistGaugeOrders(_pids);
    await CarPlayBridge.gaugePreferencesChanged();
    notifyListeners();
  }

  // ── Persistence ──────────────────────────────

  Future<void> _persistEnabledFlags(List<ObdiiPid> pids) async {
    final map = {for (var p in pids) p.pidCommand: p.enabled};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEnabledKey, json.encode(map));
  }

  Future<void> _persistGaugeOrders(List<ObdiiPid> pids) async {
    final enabled = pids
        .where((p) => p.kind == ObdPidKind.gauge && p.enabled)
        .map((p) => p.pidCommand)
        .toList();
    final disabled = pids
        .where((p) => p.kind == ObdPidKind.gauge && !p.enabled)
        .map((p) => p.pidCommand)
        .toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEnabledOrderKey, json.encode(enabled));
    await prefs.setString(_kDisabledOrderKey, json.encode(disabled));
  }

  // ── Ordering helpers ─────────────────────────

  static List<ObdiiPid> _applySavedOrdering(
    List<ObdiiPid> pids, {
    List<String>? enabledOrder,
    List<String>? disabledOrder,
  }) {
    var enabled = pids.where((p) => p.kind == ObdPidKind.gauge && p.enabled).toList();
    var disabled = pids.where((p) => p.kind == ObdPidKind.gauge && !p.enabled).toList();
    final others = pids.where((p) => p.kind != ObdPidKind.gauge).toList();

    if (enabledOrder != null) _reorderList(enabled, enabledOrder);
    if (disabledOrder != null) _reorderList(disabled, disabledOrder);

    return [...enabled, ...disabled, ...others];
  }

  static void _reorderList(List<ObdiiPid> list, List<String> order) {
    final indexMap = {for (var e in order.asMap().entries) e.value: e.key};
    list.sort((lhs, rhs) {
      final l = indexMap[lhs.pidCommand];
      final r = indexMap[rhs.pidCommand];
      if (l != null && r != null) return l.compareTo(r);
      if (l != null) return -1;
      if (r != null) return 1;
      return 0;
    });
  }

  static List<ObdiiPid> _reordered(List<ObdiiPid> pids) {
    final enabled = pids.where((p) => p.kind == ObdPidKind.gauge && p.enabled).toList();
    final disabled = pids.where((p) => p.kind == ObdPidKind.gauge && !p.enabled).toList();
    final others = pids.where((p) => p.kind != ObdPidKind.gauge).toList();
    return [...enabled, ...disabled, ...others];
  }
}
