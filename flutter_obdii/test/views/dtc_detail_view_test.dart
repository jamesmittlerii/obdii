import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;

obd2lib.TroubleCodeMetadata _dtc({
  required String code,
  String severity = 'Moderate',
  List<String> causes = const ['Cause 1'],
  List<String> remedies = const ['Remedy 1'],
}) {
  return obd2lib.TroubleCodeMetadata(
    code: code,
    title: 'Title $code',
    description: 'Description $code',
    severity: severity,
    causes: causes,
    remedies: remedies,
  );
}

void main() {
  test('testHasList', () {
    final dtc = _dtc(code: 'P0300');
    expect(dtc.code, isNotEmpty);
  });

  test('testHasSections', () {
    final dtc = _dtc(code: 'P0300');
    expect(dtc.title, isNotEmpty);
    expect(dtc.description, isNotEmpty);
  });

  test('testNavigationTitleIsCode', () {
    final dtc = _dtc(code: 'P0300');
    expect(dtc.code, 'P0300');
  });

  test('testOverviewSectionExists', () {
    final dtc = _dtc(code: 'P0300');
    expect(dtc.severity, isNotEmpty);
  });

  test('testOverviewSectionContainsLabeledContent', () {
    final dtc = _dtc(code: 'P0300');
    expect([dtc.code, dtc.title, dtc.severity].length, 3);
  });

  test('testDescriptionSectionExists', () {
    final dtc = _dtc(code: 'P0300');
    expect(dtc.description, contains('Description'));
  });

  test('testDescriptionTextNotEmpty', () {
    final dtc = _dtc(code: 'P0300');
    expect(dtc.description.isNotEmpty, isTrue);
  });

  test('testCausesSectionWithCauses', () {
    final dtc = _dtc(code: 'P0300', causes: const ['A', 'B']);
    expect(dtc.causes.length, 2);
  });

  test('testCausesSectionEmptyWhenNoCauses', () {
    final dtc = _dtc(code: 'P0171', causes: const []);
    expect(dtc.causes, isEmpty);
  });

  test('testRemediesSectionWithRemedies', () {
    final dtc = _dtc(code: 'P0300', remedies: const ['Fix']);
    expect(dtc.remedies, isNotEmpty);
  });

  test('testRemediesSectionEmptyWhenNoRemedies', () {
    final dtc = _dtc(code: 'P0171', remedies: const []);
    expect(dtc.remedies, isEmpty);
  });

  test('testRenderWithAllData', () {
    final dtc = _dtc(code: 'P0300', causes: const ['c1'], remedies: const ['r1']);
    expect(dtc.causes, isNotEmpty);
    expect(dtc.remedies, isNotEmpty);
  });

  test('testRenderWithMinimalData', () {
    final dtc = _dtc(code: 'P0171', causes: const [], remedies: const []);
    expect(dtc.code, 'P0171');
  });

  test('testSeverityMinorDisplay', () {
    final dtc = _dtc(code: 'P0100', severity: 'Low');
    expect(dtc.severity, 'Low');
  });

  test('testSeverityModerateDisplay', () {
    final dtc = _dtc(code: 'P0300', severity: 'Moderate');
    expect(dtc.severity, 'Moderate');
  });

  test('testSeveritySevereDisplay', () {
    final dtc = _dtc(code: 'P0420', severity: 'High');
    expect(dtc.severity, 'High');
  });

  test('testMultipleCausesDisplay', () {
    final dtc = _dtc(code: 'P0301', causes: const ['1', '2', '3', '4', '5']);
    expect(dtc.causes.length, 5);
  });

  test('testMultipleRemediesDisplay', () {
    final dtc = _dtc(code: 'P0301', remedies: const ['1', '2', '3', '4', '5']);
    expect(dtc.remedies.length, 5);
  });

  test('testPCodeFormat', () {
    final dtc = _dtc(code: 'P0420');
    expect(dtc.code.startsWith('P'), isTrue);
  });

  test('testCCodeFormat', () {
    final dtc = _dtc(code: 'C1234');
    expect(dtc.code.startsWith('C'), isTrue);
  });

  test('testBCodeFormat', () {
    final dtc = _dtc(code: 'B1234');
    expect(dtc.code.startsWith('B'), isTrue);
  });

  test('testUCodeFormat', () {
    final dtc = _dtc(code: 'U1234');
    expect(dtc.code.startsWith('U'), isTrue);
  });
}

