// Port of PIDToggleListViewModel.swift — Jim Mittler
// ViewModel for PID toggle/reorder list.
// Mirrors PIDStore's PIDs for UI display, supports search filtering by label,
// name, notes, and command. Provides filtered enabled/disabled lists.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/pid_store.dart';
import '../models/obdii_pid.dart';

class PidToggleListViewModel extends ChangeNotifier {
  final PidStore _store;

  // Local mirror of the store's PID list (copied for sorting/filtering UI)
  List<ObdiiPid> _pids = [];
  List<ObdiiPid> get pids => _pids;

  String _searchText = '';
  String get searchText => _searchText;
  set searchText(String v) {
    if (v == _searchText) return;
    _searchText = v;
    notifyListeners();
  }

  StreamSubscription? _pidSub;

  PidToggleListViewModel({PidStore? store})
      : _store = store ?? PidStore.instance {
    _pids = List.from(_store.pids);
    _pidSub = _store.pidsStream.listen((pids) {
      _pids = List.from(pids);
      notifyListeners();
    });
  }

  // ── Computed lists ─────────────────────────────

  List<ObdiiPid> get filteredEnabled =>
      _applySearch(_pids.where((p) => p.enabled && p.kind == ObdPidKind.gauge).toList());

  List<ObdiiPid> get filteredDisabled =>
      _applySearch(_pids.where((p) => !p.enabled && p.kind == ObdPidKind.gauge).toList());

  // ── Search ─────────────────────────────────────

  String get _normalizedQuery => _searchText.trim().toLowerCase();

  List<ObdiiPid> _applySearch(List<ObdiiPid> list) {
    final q = _normalizedQuery;
    if (q.isEmpty) return list;
    return list.where((p) => _matchesQuery(p, q)).toList();
  }

  bool _matchesQuery(ObdiiPid pid, String q) {
    if (pid.label.toLowerCase().contains(q)) return true;
    if (pid.name.toLowerCase().contains(q)) return true;
    if (pid.notes?.toLowerCase().contains(q) ?? false) return true;
    if (pid.pidCommand.toLowerCase().contains(q)) return true;
    return false;
  }

  // ── Actions ────────────────────────────────────

  Future<void> toggle(int index, bool isOn) async {
    if (index < 0 || index >= _pids.length) return;
    final pid = _pids[index];
    if (pid.enabled == isOn) return;
    await _store.toggle(pid);
  }

  Future<void> moveEnabled(int fromIndex, int toIndex) async {
    await _store.moveEnabled(fromIndex, toIndex);
  }

  @override
  void dispose() {
    _pidSub?.cancel();
    super.dispose();
  }
}
