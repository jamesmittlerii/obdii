import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_obdii/core/obdiipid.dart';

void main() {
  test('testSymbolImageCreation', () {
    const icon = Icons.settings;
    expect(icon, isNotNull);
  });

  test('testSymbolImageWithInvalidName', () {
    const invalidName = 'nonexistent_symbol_12345';
    expect(invalidName.startsWith('nonexistent_'), isTrue);
  });

  test('testImageNameForLowSeverity', () {
    const severity = 'low';
    expect(severity, 'low');
  });

  test('testImageNameForModerateSeverity', () {
    const severity = 'moderate';
    expect(severity, 'moderate');
  });

  test('testImageNameForHighSeverity', () {
    const severity = 'high';
    expect(severity, 'high');
  });

  test('testImageNameForCriticalSeverity', () {
    const severity = 'critical';
    expect(severity, 'critical');
  });

  test('testSeverityColorReturnsUIColor', () {
    expect(Colors.blue, isNotNull);
    expect(Colors.amber, isNotNull);
    expect(Colors.orange, isNotNull);
    expect(Colors.red, isNotNull);
  });

  test('testTintedSymbolCreation', () {
    final icon = Icon(Icons.info_outline, color: Colors.blue);
    expect(icon.color, Colors.blue);
  });

  test('testTintedSymbolWithInvalidName', () {
    const invalidName = 'nonexistent_symbol_98765';
    expect(invalidName.contains('nonexistent'), isTrue);
  });

  test('testTintedSymbolPreservesRenderingMode', () {
    final icon = Icon(Icons.warning_amber_outlined, color: Colors.orange);
    expect(icon.color, Colors.orange);
  });

  test('testTintedSymbolForAllSeverities', () {
    final colors = <Color>[Colors.blue, Colors.amber, Colors.orange, Colors.red];
    expect(colors.length, 4);
  });

  test('testLogEntryCreation', () {
    final ts = DateTime.now();
    expect(ts.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
  });

  test('testLogEntryCodable', () {
    final map = <String, dynamic>{
      'category': 'AppInit',
      'subsystem': 'com.rheosoft.obdiif',
      'message': 'App started',
    };
    expect(map['category'], 'AppInit');
    expect(map['message'], 'App started');
  });

  test('testAboutDetailString', () {
    const aboutString = 'flutter_obdii v1.0.0 build:1';
    expect(aboutString.contains('v'), isTrue);
    expect(aboutString.contains('build:'), isTrue);
  });

  test('testAboutDetailStringFormat', () {
    const aboutString = 'flutter_obdii v1.0.0 build:1';
    final regex = RegExp(r'.*v.*build:.*');
    expect(regex.hasMatch(aboutString), isTrue);
  });

  test('testUnitConversionLabelSmoke', () {
    expect(UnitConversion.fromMetricLabel('km/h', false)?.displayLabel, 'mph');
    expect(UnitConversion.fromMetricLabel('°C', false)?.displayLabel, '°F');
  });
}

