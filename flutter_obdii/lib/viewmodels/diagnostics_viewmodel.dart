// Port of DiagnosticsViewModel.swift — Jim Mittler
// ViewModel for diagnostic trouble codes display.
// Subscribes to OBDConnectionManager for DTC updates and organizes them
// into severity-based sections (Critical, High, Moderate, Low).
// Handles waiting state (null) vs loaded state (possibly empty array).

import 'dart:async';

import 'package:flutter_obd2/flutter_obd2.dart';

import '../core/obd_connection_manager.dart';
import '../core/pid_interest_registry.dart';
import 'base_view_model.dart';

// ─────────────────────────────────────────────
// MARK: Section (mirrors Swift Section struct)
// ─────────────────────────────────────────────

class DtcSection {
  final String title;
  final String severity;
  final List<TroubleCodeMetadata> items;

  const DtcSection({
    required this.title,
    required this.severity,
    required this.items,
  });

  @override
  bool operator ==(Object other) =>
      other is DtcSection &&
      other.title == title &&
      other.severity == severity &&
      _listEquals(other.items, items);

  @override
  int get hashCode => Object.hash(title, severity, items.length);

  static bool _listEquals(List<TroubleCodeMetadata> a, List<TroubleCodeMetadata> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].code != b[i].code) return false;
    }
    return true;
  }
}

// ─────────────────────────────────────────────
// MARK: DiagnosticsViewModel
// ─────────────────────────────────────────────

class DiagnosticsViewModel extends BaseViewModel {
  final DiagnosticsProviding _provider;
  final PidInterestRegistry _interestRegistry;
  final String _interestToken;
  bool _isVisible = false;

  /// null = waiting for first update, [] = loaded but none
  List<TroubleCodeMetadata>? _codes;
  List<TroubleCodeMetadata>? get codes => _codes;

  List<DtcSection> _sections = [];
  List<DtcSection> get sections => _sections;

  StreamSubscription? _sub;

  DiagnosticsViewModel({
    DiagnosticsProviding? provider,
    PidInterestRegistry? interestRegistry,
  })  : _provider = provider ?? OBDConnectionManager.instance,
        _interestRegistry = interestRegistry ?? PidInterestRegistry.instance,
        _interestToken =
            (interestRegistry ?? PidInterestRegistry.instance).makeToken() {
    _sub = _provider.diagnosticsStream.listen((newCodes) {
      if (newCodes == _codes) return;
      _codes = newCodes;
      _rebuildSections(newCodes);
      notifyListeners();
    });
  }

  void setVisible(bool isVisible) {
    if (_isVisible == isVisible) return;
    _isVisible = isVisible;
    if (_isVisible) {
      _interestRegistry.replace({'03'}, _interestToken);
    } else {
      _interestRegistry.clear(_interestToken);
    }
  }

  void _rebuildSections(List<TroubleCodeMetadata>? codes) {
    if (codes == null || codes.isEmpty) {
      _sections = [];
      return;
    }

    // Group by severity
    final grouped = <String, List<TroubleCodeMetadata>>{};
    for (final code in codes) {
      grouped.putIfAbsent(code.severity, () => []).add(code);
    }

    // Ordered: Critical → High → Moderate → Low
    const order = ['Critical', 'High', 'Moderate', 'Low'];
    _sections = order
        .where((sev) => grouped.containsKey(sev))
        .map((sev) => DtcSection(
              title: sev,
              severity: sev,
              items: grouped[sev]!,
            ))
        .toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _interestRegistry.clear(_interestToken);
    super.dispose();
  }
}
