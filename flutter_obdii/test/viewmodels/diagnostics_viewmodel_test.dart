// Port of DiagnosticsViewModelTests.swift — Jim Mittler
// Tests DTC grouping by severity, section construction,
// empty state handling, and mock provider integration.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;

import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/viewmodels/diagnostics_viewmodel.dart';

// ─────────────────────────────────────────────
// Mock provider
// ─────────────────────────────────────────────

class MockDiagnosticsProvider implements DiagnosticsProviding {
  @override
  List<obd2lib.TroubleCodeMetadata>? troubleCodes;

  final _ctrl = StreamController<List<obd2lib.TroubleCodeMetadata>?>.broadcast();

  @override
  Stream<List<obd2lib.TroubleCodeMetadata>?> get diagnosticsStream => _ctrl.stream;

  void send(List<obd2lib.TroubleCodeMetadata>? codes) {
    troubleCodes = codes;
    _ctrl.add(codes);
  }

  void dispose() => _ctrl.close();
}

// ─────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────

void main() {
  late MockDiagnosticsProvider mockProvider;
  late PidInterestRegistry interestRegistry;
  late DiagnosticsViewModel viewModel;

  setUp(() {
    mockProvider = MockDiagnosticsProvider();
    interestRegistry = PidInterestRegistry();
    viewModel = DiagnosticsViewModel(
      provider: mockProvider,
      interestRegistry: interestRegistry,
    );
  });

  tearDown(() {
    viewModel.dispose();
    mockProvider.dispose();
  });

  // ── Initialization ──────────────────────────────

  test('testInitializationCodesIsNullSectionsEmpty', () {
    expect(viewModel, isNotNull);
    expect(viewModel.codes, isNull);
    expect(viewModel.sections, isEmpty);
  });

  // ── Null / waiting state ────────────────────────

  test('testNilCodesStateSectionsAreEmpty', () {
    expect(viewModel.codes, isNull);
    expect(viewModel.sections, isEmpty);
  });

  test('testSectionsInitiallyEmpty', () {
    expect(viewModel.sections.length, 0);
  });

  // ── Section equality ────────────────────────────

  test('testDtcsectionEqualitySameItemsEquals', () {
    final code1 = _makeDtc('P0001', 'High');
    final s1 = DtcSection(title: 'High', severity: 'High', items: [code1]);
    final s2 = DtcSection(title: 'High', severity: 'High', items: [code1]);
    expect(s1, equals(s2));
  });

  test('testDtcsectionEqualityDifferentItemsNotEqual', () {
    final code1 = _makeDtc('P0001', 'High');
    final code2 = _makeDtc('P0002', 'High');
    final s1 = DtcSection(title: 'High', severity: 'High', items: [code1]);
    final s2 = DtcSection(title: 'High', severity: 'High', items: [code2]);
    expect(s1, isNot(equals(s2)));
  });

  // ── Sections from provider ──────────────────────

  test('testSectionsGroupedBySeverityAfterUpdate', () async {
    mockProvider.send([
      _makeDtc('P0001', 'Critical'),
      _makeDtc('P0002', 'High'),
      _makeDtc('P0003', 'Critical'),
    ]);

    await Future.delayed(const Duration(milliseconds: 50));

    expect(viewModel.sections.any((s) => s.severity == 'Critical'), isTrue);
    expect(viewModel.sections.any((s) => s.severity == 'High'), isTrue);
    expect(
      viewModel.sections.firstWhere((s) => s.severity == 'Critical').items.length,
      2,
    );
  });

  test('testSectionsOrderedCriticalHighModerateLow', () async {
    mockProvider.send([
      _makeDtc('P0001', 'Low'),
      _makeDtc('P0002', 'High'),
      _makeDtc('P0003', 'Moderate'),
      _makeDtc('P0004', 'Critical'),
    ]);

    await Future.delayed(const Duration(milliseconds: 50));

    final order = viewModel.sections.map((s) => s.severity).toList();
    expect(order, ['Critical', 'High', 'Moderate', 'Low']);
  });

  test('testEmptyCodesListProducesNoSections', () async {
    mockProvider.send([]);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.sections, isEmpty);
  });

  test('testSetvisibleTrueRegistersDTCPIDInterest', () async {
    viewModel.setVisible(true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested, contains('03'));
  });

  test('testSetvisibleFalseClearsDTCPIDInterest', () async {
    viewModel.setVisible(true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested, contains('03'));

    viewModel.setVisible(false);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested.contains('03'), isFalse);
  });

  test('testUnknownSeverityEntriesAreExcludedFromOrderedSections', () async {
    mockProvider.send([
      _makeDtc('P1111', 'Unknown'),
      _makeDtc('P2222', 'Low'),
    ]);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.sections.any((s) => s.severity == 'Unknown'), isFalse);
    expect(viewModel.sections.any((s) => s.severity == 'Low'), isTrue);
  });

  test('testMultipleEntriesInSameSeverityPreserveCount', () async {
    mockProvider.send([
      _makeDtc('P1000', 'High'),
      _makeDtc('P1001', 'High'),
      _makeDtc('P1002', 'High'),
    ]);
    await Future.delayed(const Duration(milliseconds: 50));
    final high = viewModel.sections.firstWhere((s) => s.severity == 'High');
    expect(high.items.length, 3);
  });

  test('testCodesPropertyReflectsLatestProviderPayload', () async {
    final first = [_makeDtc('P0001', 'Critical')];
    final second = [_makeDtc('P0002', 'Low')];
    mockProvider.send(first);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.codes?.first.code, 'P0001');

    mockProvider.send(second);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.codes?.first.code, 'P0002');
  });
}

obd2lib.TroubleCodeMetadata _makeDtc(String code, String severity) {
  return obd2lib.TroubleCodeMetadata(
    code: code,
    title: 'Test DTC',
    description: 'Test description',
    severity: severity,
    causes: ['Test cause'],
    remedies: ['Test remedy'],
  );
}
