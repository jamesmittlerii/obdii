// Port of PIDInterestRegistry.swift — Jim Mittler
// Demand-driven PID interest tracking registry.
// Manages which PIDs are currently needed by active UI views.
// Each view registers a unique token and declares its required PIDs.
// The registry computes the union of all interests and notifies listeners,
// allowing OBDConnectionManager to poll only what's actually visible.

import 'package:flutter/foundation.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'logger.dart';

class PidInterestRegistry extends ChangeNotifier {
  static final PidInterestRegistry instance = PidInterestRegistry._();

  /// Public constructor — use this in tests for isolated instances.
  PidInterestRegistry();
  PidInterestRegistry._();

  /// The union of all PIDs currently requested by all active tokens.
  Set<String> _interested = {};
  Set<String> get interested => _interested;

  /// Stream version so OBDConnectionManager can listen reactively.
  Stream<Set<String>> get interestedStream => Stream.multi((c) {
        c.add(_interested);
        void listener() => c.add(_interested);
        addListener(listener);
        c.onCancel = () => removeListener(listener);
      });

  /// Per-owner PID sets, keyed by token string.
  final Map<String, Set<String>> _byToken = {};

  /// Creates a new owner token. Call [replace] afterward to register interest.
  String makeToken() {
    final token = UniqueKey().toString();
    _byToken[token] = {};
    return token;
  }

  /// Replaces the entire PID set for a given token.
  void replace(Set<String> pids, String token) {
    _byToken[token] = pids;
    _recompute();
  }

  /// Clears a token's interest. Safe to call multiple times.
  /// Yields one frame to allow immediate handoff from another view first.
  Future<void> clear(String token) async {
    // Let any immediately-following replace() calls run first
    await Future.microtask(() {});
    _byToken.remove(token);
    _recompute();
  }

  void _recompute() {
    final newUnion = _byToken.values.fold<Set<String>>(
      {},
      (acc, pids) => acc..addAll(pids),
    );
    if (setEquals(newUnion, _interested)) return;
    _interested = newUnion;
    _logInterestChange(newUnion);
    notifyListeners();
  }

  void _logInterestChange(Set<String> set) {
    if (set.isEmpty) {
      obdDebug('PIDInterestRegistry: now empty', category: LogCategory.service);
      return;
    }

    final names = set.map((cmd) {
      final pid = obd2lib.Commands.allCommands[cmd];
      if (pid == null) return cmd;
      return pid.properties.description;
    }).toList()
      ..sort();

    obdDebug(
      'PIDInterestRegistry: interested set = { ${names.join(", ")} }',
      category: LogCategory.service,
    );
  }
}
