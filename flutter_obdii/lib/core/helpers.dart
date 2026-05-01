/// Swift-parity helpers entry point.
///
/// Keep cross-cutting utility helpers in core to mirror `Helpers.swift`.
class Helpers {
  static double clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }
}
