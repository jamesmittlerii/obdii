import 'package:flutter/material.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/models/obdii_pid.dart';
import 'package:flutter_obdii/views/ring_gauge_widget.dart';

ObdiiPid _testPid({
  String units = 'RPM',
  ValueRange? typical,
  ValueRange? warning,
  ValueRange? danger,
}) {
  return ObdiiPid(
    id: 'pid_rpm',
    enabled: true,
    label: 'RPM',
    name: 'Engine RPM',
    pidCommand: '010C',
    units: units,
    typicalRange: typical,
    warningRange: warning,
    dangerRange: danger,
    kind: ObdPidKind.gauge,
  );
}

Widget _build(ObdiiPid pid, PIDStats? stats, {bool isMetric = true}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 180,
        height: 180,
        child: RingGaugeWidget(pid: pid, stats: stats, isMetric: isMetric),
      ),
    ),
  );
}

PIDStats _stats(double value, obd2lib.Unit unit) =>
    PIDStats(pid: '010C', latest: obd2lib.MeasurementResult(value, unit));

void main() {
  testWidgets('testHasGeometryReader', (tester) async {
    await tester.pumpWidget(_build(_testPid(), null));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('testHasZStack', (tester) async {
    await tester.pumpWidget(_build(_testPid(), null));
    expect(find.byType(Column), findsOneWidget);
  });

  testWidgets('testHasVStackForText', (tester) async {
    await tester.pumpWidget(_build(_testPid(), null));
    expect(find.byType(Column), findsOneWidget);
  });

  testWidgets('testDisplaysTextWhenNoMeasurement', (tester) async {
    await tester.pumpWidget(_build(_testPid(), null));
    expect(find.textContaining('—'), findsOneWidget);
  });

  testWidgets('testDisplaysTextWithMeasurement', (tester) async {
    await tester.pumpWidget(_build(_testPid(), _stats(2500, obd2lib.Unit.rpm)));
    expect(find.text('2500'), findsOneWidget);
  });

  testWidgets('testTextContent', (tester) async {
    await tester.pumpWidget(_build(_testPid(), _stats(2500, obd2lib.Unit.rpm)));
    expect(find.byType(Text), findsWidgets);
  });

  testWidgets('testInitWithTypicalRange', (tester) async {
    final pid = _testPid(typical: const ValueRange(min: 80, max: 100), units: '°C');
    await tester.pumpWidget(_build(pid, null));
    expect(find.byType(RingGaugeWidget), findsOneWidget);
  });

  testWidgets('testInitWithAllRanges', (tester) async {
    final pid = _testPid(
      units: '°C',
      typical: const ValueRange(min: 80, max: 100),
      warning: const ValueRange(min: 100, max: 110),
      danger: const ValueRange(min: 110, max: 120),
    );
    await tester.pumpWidget(_build(pid, null));
    expect(find.byType(RingGaugeWidget), findsOneWidget);
  });

  testWidgets('testInitWithoutRanges', (tester) async {
    final pid = _testPid(units: '%');
    await tester.pumpWidget(_build(pid, null));
    expect(find.byType(RingGaugeWidget), findsOneWidget);
  });

  testWidgets('testMetricUnits', (tester) async {
    final pid = _testPid(units: 'km/h', typical: const ValueRange(min: 0, max: 120));
    await tester.pumpWidget(_build(pid, _stats(100, obd2lib.Unit.kilometersPerHour), isMetric: true));
    expect(find.text('km/h'), findsOneWidget);
  });

  testWidgets('testImperialUnits', (tester) async {
    final pid = _testPid(units: 'km/h', typical: const ValueRange(min: 0, max: 120));
    await tester.pumpWidget(_build(pid, _stats(60, obd2lib.Unit.kilometersPerHour), isMetric: false));
    expect(find.text('mph'), findsOneWidget);
  });

  testWidgets('testZeroValue', (tester) async {
    await tester.pumpWidget(_build(_testPid(), _stats(0, obd2lib.Unit.rpm)));
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('testNegativeValue', (tester) async {
    final pid = _testPid(units: '°C', typical: const ValueRange(min: -40, max: 50));
    await tester.pumpWidget(_build(pid, _stats(-10, obd2lib.Unit.celsius)));
    expect(find.byType(RingGaugeWidget), findsOneWidget);
  });

  testWidgets('testMaxValue', (tester) async {
    await tester.pumpWidget(_build(_testPid(), _stats(8000, obd2lib.Unit.rpm)));
    expect(find.text('8000'), findsOneWidget);
  });

  test('testColorForTypicalValue', () {
    final pid = _testPid(
      units: '%',
      typical: const ValueRange(min: 0, max: 60),
      warning: const ValueRange(min: 61, max: 80),
      danger: const ValueRange(min: 81, max: 100),
    );
    expect(pid.colorForValue(30, true), Colors.green);
  });

  test('testColorForWarningValue', () {
    final pid = _testPid(
      units: '%',
      typical: const ValueRange(min: 0, max: 60),
      warning: const ValueRange(min: 61, max: 80),
      danger: const ValueRange(min: 81, max: 100),
    );
    expect(pid.colorForValue(70, true), Colors.orange);
  });

  test('testColorForDangerValue', () {
    final pid = _testPid(
      units: '%',
      typical: const ValueRange(min: 0, max: 60),
      warning: const ValueRange(min: 61, max: 80),
      danger: const ValueRange(min: 81, max: 100),
    );
    expect(pid.colorForValue(90, true), Colors.red);
  });

  testWidgets('testRPMGauge', (tester) async {
    await tester.pumpWidget(_build(_testPid(), _stats(1200, obd2lib.Unit.rpm)));
    expect(find.byType(RingGaugeWidget), findsOneWidget);
  });

  testWidgets('testTemperatureGauge', (tester) async {
    final pid = _testPid(units: '°C', typical: const ValueRange(min: 80, max: 100));
    await tester.pumpWidget(_build(pid, _stats(90, obd2lib.Unit.celsius)));
    expect(find.byType(RingGaugeWidget), findsOneWidget);
  });

  testWidgets('testSpeedGauge', (tester) async {
    final pid = _testPid(units: 'km/h', typical: const ValueRange(min: 0, max: 120));
    await tester.pumpWidget(_build(pid, _stats(60, obd2lib.Unit.kilometersPerHour)));
    expect(find.byType(RingGaugeWidget), findsOneWidget);
  });
}

