// Port of MILStatusViewModel.swift — Jim Mittler
// ViewModel for MIL (Malfunction Indicator Lamp) status.
// Subscribes to OBDConnectionManager for MIL/Check Engine Light status updates.
// Provides formatted header text, readiness monitor sorting by ready/not ready.

import 'dart:async';

import 'package:flutter_obd2/flutter_obd2.dart';

import '../core/obd_connection_manager.dart';
import '../core/pid_interest_registry.dart';
import 'base_view_model.dart';

class MilStatusViewModel extends BaseViewModel {
  final MilStatusProviding _provider;
  final PidInterestRegistry _interestRegistry;
  final String _interestToken;
  bool _isVisible = false;

  Status? _status;
  Status? get status => _status;

  StreamSubscription? _sub;

  MilStatusViewModel({
    MilStatusProviding? provider,
    PidInterestRegistry? interestRegistry,
  })  : _provider = provider ?? OBDConnectionManager.instance,
        _interestRegistry = interestRegistry ?? PidInterestRegistry.instance,
        _interestToken =
            (interestRegistry ?? PidInterestRegistry.instance).makeToken() {
    _sub = _provider.milStatusStream.listen((newStatus) {
      if (newStatus == _status) return;
      _status = newStatus;
      notifyListeners();
    });
  }

  void setVisible(bool isVisible) {
    if (_isVisible == isVisible) return;
    _isVisible = isVisible;
    if (_isVisible) {
      _interestRegistry.replace({'0101'}, _interestToken);
    } else {
      _interestRegistry.clear(_interestToken);
    }
  }

  String get headerText {
    if (_status == null) return 'No MIL Status';
    final dtcLabel = _status!.dtcCount == 1 ? '1 DTC' : '${_status!.dtcCount} DTCs';
    return 'MIL: ${_status!.milOn ? 'On' : 'Off'} ($dtcLabel)';
  }

  bool get hasStatus => _status != null;

  /// Readiness monitors sorted: Not Ready → Ready → Unknown
  List<ReadinessMonitor> get sortedSupportedMonitors {
    if (_status == null) return [];
    final supported = _status!.monitors.where((m) => m.supported).toList();
    return supported..sort((lhs, rhs) {
      int lp = _readinessPriority(lhs.ready);
      int rp = _readinessPriority(rhs.ready);
      if (lp != rp) return lp.compareTo(rp);
      return lhs.name.compareTo(rhs.name);
    });
  }

  /// 0 = Not Ready, 1 = Ready (mirrors Swift readinessPriority)
  int _readinessPriority(bool ready) => ready ? 1 : 0;

  @override
  void dispose() {
    _sub?.cancel();
    _interestRegistry.clear(_interestToken);
    super.dispose();
  }
}
