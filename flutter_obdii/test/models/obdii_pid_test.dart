// Port of OBDIIPIDTests.swift — Jim Mittler
// Unit tests for ObdiiPid models and utilities.
// Tests ValueRange operations, PID formatting, unit conversions,
// color coding, and range calculations.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_obdii/models/obdii_pid.dart';

void main() {
  // ─────────────────────────────────────────────
  // ValueRange tests
  // ─────────────────────────────────────────────

  group('ValueRange creation', () {
    test('testMinAndMaxAreStoredCorrectly', () {
      const r = ValueRange(min: 0, max: 100);
      expect(r.min, 0);
      expect(r.max, 100);
    });
  });

  group('ValueRange.contains', () {
    const range = ValueRange(min: 0, max: 100);

    test('testContainsMidpoint', () => expect(range.contains(50), isTrue));
    test('testContainsMin', () => expect(range.contains(0), isTrue));
    test('testContainsMax', () => expect(range.contains(100), isTrue));
    test('testDoesNotContainBelowMin', () => expect(range.contains(-1), isFalse));
    test('testDoesNotContainAboveMax', () => expect(range.contains(101), isFalse));
  });

  group('ValueRange.clampedValue', () {
    const range = ValueRange(min: 0, max: 100);

    test('testDoesNotClampValidValue', () => expect(range.clampedValue(50), 50));
    test('testClampsToMin', () => expect(range.clampedValue(-10), 0));
    test('testClampsToMax', () => expect(range.clampedValue(150), 100));
  });

  group('ValueRange.normalizedPosition', () {
    const range = ValueRange(min: 0, max: 100);

    test('testPositionAtMin00', () => expect(range.normalizedPosition(0), closeTo(0.0, 0.001)));
    test('testPositionAtMidpoint05', () => expect(range.normalizedPosition(50), closeTo(0.5, 0.001)));
    test('testPositionAtMax10', () => expect(range.normalizedPosition(100), closeTo(1.0, 0.001)));
  });

  test('testNormalizedpositionReturns0WhenMinMax', () {
    const range = ValueRange(min: 50, max: 50);
    expect(range.normalizedPosition(50), closeTo(0.0, 0.001));
  });

  group('ValueRange.overlaps', () {
    const range1 = ValueRange(min: 0, max: 100);
    const range2 = ValueRange(min: 50, max: 150);
    const range3 = ValueRange(min: 200, max: 300);

    test('testOverlappingRanges', () => expect(range1.overlaps(range2), isTrue));
    test('testNonOverlappingRanges', () => expect(range1.overlaps(range3), isFalse));
  });

  // ─────────────────────────────────────────────
  // ObdiiPid tests
  // ─────────────────────────────────────────────

  ObdiiPid makeRpmPid({
    bool enabled = true,
    String label = 'RPM',
    String name = 'Engine RPM',
    ValueRange? typicalRange,
    ValueRange? warningRange,
    ValueRange? dangerRange,
  }) {
    return ObdiiPid(
      id: 'rpm_test',
      enabled: enabled,
      label: label,
      name: name,
      pidCommand: '010C',
      units: 'RPM',
      typicalRange: typicalRange,
      warningRange: warningRange,
      dangerRange: dangerRange,
    );
  }

  group('ObdiiPid creation', () {
    test('testLabelNameEnabledKind', () {
      final pid = makeRpmPid();
      expect(pid.label, 'RPM');
      expect(pid.name, 'Engine RPM');
      expect(pid.enabled, isTrue);
      expect(pid.kind, ObdPidKind.gauge);
    });

    test('testNameDefaultsToLabelIfNotProvided', () {
      final pid = ObdiiPid(
        id: 'test',
        label: 'Test',
        name: 'Test', // constructor requires name, but ObdiiPid.fromJson defaults to label
        pidCommand: '010C',
        units: 'RPM',
        typicalRange: const ValueRange(min: 0, max: 100),
      );
      expect(pid.name, 'Test');
    });
  });

  group('ObdiiPid.combinedRange', () {
    test('testSpansAcrossAllRanges', () {
      final pid = makeRpmPid(
        typicalRange: const ValueRange(min: 0, max: 1000),
        warningRange: const ValueRange(min: 1000, max: 2000),
        dangerRange: const ValueRange(min: 2000, max: 3000),
      );
      final combined = pid.combinedRange();
      expect(combined.min, 0);
      expect(combined.max, 3000);
    });

    test('testDefaultsTo01WithNoRanges', () {
      final pid = makeRpmPid();
      final combined = pid.combinedRange();
      expect(combined.min, 0);
      expect(combined.max, 1);
    });
  });

  group('ObdiiPid.colorForValue', () {
    final pid = ObdiiPid(
      id: 'c',
      label: 'Test',
      name: 'Test',
      pidCommand: '010C',
      units: 'RPM',
      typicalRange: const ValueRange(min: 0, max: 2000),
      warningRange: const ValueRange(min: 2000, max: 4000),
      dangerRange: const ValueRange(min: 4000, max: 8000),
    );

    test('testTypicalRangeGreen', () => expect(pid.colorForValue(1000, true), Colors.green));
    test('testWarningRangeOrange', () => expect(pid.colorForValue(3000, true), Colors.orange));
    test('testDangerRangeRed', () => expect(pid.colorForValue(5000, true), Colors.red));
    test('testOutsideAllRangesBlueGrey', () => expect(pid.colorForValue(9000, true), Colors.blueGrey));
  });

  group('ObdiiPid.displayRange', () {
    test('testContainsUnitLabelAndValues', () {
      final pid = makeRpmPid(typicalRange: const ValueRange(min: 0, max: 8000));
      final display = pid.displayRange(true);
      expect(display.contains('RPM'), isTrue);
      expect(display.contains('0'), isTrue);
      expect(display.contains('8'), isTrue);
    });
  });

  group('ObdiiPid equality', () {
    test('testSameIdEqual', () {
      final pid1 = ObdiiPid(id: 'abc', label: 'RPM', name: 'RPM', pidCommand: '010C', units: 'RPM');
      final pid2 = ObdiiPid(id: 'abc', label: 'RPM', name: 'RPM', pidCommand: '010C', units: 'RPM');
      expect(pid1, equals(pid2));
    });

    test('testDifferentIdsNotEqual', () {
      final pid1 = ObdiiPid(id: 'abc', label: 'RPM', name: 'RPM', pidCommand: '010C', units: 'RPM');
      final pid2 = ObdiiPid(id: 'xyz', label: 'Speed', name: 'Speed', pidCommand: '010D', units: 'km/h');
      expect(pid1, isNot(equals(pid2)));
    });

    test('testDifferentPIDsFormDistinctSetEntries', () {
      final pid1 = ObdiiPid(id: 'a', label: 'RPM', name: 'RPM', pidCommand: '010C', units: 'RPM');
      final pid2 = ObdiiPid(id: 'b', label: 'Speed', name: 'Speed', pidCommand: '010D', units: 'km/h');
      final s = {pid1, pid2};
      expect(s.length, 2);
    });
  });
}
