import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_obdii/core/config_data.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/models/obdii_pid.dart';

void main() {
  // MeasurementUnit / ConnectionType parity checks
  test('testMeasurementunitMetricDisplayName', () => expect(MeasurementUnit.metric.displayName, 'Metric'));
  test('testMeasurementunitImperialDisplayName', () => expect(MeasurementUnit.imperial.displayName, 'Imperial'));
  test('testMeasurementunitNextFromMetric', () => expect(MeasurementUnit.metric.next, MeasurementUnit.imperial));
  test('testMeasurementunitNextFromImperial', () => expect(MeasurementUnit.imperial.next, MeasurementUnit.metric));
  test('testConnectiontypeBluetoothRaw', () => expect(ConnectionType.bluetooth.rawValue, 'bluetooth'));
  test('testConnectiontypeWifiRaw', () => expect(ConnectionType.wifi.rawValue, 'wifi'));
  test('testConnectiontypeDemoRaw', () => expect(ConnectionType.demo.rawValue, 'demo'));
  test('testConnectiontypeFromRawBluetooth', () => expect(ConnectionType.fromRaw('bluetooth'), ConnectionType.bluetooth));
  test('testConnectiontypeFromRawWifi', () => expect(ConnectionType.fromRaw('wifi'), ConnectionType.wifi));
  test('testConnectiontypeFromRawDemo', () => expect(ConnectionType.fromRaw('demo'), ConnectionType.demo));
  test('testConnectiontypeFromRawUnknownDefaultsBluetooth', () => expect(ConnectionType.fromRaw('x'), ConnectionType.bluetooth));

  // UnitConversion label mapping checks
  test('testUnitconversionCelsiusMetricLabel', () => expect(UnitConversion.fromMetricLabel('°C', true)?.displayLabel, '°C'));
  test('testUnitconversionCelsiusImperialLabel', () => expect(UnitConversion.fromMetricLabel('°C', false)?.displayLabel, '°F'));
  test('testUnitconversionSpeedMetricLabel', () => expect(UnitConversion.fromMetricLabel('km/h', true)?.displayLabel, 'km/h'));
  test('testUnitconversionSpeedImperialLabel', () => expect(UnitConversion.fromMetricLabel('km/h', false)?.displayLabel, 'mph'));
  test('testUnitconversionPressureMetricLabel', () => expect(UnitConversion.fromMetricLabel('kPa', true)?.displayLabel, 'kPa'));
  test('testUnitconversionPressureImperialLabel', () => expect(UnitConversion.fromMetricLabel('kPa', false)?.displayLabel, 'psi'));
  test('testUnitconversionDistanceMetricLabel', () => expect(UnitConversion.fromMetricLabel('km', true)?.displayLabel, 'km'));
  test('testUnitconversionDistanceImperialLabel', () => expect(UnitConversion.fromMetricLabel('km', false)?.displayLabel, 'mi'));
  test('testUnitconversionMafMetricLabel', () => expect(UnitConversion.fromMetricLabel('g/s', true)?.displayLabel, 'g/s'));
  test('testUnitconversionMafImperialLabel', () => expect(UnitConversion.fromMetricLabel('g/s', false)?.displayLabel, 'lb/min'));
  test('testUnitconversionFuelMetricLabel', () => expect(UnitConversion.fromMetricLabel('L/h', true)?.displayLabel, 'L/h'));
  test('testUnitconversionFuelImperialLabel', () => expect(UnitConversion.fromMetricLabel('L/h', false)?.displayLabel, 'gal/h'));
  test('testUnitconversionRPMPassthrough', () => expect(UnitConversion.fromMetricLabel('RPM', false)?.displayLabel, 'RPM'));
  test('testUnitconversionPercentPassthrough', () => expect(UnitConversion.fromMetricLabel('%', false)?.displayLabel, '%'));
  test('testUnitconversionVoltsPassthrough', () => expect(UnitConversion.fromMetricLabel('V', false)?.displayLabel, 'V'));
  test('testUnitconversionLambdaPassthrough', () => expect(UnitConversion.fromMetricLabel('λ', false)?.displayLabel, 'λ'));
  test('testUnitconversionNAPassthrough', () => expect(UnitConversion.fromMetricLabel('NA', false)?.displayLabel, 'NA'));
  test('testUnitconversionPaPassthrough', () => expect(UnitConversion.fromMetricLabel('Pa', false)?.displayLabel, 'Pa'));
  test('testUnitconversionMAPassthrough', () => expect(UnitConversion.fromMetricLabel('mA', false)?.displayLabel, 'mA'));
  test('testUnitconversionDegreesPassthrough', () => expect(UnitConversion.fromMetricLabel('° BTDC', false)?.displayLabel, '° BTDC'));
  test('testUnitconversionSecondsPassthrough', () => expect(UnitConversion.fromMetricLabel('s', false)?.displayLabel, 's'));
  test('testUnitconversionCountPassthrough', () => expect(UnitConversion.fromMetricLabel('count', false)?.displayLabel, 'count'));
  test('testUnitconversionUnknownReturnsNull', () => expect(UnitConversion.fromMetricLabel('???', true), isNull));

  // UnitConversion numeric conversion checks
  test('testCelsiusToFahrenheit032', () => expect(UnitConversion.fromMetricLabel('°C', false)!.convert(0), 32));
  test('testCelsiusToFahrenheit100212', () => expect(UnitConversion.fromMetricLabel('°C', false)!.convert(100), 212));
  test('testKmhToMphConverts', () => expect(UnitConversion.fromMetricLabel('km/h', false)!.convert(100), closeTo(62.1371, 0.001)));
  test('testKpaToPsiConverts', () => expect(UnitConversion.fromMetricLabel('kPa', false)!.convert(100), closeTo(14.5038, 0.001)));
  test('testKmToMiConverts', () => expect(UnitConversion.fromMetricLabel('km', false)!.convert(10), closeTo(6.21371, 0.001)));
  test('testGSToLbMinConverts', () => expect(UnitConversion.fromMetricLabel('g/s', false)!.convert(10), closeTo(1.32277, 0.001)));
  test('testLHToGalHConverts', () => expect(UnitConversion.fromMetricLabel('L/h', false)!.convert(10), closeTo(2.64172, 0.001)));
  test('testRpmConversionIdentity', () => expect(UnitConversion.fromMetricLabel('RPM', false)!.convert(1234), 1234));
  test('testPercentConversionIdentity', () => expect(UnitConversion.fromMetricLabel('%', false)!.convert(50), 50));
  test('testVoltsConversionIdentity', () => expect(UnitConversion.fromMetricLabel('V', false)!.convert(12.7), 12.7));

  // PidInterestRegistry parity checks
  test('testRegistryStartsEmpty', () {
    final r = PidInterestRegistry();
    expect(r.interested, isEmpty);
  });
  test('testMaketokenReturnsNonEmptyString', () {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    expect(t.isNotEmpty, isTrue);
  });
  test('testMaketokenReturnsUniqueValues', () {
    final r = PidInterestRegistry();
    expect(r.makeToken(), isNot(equals(r.makeToken())));
  });
  test('testReplaceRegistersOnePid', () {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({'010C'}, t);
    expect(r.interested, {'010C'});
  });
  test('testReplaceRegistersMultiplePids', () {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({'010C', '010D'}, t);
    expect(r.interested, containsAll({'010C', '010D'}));
  });
  test('testReplaceEmptyClearsTokenDemand', () {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({'010C'}, t);
    r.replace({}, t);
    expect(r.interested, isEmpty);
  });
  test('testUnionAcrossTwoTokens', () {
    final r = PidInterestRegistry();
    final t1 = r.makeToken();
    final t2 = r.makeToken();
    r.replace({'010C'}, t1);
    r.replace({'010D'}, t2);
    expect(r.interested, containsAll({'010C', '010D'}));
  });
  test('testSharedPidUnionDeduplicates', () {
    final r = PidInterestRegistry();
    final t1 = r.makeToken();
    final t2 = r.makeToken();
    r.replace({'010C'}, t1);
    r.replace({'010C'}, t2);
    expect(r.interested.length, 1);
  });
  test('testClearRemovesTokenAfterMicrotask', () async {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({'010C'}, t);
    await r.clear(t);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(r.interested, isEmpty);
  });
  test('testClearOneTokenLeavesOtherTokenPid', () async {
    final r = PidInterestRegistry();
    final t1 = r.makeToken();
    final t2 = r.makeToken();
    r.replace({'010C'}, t1);
    r.replace({'010D'}, t2);
    await r.clear(t1);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(r.interested.contains('010D'), isTrue);
  });
  test('testClearUnknownTokenNoThrow', () async {
    final r = PidInterestRegistry();
    await r.clear('unknown');
    expect(r.interested, isEmpty);
  });
  test('testReplaceUnknownTokenWorks', () {
    final r = PidInterestRegistry();
    r.replace({'010C'}, 'manual');
    expect(r.interested.contains('010C'), isTrue);
  });

  // ObdiiPid id equality semantics
  test('testObdiipidEqualityIsIdBasedTrue', () {
    final a = ObdiiPid(id: 'same', label: 'A', name: 'A', pidCommand: '010C');
    final b = ObdiiPid(id: 'same', label: 'B', name: 'B', pidCommand: '010D');
    expect(a == b, isTrue);
  });
  test('testObdiipidEqualityIsIdBasedFalse', () {
    final a = ObdiiPid(id: 'a', label: 'A', name: 'A', pidCommand: '010C');
    final b = ObdiiPid(id: 'b', label: 'A', name: 'A', pidCommand: '010C');
    expect(a == b, isFalse);
  });
  test('testCopywithUpdatesEnabledTrue', () {
    final a = ObdiiPid(id: 'a', enabled: false, label: 'A', name: 'A', pidCommand: '010C');
    expect(a.copyWith(enabled: true).enabled, isTrue);
  });
  test('testCopywithPreservesId', () {
    final a = ObdiiPid(id: 'a', enabled: false, label: 'A', name: 'A', pidCommand: '010C');
    expect(a.copyWith(enabled: true).id, 'a');
  });
  test('testCopywithPreservesPidCommand', () {
    final a = ObdiiPid(id: 'a', enabled: false, label: 'A', name: 'A', pidCommand: '010C');
    expect(a.copyWith(enabled: true).pidCommand, '010C');
  });

  // Additional parity checks (fromJson / range / formatting)
  test('testFromjsonDefaultsEnabledFalse', () {
    final p = ObdiiPid.fromJson({'id': 'x', 'label': 'L', 'name': 'N', 'pid': '010C'});
    expect(p.enabled, isFalse);
  });
  test('testFromjsonDefaultsKindGauge', () {
    final p = ObdiiPid.fromJson({'id': 'x', 'label': 'L', 'name': 'N', 'pid': '010C'});
    expect(p.kind, ObdPidKind.gauge);
  });
  test('testFromjsonKindStatusMaps', () {
    final p = ObdiiPid.fromJson({'id': 'x', 'label': 'L', 'name': 'N', 'pid': '0101', 'kind': 'status'});
    expect(p.kind, ObdPidKind.status);
  });
  test('testFromjsonNameFallsBackToLabel', () {
    final p = ObdiiPid.fromJson({'id': 'x', 'label': 'LabelOnly', 'pid': '0101'});
    expect(p.name, 'LabelOnly');
  });
  test('testFromjsonUnknownPidMapCommandPassesThrough', () {
    final p = ObdiiPid.fromJson({'id': 'x', 'label': 'L', 'name': 'N', 'pid': {'type': 'mode1', 'command': 'FFFF'}});
    expect(p.pidCommand, 'FFFF');
  });
  test('testFromjsonParsesTypicalRange', () {
    final p = ObdiiPid.fromJson({
      'id': 'x',
      'label': 'L',
      'name': 'N',
      'pid': '010C',
      'typicalRange': {'min': 1, 'max': 2}
    });
    expect(p.typicalRange, const ValueRange(min: 1, max: 2));
  });
  test('testFromjsonParsesWarningRange', () {
    final p = ObdiiPid.fromJson({
      'id': 'x',
      'label': 'L',
      'name': 'N',
      'pid': '010C',
      'warningRange': {'min': 3, 'max': 4}
    });
    expect(p.warningRange, const ValueRange(min: 3, max: 4));
  });
  test('testFromjsonParsesDangerRange', () {
    final p = ObdiiPid.fromJson({
      'id': 'x',
      'label': 'L',
      'name': 'N',
      'pid': '010C',
      'dangerRange': {'min': 5, 'max': 6}
    });
    expect(p.dangerRange, const ValueRange(min: 5, max: 6));
  });
  test('testDisplayrangeEmptyUnitsReturnsEmptyString', () {
    final p = ObdiiPid(id: 'x', label: 'L', name: 'N', pidCommand: '010C');
    expect(p.displayRange(true), '');
  });
  test('testFormattedvalueWithEmptyUnitsNoTrailingSpace', () {
    final p = ObdiiPid(id: 'x', label: 'L', name: 'N', pidCommand: '010C');
    expect(p.formattedValue(10, true), '10');
  });
  test('testCombinedrangeUsesTypicalWhenOnlyTypicalExists', () {
    final p = ObdiiPid(
      id: 'x',
      label: 'L',
      name: 'N',
      pidCommand: '010C',
      typicalRange: const ValueRange(min: 3, max: 7),
    );
    expect(p.combinedRange(), const ValueRange(min: 3, max: 7));
  });
  test('testTypicalrangeforMetricKeepsValue', () {
    final p = ObdiiPid(
      id: 'x',
      label: 'L',
      name: 'N',
      pidCommand: '0105',
      units: '°C',
      typicalRange: const ValueRange(min: 0, max: 100),
    );
    expect(p.typicalRangeFor(true), const ValueRange(min: 0, max: 100));
  });
  test('testTypicalrangeforImperialConvertsValue', () {
    final p = ObdiiPid(
      id: 'x',
      label: 'L',
      name: 'N',
      pidCommand: '0105',
      units: '°C',
      typicalRange: const ValueRange(min: 0, max: 100),
    );
    expect(p.typicalRangeFor(false), const ValueRange(min: 32, max: 212));
  });
  test('testWarningrangeforNullRemainsNull', () {
    final p = ObdiiPid(id: 'x', label: 'L', name: 'N', pidCommand: '010C');
    expect(p.warningRangeFor(true), isNull);
  });
  test('testDangerrangeforNullRemainsNull', () {
    final p = ObdiiPid(id: 'x', label: 'L', name: 'N', pidCommand: '010C');
    expect(p.dangerRangeFor(true), isNull);
  });
  test('testColorforvalueWithNoRangesUsesBlueGrey', () {
    final p = ObdiiPid(id: 'x', label: 'L', name: 'N', pidCommand: '010C');
    expect(p.colorForValue(50, true), isNotNull);
  });
  test('testMeasurementunitNamesStable', () {
    expect(MeasurementUnit.metric.name, 'metric');
    expect(MeasurementUnit.imperial.name, 'imperial');
  });
  test('testConnectiontypeNamesStable', () {
    expect(ConnectionType.bluetooth.name, 'bluetooth');
    expect(ConnectionType.wifi.name, 'wifi');
    expect(ConnectionType.demo.name, 'demo');
  });
  test('testRegistryClearAfterReplaceEmptyStaysEmpty', () async {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({}, t);
    await r.clear(t);
    expect(r.interested, isEmpty);
  });
  test('testRegistryReplacingSameSetDoesNotChangeUnion', () {
    final r = PidInterestRegistry();
    final t = r.makeToken();
    r.replace({'010C'}, t);
    final before = Set<String>.from(r.interested);
    r.replace({'010C'}, t);
    expect(r.interested, equals(before));
  });
  test('testRegistryWithThreeTokensUnionsAll', () {
    final r = PidInterestRegistry();
    final t1 = r.makeToken();
    final t2 = r.makeToken();
    final t3 = r.makeToken();
    r.replace({'010C'}, t1);
    r.replace({'010D'}, t2);
    r.replace({'0105'}, t3);
    expect(r.interested, containsAll({'010C', '010D', '0105'}));
  });
  test('testRegistryClearMiddleTokenKeepsOthers', () async {
    final r = PidInterestRegistry();
    final t1 = r.makeToken();
    final t2 = r.makeToken();
    final t3 = r.makeToken();
    r.replace({'010C'}, t1);
    r.replace({'010D'}, t2);
    r.replace({'0105'}, t3);
    await r.clear(t2);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(r.interested.contains('010D'), isFalse);
    expect(r.interested.contains('010C'), isTrue);
    expect(r.interested.contains('0105'), isTrue);
  });
  test('testCopywithWithoutArgsPreservesEnabled', () {
    final a = ObdiiPid(id: 'x', enabled: true, label: 'L', name: 'N', pidCommand: '010C');
    expect(a.copyWith().enabled, isTrue);
  });
  test('testHashcodeEqualsForSameId', () {
    final a = ObdiiPid(id: 'same', label: 'L1', name: 'N1', pidCommand: '010C');
    final b = ObdiiPid(id: 'same', label: 'L2', name: 'N2', pidCommand: '010D');
    expect(a.hashCode, b.hashCode);
  });
  test('testHashcodeDiffersForDifferentIds', () {
    final a = ObdiiPid(id: 'a', label: 'L1', name: 'N1', pidCommand: '010C');
    final b = ObdiiPid(id: 'b', label: 'L1', name: 'N1', pidCommand: '010C');
    expect(a.hashCode == b.hashCode, isFalse);
  });
}
