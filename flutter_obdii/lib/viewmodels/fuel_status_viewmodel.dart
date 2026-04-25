// Port of FuelStatusViewModel.swift — Jim Mittler
// ViewModel for fuel system status display.
// Subscribes to OBDConnectionManager for fuel status updates covering Bank 1
// and Bank 2. Handles nil (waiting), empty, and populated states.

import 'dart:async';

import 'package:flutter_obd2/flutter_obd2.dart';

import '../core/obd_connection_manager.dart';
import '../core/pid_interest_registry.dart';
import 'base_view_model.dart';

class FuelStatusViewModel extends BaseViewModel {
  final FuelStatusProviding _provider;
  final PidInterestRegistry _interestRegistry;
  final String _interestToken;
  bool _isVisible = false;

  /// null = waiting for first update
  List<StatusCodeMetadata?>? _status;
  List<StatusCodeMetadata?>? get status => _status;

  StreamSubscription? _sub;

  FuelStatusViewModel({
    FuelStatusProviding? provider,
    PidInterestRegistry? interestRegistry,
  })  : _provider = provider ?? OBDConnectionManager.instance,
        _interestRegistry = interestRegistry ?? PidInterestRegistry.instance,
        _interestToken =
            (interestRegistry ?? PidInterestRegistry.instance).makeToken() {
    _sub = _provider.fuelStatusStream.listen((newStatus) {
      if (newStatus == _status) return;
      _status = newStatus;
      notifyListeners();
    });
  }

  void setVisible(bool isVisible) {
    if (_isVisible == isVisible) return;
    _isVisible = isVisible;
    if (_isVisible) {
      _interestRegistry.replace({'0103'}, _interestToken);
    } else {
      _interestRegistry.clear(_interestToken);
    }
  }

  /// Fuel system status for Bank 1
  StatusCodeMetadata? get bank1 =>
      (_status != null && _status!.isNotEmpty) ? _status![0] : null;

  /// Fuel system status for Bank 2
  StatusCodeMetadata? get bank2 =>
      (_status != null && _status!.length > 1) ? _status![1] : null;

  /// True if any bank contains a non-null status value
  bool get hasAnyStatus {
    if (_status == null) return false;
    return _status!.any((s) => s != null);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _interestRegistry.clear(_interestToken);
    super.dispose();
  }
}
