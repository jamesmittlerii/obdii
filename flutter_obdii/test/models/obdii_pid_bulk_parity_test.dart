import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_obdii/core/obdiipid.dart';

ObdiiPid _pidFromCommandName(String command) {
  return ObdiiPid.fromJson({
    'id': 'x_$command',
    'label': 'Test',
    'name': 'Test',
    'pid': {'type': 'mode1', 'command': command},
    'units': 'km/h',
  });
}

ObdiiPid _pidFromGmCommand(String command) {
  return ObdiiPid.fromJson({
    'id': 'gm_$command',
    'label': 'Test',
    'name': 'Test',
    'pid': {'type': 'GMmode22', 'command': command},
    'units': 'kPa',
  });
}

ObdiiPid _pidWithRanges({
  required ValueRange typical,
  ValueRange? warning,
  ValueRange? danger,
  String units = '°C',
}) {
  return ObdiiPid(
    id: 'ranges',
    enabled: true,
    label: 'L',
    name: 'N',
    pidCommand: '0105',
    units: units,
    typicalRange: typical,
    warningRange: warning,
    dangerRange: danger,
  );
}

void main() {
  // command mapping parity
  test('testMapsRpm', () => expect(_pidFromCommandName('rpm').pidCommand, '010C'));
  test('testMapsSpeed', () => expect(_pidFromCommandName('speed').pidCommand, '010D'));
  test('testMapsCoolantTemp', () => expect(_pidFromCommandName('coolantTemp').pidCommand, '0105'));
  test('testMapsIntakeTemp', () => expect(_pidFromCommandName('intakeTemp').pidCommand, '010F'));
  test('testMapsStatus', () => expect(_pidFromCommandName('status').pidCommand, '0101'));
  test('testMapsFuelStatus', () => expect(_pidFromCommandName('fuelStatus').pidCommand, '0103'));
  test('testMapsGETDTC', () => expect(_pidFromCommandName('GET_DTC').pidCommand, '03'));
  test('testMapsControlModuleVoltage', () => expect(_pidFromCommandName('controlModuleVoltage').pidCommand, '0142'));
  test('testMapsCommandedEquivRatio', () => expect(_pidFromCommandName('commandedEquivRatio').pidCommand, '0144'));
  test('testMapsEngineOilTemp', () => expect(_pidFromCommandName('engineOilTemp').pidCommand, '015C'));
  test('testMapsFuelPressure', () => expect(_pidFromCommandName('fuelPressure').pidCommand, '010A'));
  test('testMapsCatalystTempB1S1', () => expect(_pidFromCommandName('catalystTempB1S1').pidCommand, '013C'));
  test('testMapsCatalystTempB2S1', () => expect(_pidFromCommandName('catalystTempB2S1').pidCommand, '013D'));
  test('testMapsCatalystTempB1S2', () => expect(_pidFromCommandName('catalystTempB1S2').pidCommand, '013E'));
  test('testMapsCatalystTempB2S2', () => expect(_pidFromCommandName('catalystTempB2S2').pidCommand, '013F'));
  test('testMapsThrottlePos', () => expect(_pidFromCommandName('throttlePos').pidCommand, '0111'));
  test('testMapsThrottleActuator', () => expect(_pidFromCommandName('throttleActuator').pidCommand, '014C'));
  test('testMapsThrottlePosB', () => expect(_pidFromCommandName('throttlePosB').pidCommand, '0147'));
  test('testMapsThrottlePosC', () => expect(_pidFromCommandName('throttlePosC').pidCommand, '0148'));
  test('testMapsThrottlePosD', () => expect(_pidFromCommandName('throttlePosD').pidCommand, '0149'));
  test('testMapsThrottlePosE', () => expect(_pidFromCommandName('throttlePosE').pidCommand, '014A'));
  test('testMapsThrottlePosF', () => expect(_pidFromCommandName('throttlePosF').pidCommand, '014B'));
  test('testMapsTimingAdvance', () => expect(_pidFromCommandName('timingAdvance').pidCommand, '010E'));
  test('testMapsAmbientAirTemp', () => expect(_pidFromCommandName('ambientAirTemp').pidCommand, '0146'));
  test('testMapsRelativeThrottlePos', () => expect(_pidFromCommandName('relativeThrottlePos').pidCommand, '0145'));
  test('testMapsEngineLoad', () => expect(_pidFromCommandName('engineLoad').pidCommand, '0104'));
  test('testMapsAbsoluteLoad', () => expect(_pidFromCommandName('absoluteLoad').pidCommand, '0143'));
  test('testMapsFuelLevel', () => expect(_pidFromCommandName('fuelLevel').pidCommand, '012F'));
  test('testMapsBarometricPressure', () => expect(_pidFromCommandName('barometricPressure').pidCommand, '0133'));
  test('testMapsIntakePressure', () => expect(_pidFromCommandName('intakePressure').pidCommand, '010B'));
  test('testMapsFuelRailPressureAbs', () => expect(_pidFromCommandName('fuelRailPressureAbs').pidCommand, '0159'));
  test('testMapsFuelRailPressureDirect', () => expect(_pidFromCommandName('fuelRailPressureDirect').pidCommand, '0123'));
  test('testMapsFuelRailPressureVac', () => expect(_pidFromCommandName('fuelRailPressureVac').pidCommand, '0122'));
  test('testMapsMaf', () => expect(_pidFromCommandName('maf').pidCommand, '0110'));
  test('testMapsFuelRate', () => expect(_pidFromCommandName('fuelRate').pidCommand, '015E'));
  test('testMapsRelativeAccelPos', () => expect(_pidFromCommandName('relativeAccelPos').pidCommand, '015A'));
  test('testMapsShortFuelTrim1', () => expect(_pidFromCommandName('shortFuelTrim1').pidCommand, '0106'));
  test('testMapsLongFuelTrim1', () => expect(_pidFromCommandName('longFuelTrim1').pidCommand, '0107'));
  test('testMapsShortFuelTrim2', () => expect(_pidFromCommandName('shortFuelTrim2').pidCommand, '0108'));
  test('testMapsLongFuelTrim2', () => expect(_pidFromCommandName('longFuelTrim2').pidCommand, '0109'));
  test('testMapsO2Bank1Sensor1', () => expect(_pidFromCommandName('O2Bank1Sensor1').pidCommand, '0114'));
  test('testMapsO2Bank1Sensor2', () => expect(_pidFromCommandName('O2Bank1Sensor2').pidCommand, '0115'));
  test('testMapsO2Bank1Sensor3', () => expect(_pidFromCommandName('O2Bank1Sensor3').pidCommand, '0116'));
  test('testMapsO2Bank1Sensor4', () => expect(_pidFromCommandName('O2Bank1Sensor4').pidCommand, '0117'));
  test('testMapsO2Bank2Sensor1', () => expect(_pidFromCommandName('O2Bank2Sensor1').pidCommand, '0118'));
  test('testMapsO2Bank2Sensor2', () => expect(_pidFromCommandName('O2Bank2Sensor2').pidCommand, '0119'));
  test('testMapsO2Bank2Sensor3', () => expect(_pidFromCommandName('O2Bank2Sensor3').pidCommand, '011A'));
  test('testMapsO2Sensor', () => expect(_pidFromCommandName('O2Sensor').pidCommand, '0113'));
  test('testMapsFuelType', () => expect(_pidFromCommandName('fuelType').pidCommand, '0151'));
  test('testMapsObdcompliance', () => expect(_pidFromCommandName('obdcompliance').pidCommand, '011C'));
  test('testMapsStatusDriveCycle', () => expect(_pidFromCommandName('statusDriveCycle').pidCommand, '0141'));
  test('testMapsFreezeDTC', () => expect(_pidFromCommandName('freezeDTC').pidCommand, '0202'));
  test('testMapsAirStatus', () => expect(_pidFromCommandName('airStatus').pidCommand, '0112'));
  test('testMapsEvapVaporPressure', () => expect(_pidFromCommandName('evapVaporPressure').pidCommand, '0132'));
  test('testMapsEvapVaporPressureAlt', () => expect(_pidFromCommandName('evapVaporPressureAlt').pidCommand, '0154'));
  test('testMapsEvapVaporPressureAbs', () => expect(_pidFromCommandName('evapVaporPressureAbs').pidCommand, '0153'));
  test('testMapsEvaporativePurge', () => expect(_pidFromCommandName('evaporativePurge').pidCommand, '012E'));
  test('testMapsCommandedEGR', () => expect(_pidFromCommandName('commandedEGR').pidCommand, '012C'));
  test('testMapsEGRError', () => expect(_pidFromCommandName('EGRError').pidCommand, '012D'));
  test('testMapsWarmUpsSinceDTCCleared', () => expect(_pidFromCommandName('warmUpsSinceDTCCleared').pidCommand, '0130'));
  test('testMapsDistanceSinceDTCCleared', () => expect(_pidFromCommandName('distanceSinceDTCCleared').pidCommand, '0131'));
  test('testMapsDistanceWMIL', () => expect(_pidFromCommandName('distanceWMIL').pidCommand, '0121'));
  test('testMapsRunTime', () => expect(_pidFromCommandName('runTime').pidCommand, '011F'));
  test('testMapsRunTimeMIL', () => expect(_pidFromCommandName('runTimeMIL').pidCommand, '014D'));
  test('testMapsTimeSinceDTCCleared', () => expect(_pidFromCommandName('timeSinceDTCCleared').pidCommand, '014E'));
  test('testMapsHybridBatteryLife', () => expect(_pidFromCommandName('hybridBatteryLife').pidCommand, '015B'));
  test('testMapsFuelInjectionTiming', () => expect(_pidFromCommandName('fuelInjectionTiming').pidCommand, '015D'));
  test('testMapsMaxMAF', () => expect(_pidFromCommandName('maxMAF').pidCommand, '0150'));
  test('testMapsEthanoPercent', () => expect(_pidFromCommandName('ethanoPercent').pidCommand, '0152'));
  test('testMapsO2Sensor1WRVolatage', () => expect(_pidFromCommandName('O2Sensor1WRVolatage').pidCommand, '0124'));
  test('testMapsO2Sensor2WRVolatage', () => expect(_pidFromCommandName('O2Sensor2WRVolatage').pidCommand, '0125'));
  test('testMapsO2Sensor3WRVolatage', () => expect(_pidFromCommandName('O2Sensor3WRVolatage').pidCommand, '0126'));
  test('testMapsO2Sensor4WRVolatage', () => expect(_pidFromCommandName('O2Sensor4WRVolatage').pidCommand, '0127'));
  test('testMapsO2Sensor5WRVolatage', () => expect(_pidFromCommandName('O2Sensor5WRVolatage').pidCommand, '0128'));
  test('testMapsO2Sensor6WRVolatage', () => expect(_pidFromCommandName('O2Sensor6WRVolatage').pidCommand, '0129'));
  test('testMapsO2Sensor7WRVolatage', () => expect(_pidFromCommandName('O2Sensor7WRVolatage').pidCommand, '012A'));
  test('testMapsO2Sensor8WRVolatage', () => expect(_pidFromCommandName('O2Sensor8WRVolatage').pidCommand, '012B'));
  test('testMapsO2Sensor1WRCurrent', () => expect(_pidFromCommandName('O2Sensor1WRCurrent').pidCommand, '0134'));
  test('testMapsO2Sensor2WRCurrent', () => expect(_pidFromCommandName('O2Sensor2WRCurrent').pidCommand, '0135'));
  test('testMapsO2Sensor3WRCurrent', () => expect(_pidFromCommandName('O2Sensor3WRCurrent').pidCommand, '0136'));
  test('testMapsO2Sensor4WRCurrent', () => expect(_pidFromCommandName('O2Sensor4WRCurrent').pidCommand, '0137'));
  test('testMapsO2Sensor5WRCurrent', () => expect(_pidFromCommandName('O2Sensor5WRCurrent').pidCommand, '0138'));
  test('testMapsO2Sensor6WRCurrent', () => expect(_pidFromCommandName('O2Sensor6WRCurrent').pidCommand, '0139'));
  test('testMapsO2Sensor7WRCurrent', () => expect(_pidFromCommandName('O2Sensor7WRCurrent').pidCommand, '013A'));
  test('testMapsO2Sensor8WRCurrent', () => expect(_pidFromCommandName('O2Sensor8WRCurrent').pidCommand, '013B'));
  test('testMapsGmEngineOilTemp', () => expect(_pidFromGmCommand('engineOilTemp').pidCommand, '221154'));
  test('testMapsGmEngineOilPressure', () => expect(_pidFromGmCommand('engineOilPressure').pidCommand, '221470'));
  test('testMapsGmACHighPressure', () => expect(_pidFromGmCommand('ACHighPressure').pidCommand, '221144'));
  test('testMapsGmTransFluidTemp', () => expect(_pidFromGmCommand('transFluidTemp').pidCommand, '221940'));

  // ValueRange behavior
  test('testValuerangeContainsLowerBound', () => expect(const ValueRange(min: 0, max: 10).contains(0), isTrue));
  test('testValuerangeContainsUpperBound', () => expect(const ValueRange(min: 0, max: 10).contains(10), isTrue));
  test('testValuerangeExcludesBelow', () => expect(const ValueRange(min: 0, max: 10).contains(-1), isFalse));
  test('testValuerangeExcludesAbove', () => expect(const ValueRange(min: 0, max: 10).contains(11), isFalse));
  test('testValuerangeClampsBelow', () => expect(const ValueRange(min: 0, max: 10).clampedValue(-5), 0));
  test('testValuerangeClampsAbove', () => expect(const ValueRange(min: 0, max: 10).clampedValue(20), 10));
  test('testValuerangeKeepsMid', () => expect(const ValueRange(min: 0, max: 10).clampedValue(7), 7));
  test('testValuerangeOverlapTrue', () => expect(const ValueRange(min: 0, max: 10).overlaps(const ValueRange(min: 5, max: 20)), isTrue));
  test('testValuerangeOverlapFalse', () => expect(const ValueRange(min: 0, max: 10).overlaps(const ValueRange(min: 11, max: 20)), isFalse));
  test('testValuerangeNormalizedMin', () => expect(const ValueRange(min: 0, max: 10).normalizedPosition(0), 0));
  test('testValuerangeNormalizedMax', () => expect(const ValueRange(min: 0, max: 10).normalizedPosition(10), 1));
  test('testValuerangeNormalizedMid', () => expect(const ValueRange(min: 0, max: 10).normalizedPosition(5), 0.5));
  test('testValuerangeNormalizedFlatReturns0', () => expect(const ValueRange(min: 1, max: 1).normalizedPosition(1), 0));
  test('testValuerangeConvertedCelsiusImperial', () => expect(const ValueRange(min: 0, max: 100).converted('°C', false), const ValueRange(min: 32, max: 212)));
  test('testValuerangeConvertedKphImperial', () => expect(const ValueRange(min: 0, max: 100).converted('km/h', false).max, closeTo(62.1371, 0.001)));
  test('testValuerangeConvertedUnknownUnchanged', () => expect(const ValueRange(min: 1, max: 2).converted('unknown', true), const ValueRange(min: 1, max: 2)));

  // formatting and units
  test('testUnitlabelMetricKmh', () => expect(_pidWithRanges(typical: const ValueRange(min: 0, max: 1), units: 'km/h').unitLabel(true), 'km/h'));
  test('testUnitlabelImperialKmh', () => expect(_pidWithRanges(typical: const ValueRange(min: 0, max: 1), units: 'km/h').unitLabel(false), 'mph'));
  test('testUnitlabelMetricCelsius', () => expect(_pidWithRanges(typical: const ValueRange(min: 0, max: 1), units: '°C').unitLabel(true), '°C'));
  test('testUnitlabelImperialCelsius', () => expect(_pidWithRanges(typical: const ValueRange(min: 0, max: 1), units: '°C').unitLabel(false), '°F'));
  test('testUnitlabelUnknownPassthrough', () => expect(_pidWithRanges(typical: const ValueRange(min: 0, max: 1), units: 'abc').unitLabel(true), 'abc'));
  test('testFormattedvalueIncludesUnits', () => expect(_pidWithRanges(typical: const ValueRange(min: 0, max: 1), units: 'km/h').formattedValue(10, true), '10 km/h'));
  test('testFormattedvalueOmitsUnitsWhenRequested', () => expect(_pidWithRanges(typical: const ValueRange(min: 0, max: 1), units: 'km/h').formattedValue(10, true, includeUnits: false), '10'));
  test('testDisplayrangeProducesLabel', () => expect(_pidWithRanges(typical: const ValueRange(min: 0, max: 100), units: 'km/h').displayRange(true), contains('km/h')));
  test('testDisplayrangeImperialUsesMph', () => expect(_pidWithRanges(typical: const ValueRange(min: 0, max: 100), units: 'km/h').displayRange(false), contains('mph')));
  test('testCombinedrangeUsesAllRangesMin', () {
    final pid = _pidWithRanges(
      typical: const ValueRange(min: 20, max: 80),
      warning: const ValueRange(min: 10, max: 90),
      danger: const ValueRange(min: 0, max: 100),
    );
    expect(pid.combinedRange().min, 0);
  });
  test('testCombinedrangeUsesAllRangesMax', () {
    final pid = _pidWithRanges(
      typical: const ValueRange(min: 20, max: 80),
      warning: const ValueRange(min: 10, max: 90),
      danger: const ValueRange(min: 0, max: 100),
    );
    expect(pid.combinedRange().max, 100);
  });
  test('testCombinedrangeFallbackDefaults', () {
    final pid = ObdiiPid(
      id: 'no_ranges',
      label: 'L',
      name: 'N',
      pidCommand: '010C',
      units: 'RPM',
    );
    expect(pid.combinedRange(), const ValueRange(min: 0, max: 1));
  });

  // color thresholds
  test('testColorDangerRed', () {
    final pid = _pidWithRanges(
      typical: const ValueRange(min: 0, max: 60),
      warning: const ValueRange(min: 61, max: 80),
      danger: const ValueRange(min: 81, max: 100),
      units: '%',
    );
    expect(pid.colorForValue(90, true), Colors.red);
  });
  test('testColorWarningOrange', () {
    final pid = _pidWithRanges(
      typical: const ValueRange(min: 0, max: 60),
      warning: const ValueRange(min: 61, max: 80),
      danger: const ValueRange(min: 81, max: 100),
      units: '%',
    );
    expect(pid.colorForValue(70, true), Colors.orange);
  });
  test('testColorTypicalGreen', () {
    final pid = _pidWithRanges(
      typical: const ValueRange(min: 0, max: 60),
      warning: const ValueRange(min: 61, max: 80),
      danger: const ValueRange(min: 81, max: 100),
      units: '%',
    );
    expect(pid.colorForValue(30, true), Colors.green);
  });
  test('testColorDefaultBlueGrey', () {
    final pid = _pidWithRanges(
      typical: const ValueRange(min: 10, max: 20),
      warning: const ValueRange(min: 30, max: 40),
      danger: const ValueRange(min: 50, max: 60),
      units: '%',
    );
    expect(pid.colorForValue(25, true), Colors.blueGrey);
  });
}
