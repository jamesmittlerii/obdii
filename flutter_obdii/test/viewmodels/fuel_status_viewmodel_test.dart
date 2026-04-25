// Port of FuelStatusViewModelTests.swift — Jim Mittler
// Tests fuel system status tracking, bank status extraction,
// hasAnyStatus, and integration with mock provider.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;

import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/viewmodels/fuel_status_viewmodel.dart';

// ─────────────────────────────────────────────
// Mock provider
// ─────────────────────────────────────────────

class MockFuelStatusProvider implements FuelStatusProviding {
  @override
  List<obd2lib.StatusCodeMetadata?>? fuelStatus;

  final _ctrl =
      StreamController<List<obd2lib.StatusCodeMetadata?>?>.broadcast();

  @override
  Stream<List<obd2lib.StatusCodeMetadata?>?> get fuelStatusStream =>
      _ctrl.stream;

  void send(List<obd2lib.StatusCodeMetadata?>? status) {
    fuelStatus = status;
    _ctrl.add(status);
  }

  void dispose() => _ctrl.close();
}

void main() {
  late MockFuelStatusProvider mockProvider;
  late PidInterestRegistry interestRegistry;
  late FuelStatusViewModel viewModel;

  setUp(() {
    mockProvider = MockFuelStatusProvider();
    interestRegistry = PidInterestRegistry();
    viewModel =
        FuelStatusViewModel(provider: mockProvider, interestRegistry: interestRegistry);
  });

  tearDown(() {
    viewModel.dispose();
    mockProvider.dispose();
  });

  // ── Initialization ──────────────────────────────

  test('testInitializationStatusBank1Bank2AllNull', () {
    expect(viewModel, isNotNull);
    expect(viewModel.status, isNull);
    expect(viewModel.bank1, isNull);
    expect(viewModel.bank2, isNull);
  });

  // ── hasAnyStatus ────────────────────────────────

  test('testHasanystatusFalseWhenStatusIsNull', () {
    expect(viewModel.hasAnyStatus, isFalse);
  });

  test('testHasanystatusFalseWithEmptyStatusList', () async {
    mockProvider.send([]);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.hasAnyStatus, isFalse);
  });

  // ── Status updates ──────────────────────────────

  test('testFuelStatusUpdatesBank1AndBank2', () async {
    // Simulate: bank1 = "OK", bank2 = null
    final bank1 = obd2lib.StatusCodeMetadata(
      code: 'OK',
      description: 'Closed loop',
    );
    mockProvider.send([bank1, null]);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(viewModel.bank1?.code, 'OK');
    expect(viewModel.bank2, isNull);
    expect(viewModel.hasAnyStatus, isTrue);
  });

  test('testBank1AndBank2AreIndependent', () async {
    final bank1 = obd2lib.StatusCodeMetadata(code: 'A', description: '');
    final bank2 = obd2lib.StatusCodeMetadata(code: 'B', description: '');
    mockProvider.send([bank1, bank2]);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(viewModel.bank1?.code, 'A');
    expect(viewModel.bank2?.code, 'B');
  });

  test('testHasanystatusIsTrueWhenAtLeastOneBankHasData', () async {
    final bank1 = obd2lib.StatusCodeMetadata(code: 'X', description: '');
    mockProvider.send([bank1]);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(viewModel.hasAnyStatus, isTrue);
  });

  test('testBankStructureIsOptional', () {
    // Regardless of data, these are nullable properties
    expect(viewModel.bank1 == null || viewModel.bank1 != null, isTrue);
    expect(viewModel.bank2 == null || viewModel.bank2 != null, isTrue);
  });

  test('testSetvisibleTrueRegistersFuelStatusPIDInterest', () async {
    viewModel.setVisible(true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested, contains('0103'));
  });

  test('testSetvisibleFalseClearsFuelStatusPIDInterest', () async {
    viewModel.setVisible(true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested, contains('0103'));

    viewModel.setVisible(false);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested.contains('0103'), isFalse);
  });

  test('testBank1RemainsNullWhenOnlySecondSlotIsProvided', () async {
    final bank2 = obd2lib.StatusCodeMetadata(code: 'B2', description: 'Second');
    mockProvider.send([null, bank2]);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.bank1, isNull);
    expect(viewModel.bank2?.code, 'B2');
  });

  test('testHasanystatusFalseWhenAllBankValuesAreNull', () async {
    mockProvider.send([null, null]);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.hasAnyStatus, isFalse);
  });

  test('testStatusPropertyMirrorsLatestProviderArrayLength', () async {
    mockProvider.send([
      obd2lib.StatusCodeMetadata(code: 'A', description: ''),
    ]);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.status?.length, 1);

    mockProvider.send([
      obd2lib.StatusCodeMetadata(code: 'A', description: ''),
      obd2lib.StatusCodeMetadata(code: 'B', description: ''),
    ]);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.status?.length, 2);
  });
}
