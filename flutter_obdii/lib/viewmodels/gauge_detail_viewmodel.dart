// Port of GaugeDetailViewModel.swift — Jim Mittler
// ViewModel for single gauge detail view.
// Tracks statistics for a specific PID including current value, min/max observed,
// and sample count. Refreshes when units change.

import 'dart:async';

import '../core/config_data.dart';
import '../core/obd_connection_manager.dart';
import '../models/obdii_pid.dart';
import 'base_view_model.dart';

class GaugeDetailViewModel extends BaseViewModel {
  final ObdiiPid pid;
  final PidStatsProviding _statsProvider;
  final UnitsProviding _unitsProvider;

  PIDStats? _stats;
  PIDStats? get stats => _stats;

  StreamSubscription? _statsSub;
  StreamSubscription? _unitsSub;

  GaugeDetailViewModel({
    required this.pid,
    PidStatsProviding? statsProvider,
    UnitsProviding? unitsProvider,
  })  : _statsProvider = statsProvider ?? OBDConnectionManager.instance,
        _unitsProvider = unitsProvider ?? ConfigData.instance {
    // Seed with current value immediately
    _stats = _statsProvider.statsFor(pid.pidCommand);
    _bindPidStats();
    _bindUnits();
  }

  void _bindPidStats() {
    _statsSub = _statsProvider.pidStatsStream.listen((allStats) {
      final newStats = allStats[pid.pidCommand];
      if (!_isSameStats(_stats, newStats)) {
        _stats = newStats;
        notifyListeners();
      }
    });
  }

  void _bindUnits() {
    _unitsSub = _unitsProvider.unitsStream.listen((_) {
      // Force refresh so UI re-renders with new unit formatting
      _stats = _statsProvider.statsFor(pid.pidCommand);
      notifyListeners();
    });
  }

  /// Prevents UI from updating unless the change is meaningful.
  static bool _isSameStats(PIDStats? lhs, PIDStats? rhs) {
    if (lhs == null && rhs == null) return true;
    if (lhs == null || rhs == null) return false;
    return lhs.sampleCount == rhs.sampleCount &&
        lhs.latest.value == rhs.latest.value &&
        lhs.min == rhs.min &&
        lhs.max == rhs.max;
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    _unitsSub?.cancel();
    super.dispose();
  }
}
