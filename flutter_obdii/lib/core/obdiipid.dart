// Port of OBDIIPID.swift — Jim Mittler
// PID data model and library loader.
// Defines ObdiiPid struct with metadata (ranges, units, formulas), ValueRange
// for min/max bounds, and UnitConversion for metric/imperial conversion.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart' show Colors, Color;
import 'package:flutter/services.dart';
import 'package:flutter_obd2/src/commands/commands.dart' as obd2lib;

// ─────────────────────────────────────────────
// MARK: ValueRange
// ─────────────────────────────────────────────

class ValueRange {
  final double min;
  final double max;

  const ValueRange({required this.min, required this.max});

  factory ValueRange.fromJson(Map<String, dynamic> json) => ValueRange(
        min: (json['min'] as num).toDouble(),
        max: (json['max'] as num).toDouble(),
      );

  bool contains(double value) => value >= min && value <= max;

  double clampedValue(double value) => math.max(min, math.min(value, max));

  bool overlaps(ValueRange other) => !(other.max < min || other.min > max);

  double normalizedPosition(double value) {
    if (max == min) return 0;
    return (value - min) / (max - min);
  }

  ValueRange converted(String unitLabel, bool isMetric) {
    final conv = UnitConversion.fromMetricLabel(unitLabel, isMetric);
    if (conv == null) return this;
    return ValueRange(min: conv.convert(min), max: conv.convert(max));
  }

  @override
  bool operator ==(Object other) =>
      other is ValueRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

// ─────────────────────────────────────────────
// MARK: UnitConversion
// ─────────────────────────────────────────────

class UnitConversion {
  final String displayLabel;
  final double Function(double) convert;

  UnitConversion(this.displayLabel, this.convert);

  static UnitConversion? fromMetricLabel(String label, bool isMetric) {
    switch (label) {
      case '°C':
        return isMetric
            ? UnitConversion('°C', (v) => v)
            : UnitConversion('°F', (v) => (v * 9 / 5) + 32);
      case 'km/h':
        return isMetric
            ? UnitConversion('km/h', (v) => v)
            : UnitConversion('mph', (v) => v * 0.621371);
      case 'kPa':
        return isMetric
            ? UnitConversion('kPa', (v) => v)
            : UnitConversion('psi', (v) => v * 0.145038);
      case 'km':
        return isMetric
            ? UnitConversion('km', (v) => v)
            : UnitConversion('mi', (v) => v * 0.621371);
      case 'g/s':
        return isMetric
            ? UnitConversion('g/s', (v) => v)
            : UnitConversion('lb/min', (v) => v * 0.132277);
      case 'L/h':
        return isMetric
            ? UnitConversion('L/h', (v) => v)
            : UnitConversion('gal/h', (v) => v * 0.264172);
      case 'RPM':
      case '%':
      case 'V':
      case 'λ':
      case 'NA':
      case 'Pa':
      case 'mA':
      case '° BTDC':
      case 's':
      case 'count':
        return UnitConversion(label, (v) => v);
      default:
        return null;
    }
  }
}

// ─────────────────────────────────────────────
// MARK: ObdiiPid
// ─────────────────────────────────────────────

enum ObdPidKind { gauge, status }

class ObdiiPid {
  final String id;
  bool enabled;
  final String label;
  final String name;
  final String pidCommand; // e.g. "010C"
  final String? formula;
  final String? units;
  final ValueRange? typicalRange;
  final ValueRange? warningRange;
  final ValueRange? dangerRange;
  final String? notes;
  final ObdPidKind kind;

  ObdiiPid({
    required this.id,
    this.enabled = false,
    required this.label,
    required this.name,
    required this.pidCommand,
    this.formula,
    this.units,
    this.typicalRange,
    this.warningRange,
    this.dangerRange,
    this.notes,
    this.kind = ObdPidKind.gauge,
  });

  // Copy with modified enabled flag (needed for PIDStore toggle)
  ObdiiPid copyWith({bool? enabled}) => ObdiiPid(
        id: id,
        enabled: enabled ?? this.enabled,
        label: label,
        name: name,
        pidCommand: pidCommand,
        formula: formula,
        units: units,
        typicalRange: typicalRange,
        warningRange: warningRange,
        dangerRange: dangerRange,
        notes: notes,
        kind: kind,
      );

  // ── JSON ──────────────────────────────────────

