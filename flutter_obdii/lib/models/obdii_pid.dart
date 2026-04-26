// Port of OBDIIPID.swift — Jim Mittler
// PID data model and library loader.
// Defines ObdiiPid struct with metadata (ranges, units, formulas), ValueRange
// for min/max bounds, and UnitConversion for metric/imperial conversion.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart' show Colors, Color;
import 'package:flutter/services.dart';

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
    String pidCommand;
    if (pidRaw is String) {
      pidCommand = pidRaw;
    } else if (pidRaw is Map) {
      // Map the SwiftOBD2 command names to hex codes
      pidCommand = _swiftCommandToHex(pidRaw['command'] as String? ?? '');
    } else {
      pidCommand = '';
    }

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

// ─────────────────────────────────────────────
// MARK: Swift OBD command name → OBD2 hex code
// ─────────────────────────────────────────────

/// Maps SwiftOBD2 command enum names to their 4-char OBD2 hex strings.
String _swiftCommandToHex(String command) {
  const map = <String, String>{
    'fuelStatus':              '0103',
    'status':                  '0101',
    'GET_DTC':                 '03',
    'intakeTemp':              '010F',
    'controlModuleVoltage':    '0142',
    'coolantTemp':             '0105',
    'rpm':                     '010C',
    'commandedEquivRatio':     '0144',
    'speed':                   '010D',
    'engineOilTemp':           '015C',
    'fuelPressure':            '010A',
    'catalystTempB1S1':        '013C',
    'catalystTempB2S1':        '013D',
    'catalystTempB1S2':        '013E',
    'catalystTempB2S2':        '013F',
    'throttlePos':             '0111',
    'throttleActuator':        '014C',
    'throttlePosB':            '0147',
    'throttlePosC':            '0148',
    'throttlePosD':            '0149',
    'throttlePosE':            '014A',
    'throttlePosF':            '014B',
    'timingAdvance':           '010E',
    'ambientAirTemp':          '0146',
    'relativeThrottlePos':     '0145',
    'engineLoad':              '0104',
    'absoluteLoad':            '0143',
    'fuelLevel':               '012F',
    'barometricPressure':      '0133',
    'intakePressure':          '010B',
    'fuelRailPressureAbs':     '0159',
    'fuelRailPressureDirect':  '0123',
    'fuelRailPressureVac':     '0122',
    'maf':                     '0110',
    'fuelRate':                '015E',
    'relativeAccelPos':        '015A',
    'shortFuelTrim1':          '0106',
    'longFuelTrim1':           '0107',
    'shortFuelTrim2':          '0108',
    'longFuelTrim2':           '0109',
    'O2Bank1Sensor1':          '0114',
    'O2Bank1Sensor2':          '0115',
    'O2Bank1Sensor3':          '0116',
    'O2Bank1Sensor4':          '0117',
    'O2Bank2Sensor1':          '0118',
    'O2Bank2Sensor2':          '0119',
    'O2Bank2Sensor3':          '011A',
    'O2Sensor':                '0113',
    'fuelType':                '0151',
    'obdcompliance':           '011C',
    'statusDriveCycle':        '0141',
    'freezeDTC':               '0202',
    'airStatus':               '0112',
    'evapVaporPressure':       '0132',
    'evapVaporPressureAlt':    '0154',
    'evapVaporPressureAbs':    '0153',
    'evaporativePurge':        '012E',
    'commandedEGR':            '012C',
    'EGRError':                '012D',
    'warmUpsSinceDTCCleared':  '0130',
    'distanceSinceDTCCleared': '0131',
    'distanceWMIL':            '0121',
    'runTime':                 '011F',
    'runTimeMIL':              '014D',
    'timeSinceDTCCleared':     '014E',
    'hybridBatteryLife':       '015B',
    'fuelInjectionTiming':     '015D',
    'maxMAF':                  '0150',
    'ethanoPercent':           '0152',
    'O2Sensor1WRVolatage':     '0124',
    'O2Sensor2WRVolatage':     '0125',
    'O2Sensor3WRVolatage':     '0126',
    'O2Sensor4WRVolatage':     '0127',
    'O2Sensor5WRVolatage':     '0128',
    'O2Sensor6WRVolatage':     '0129',
    'O2Sensor7WRVolatage':     '012A',
    'O2Sensor8WRVolatage':     '012B',
    'O2Sensor1WRCurrent':      '0134',
    'O2Sensor2WRCurrent':      '0135',
    'O2Sensor3WRCurrent':      '0136',
    'O2Sensor4WRCurrent':      '0137',
    'O2Sensor5WRCurrent':      '0138',
    'O2Sensor6WRCurrent':      '0139',
    'O2Sensor7WRCurrent':      '013A',
    'O2Sensor8WRCurrent':      '013B',
    // GM mode 22 PIDs
    'engineOilPressure':       '2215B4',
    'ACHighPressure':          '2215BD',
    'transFluidTemp':          '2215BE',
  };
  return map[command] ?? command;
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
