// Port of BaseViewModel.swift — Jim Mittler
// Base class for all ViewModels.
// Provides a standard onChanged hook so all ViewModels can trigger
// CarPlay refreshes (CarPlay doesn't support two-way SwiftUI binding).

import 'package:flutter/foundation.dart';

abstract class BaseViewModel extends ChangeNotifier {
  /// Hook for CarPlay integration — set by the CarPlay controller to
  /// receive notifications when data changes.
  VoidCallback? onChanged;

  @override
  void notifyListeners() {
    super.notifyListeners();
    onChanged?.call();
  }
}