  factory ObdiiPid.fromJson(Map<String, dynamic> json) {
    // pid field can be an object {"type": "mode1", "command": "rpm"} OR a string like "010C"
    final pidRaw = json['pid'];
    final pidCommand = _resolvePidCommand(pidRaw);

    return ObdiiPid(
      id: (json['id'] as String?) ?? _generateId(),
      enabled: json['enabled'] as bool? ?? false,
      label: json['label'] as String? ?? '',
      name: json['name'] as String? ?? json['label'] as String? ?? '',
      pidCommand: pidCommand,
      formula: json['formula'] as String?,
      units: json['units'] as String?,
      typicalRange: json['typicalRange'] != null
          ? ValueRange.fromJson(json['typicalRange'])
          : null,
      warningRange: json['warningRange'] != null
          ? ValueRange.fromJson(json['warningRange'])
          : null,
      dangerRange: json['dangerRange'] != null
          ? ValueRange.fromJson(json['dangerRange'])
          : null,
      notes: json['notes'] as String?,
      kind: json['kind'] == 'status' ? ObdPidKind.status : ObdPidKind.gauge,
    );
  }

  // ── Formatting ───────────────────────────────

  String unitLabel(bool isMetric) {
    if (units == null) return '';
    return UnitConversion.fromMetricLabel(units!, isMetric)?.displayLabel ??
        units!;
  }

  ValueRange? _convertedRange(ValueRange? range, bool isMetric) {
    if (range == null || units == null) return range;
    return range.converted(units!, isMetric);
  }

  ValueRange? typicalRangeFor(bool isMetric) =>
      _convertedRange(typicalRange, isMetric);
  ValueRange? warningRangeFor(bool isMetric) =>
      _convertedRange(warningRange, isMetric);
  ValueRange? dangerRangeFor(bool isMetric) =>
      _convertedRange(dangerRange, isMetric);

  ValueRange combinedRange() {
    final all = [typicalRange, warningRange, dangerRange].whereType<ValueRange>();
    if (all.isEmpty) return const ValueRange(min: 0, max: 1);
    final minV = all.map((r) => r.min).reduce(math.min);
    final maxV = all.map((r) => r.max).reduce(math.max);
    return ValueRange(min: minV, max: maxV);
  }

  String displayRange(bool isMetric) {
    if (units == null) return '';
    final converted = combinedRange().converted(units!, isMetric);
    final label = unitLabel(isMetric);
    final digits = _preferredFractionDigits(label);
    final minStr = _fmt(converted.min, digits);
    final maxStr = _fmt(converted.max, digits);
    return '$minStr – $maxStr $label';
  }

  String formattedValue(double value, bool isMetric,
      {bool includeUnits = true}) {
    final label = unitLabel(isMetric);
    final digits = _preferredFractionDigits(label);
    final v = _fmt(value, digits);
    return includeUnits && label.isNotEmpty ? '$v $label' : v;
  }

  Color colorForValue(double value, bool isMetric) {
    if (dangerRangeFor(isMetric)?.contains(value) ?? false) return Colors.red;
    if (warningRangeFor(isMetric)?.contains(value) ?? false) return Colors.orange;
    if (typicalRangeFor(isMetric)?.contains(value) ?? false) return Colors.green;
    return Colors.blueGrey;
  }

  int _preferredFractionDigits(String label) {
    switch (label) {
      case 'RPM':
      case '°C':
      case '°F':
      case '%':
      case 'kPa':
      case 'psi':
      case 'km/h':
      case 'mph':
      case 'km':
      case 'mi':
      case 's':
      case 'count':
        return 0;
      case 'V':
      case 'g/s':
      case 'λ':
        return 2;
      case 'L/h':
        return 1;
      default:
        return 0;
    }
  }

  String _fmt(double v, int digits) =>
      v.toStringAsFixed(digits);

  @override
  bool operator ==(Object other) => other is ObdiiPid && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

String _resolvePidCommand(dynamic pidRaw) {
  if (pidRaw is String) return pidRaw.toUpperCase();
  if (pidRaw is! Map) return '';
  final pidType = pidRaw['type'] as String?;
  final alias = (pidRaw['command'] as String? ?? '').trim();
  if (alias.isEmpty) return '';
  return obd2lib.Commands.resolveCommandId(alias, pidType: pidType);
}

// Simple counter-based fallback ID
int _idCounter = 0;
String _generateId() => 'pid_${++_idCounter}';

// ─────────────────────────────────────────────
// MARK: ObdiiPidLibrary
// ─────────────────────────────────────────────

class ObdiiPidLibrary {
  static Future<List<ObdiiPid>> loadFromJSON() async {
    try {
      final jsonString = await rootBundle.loadString('assets/OBDPIDs.json');
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((j) => ObdiiPid.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('ObdiiPidLibrary: Failed to load OBDPIDs.json: $e');
      return [];
    }
  }
}

// Swift-parity name aliases.
typedef OBDIIPID = ObdiiPid;
typedef OBDValueRange = ValueRange;
