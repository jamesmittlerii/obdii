// Port of GaugesViewModel.swift — Jim Mittler
// ViewModel for the selected gauges dashboard.
// Keeps an array of visible tiles. Updates when new data arrives.
// Combines PidListProviding + PidStatsProviding + UnitsProviding.

import 'dart:async';

import '../core/config_data.dart';
import '../core/obd_connection_manager.dart';
import '../core/pid_interest_registry.dart';
import '../core/pid_store.dart';
import '../core/obdiipid.dart';
import 'base_view_model.dart';

// ─────────────────────────────────────────────
// MARK: Tile (replaces Swift Tile struct)
// ─────────────────────────────────────────────

class GaugeTile {
  final String id;
  final ObdiiPid pid;
  final PIDStats? stats;

  const GaugeTile({required this.id, required this.pid, this.stats});

  @override
  bool operator ==(Object other) =>
      other is GaugeTile &&
      other.id == id &&
      other.stats?.sampleCount == stats?.sampleCount &&
      other.stats?.latest.value == stats?.latest.value;

  @override
  int get hashCode => Object.hash(id, stats?.sampleCount);
}

// ─────────────────────────────────────────────
// MARK: GaugesViewModel
// ─────────────────────────────────────────────

class GaugesViewModel extends BaseViewModel {
  final PidListProviding _pidProvider;
  final PidStatsProviding _statsProvider;
  final UnitsProviding _unitsProvider;
  final PidInterestRegistry _interestRegistry;
  final String _interestToken;

  List<GaugeTile> _tiles = [];
  List<GaugeTile> get tiles => _tiles;
  bool _isVisible = false;

  bool get isEmpty => _tiles.isEmpty;

  StreamSubscription? _pidSub;
  StreamSubscription? _statsSub;
  StreamSubscription? _unitsSub;

  GaugesViewModel({
    PidListProviding? pidProvider,
    PidStatsProviding? statsProvider,
    UnitsProviding? unitsProvider,
    PidInterestRegistry? interestRegistry,
  })  : _pidProvider = pidProvider ?? PidStore.instance,
        _statsProvider = statsProvider ?? OBDConnectionManager.instance,
        _unitsProvider = unitsProvider ?? ConfigData.instance,
        _interestRegistry = interestRegistry ?? PidInterestRegistry.instance,
        _interestToken =
            (interestRegistry ?? PidInterestRegistry.instance).makeToken() {
    _bind();
  }

  void _bind() {
    // Rebuild whenever pids list changes
    _pidSub = _pidProvider.pidsStream.listen((_) => _rebuildTiles());

    // Rebuild whenever stats update
    _statsSub = _statsProvider.pidStatsStream.listen((_) => _rebuildTiles());

    // Rebuild whenever units change (values need re-conversion)
    _unitsSub = _unitsProvider.unitsStream.listen((_) => _rebuildTiles());

    // Initial build
    _rebuildTiles();
  }

  void _rebuildTiles() {
    final newTiles = _pidProvider.pids
        .where((p) => p.enabled && p.kind == ObdPidKind.gauge)
        .map((pid) => GaugeTile(
              id: pid.id,
              pid: pid,
              stats: _statsProvider.statsFor(pid.pidCommand),
            ))
        .toList();

    // Avoid unnecessary notify if tiles are the same
    if (_tilesEqual(newTiles, _tiles)) return;
    _tiles = newTiles;
    _updateInterest();
    notifyListeners();
  }

  void setVisible(bool isVisible) {
    if (_isVisible == isVisible) return;
    _isVisible = isVisible;
    _updateInterest();
  }

  void _updateInterest() {
    if (!_isVisible) {
      _interestRegistry.clear(_interestToken);
      return;
    }
    final interested = _tiles.map((t) => t.pid.pidCommand).toSet();
    _interestRegistry.replace(interested, _interestToken);
  }

  bool _tilesEqual(List<GaugeTile> a, List<GaugeTile> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _pidSub?.cancel();
    _statsSub?.cancel();
    _unitsSub?.cancel();
    _interestRegistry.clear(_interestToken);
    super.dispose();
  }
}
