// Port of MILStatusViewModelTests.swift — Jim Mittler
// Tests MIL status tracking, readiness monitor sorting, headerText formatting,
// onChanged callback, and integration with mock MIL provider.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_obd2/flutter_obd2.dart' as obd2lib;

import 'package:flutter_obdii/core/obd_connection_manager.dart';
import 'package:flutter_obdii/core/pid_interest_registry.dart';
import 'package:flutter_obdii/viewmodels/mil_status_viewmodel.dart';

// ─────────────────────────────────────────────
// Mock provider
// ─────────────────────────────────────────────

class MockMilStatusProvider implements MilStatusProviding {
  @override
  obd2lib.Status? milStatus;

  final _ctrl = StreamController<obd2lib.Status?>.broadcast();

  @override
  Stream<obd2lib.Status?> get milStatusStream => _ctrl.stream;

  void send(obd2lib.Status? status) {
    milStatus = status;
    _ctrl.add(status);
  }

  void dispose() => _ctrl.close();
}

// Helper to build an obd2lib.Status with readiness monitors
obd2lib.Status makeStatus({
  required bool milOn,
  required int dtcCount,
  required List<obd2lib.ReadinessMonitor> monitors,
}) {
  return obd2lib.Status(milOn: milOn, dtcCount: dtcCount, monitors: monitors);
}

obd2lib.ReadinessMonitor makeMonitor(String name,
    {bool supported = true, bool ready = true}) {
  return obd2lib.ReadinessMonitor(name: name, supported: supported, ready: ready);
}

void main() {
  late MockMilStatusProvider mockProvider;
  late PidInterestRegistry interestRegistry;
  late MilStatusViewModel viewModel;

  setUp(() {
    mockProvider = MockMilStatusProvider();
    interestRegistry = PidInterestRegistry();
    viewModel =
        MilStatusViewModel(provider: mockProvider, interestRegistry: interestRegistry);
  });

  tearDown(() {
    viewModel.dispose();
    mockProvider.dispose();
  });

  // ── Initialization ──────────────────────────────

  test('testInitializationStatusNullHasStatusFalse', () {
    expect(viewModel, isNotNull);
    expect(viewModel.status, isNull);
    expect(viewModel.hasStatus, isFalse);
  });

  // ── hasStatus ───────────────────────────────────

  test('testHasstatusFalseWhenNil', () {
    expect(viewModel.status, isNull);
    expect(viewModel.hasStatus, isFalse);
  });

  // ── Status updates ──────────────────────────────

  test('testStatusUpdatesFromProvider', () async {
    final monitors = [
      makeMonitor('Misfire', ready: true),
      makeMonitor('Fuel System', ready: false),
    ];
    final status = makeStatus(milOn: true, dtcCount: 2, monitors: monitors);
    mockProvider.send(status);
    await Future.delayed(const Duration(milliseconds: 50));

    expect(viewModel.status, isNotNull);
    expect(viewModel.hasStatus, isTrue);
    expect(viewModel.headerText, 'MIL: On (2 DTCs)');
  });

  // ── sortedSupportedMonitors ─────────────────────

  test('testSortedsupportedmonitorsInitiallyEmpty', () {
    expect(viewModel.sortedSupportedMonitors, isEmpty);
  });

  test('testMonitorSortingNotReadyFirstThenReadyFilteredBySupported', () async {
    final monitors = [
      makeMonitor('B Monitor', supported: true, ready: true),
      makeMonitor('A Monitor', supported: true, ready: false),
      makeMonitor('C Monitor', supported: true, ready: false),
      makeMonitor('Z Unsupported', supported: false, ready: true),
    ];
    mockProvider.send(makeStatus(milOn: false, dtcCount: 0, monitors: monitors));
    await Future.delayed(const Duration(milliseconds: 50));

    final sorted = viewModel.sortedSupportedMonitors;

    // Z Unsupported must be excluded
    expect(sorted.any((m) => m.name == 'Z Unsupported'), isFalse);

    // Not-ready first (A, C), then ready (B)
    final names = sorted.map((m) => m.name).toList();
    expect(names, ['A Monitor', 'C Monitor', 'B Monitor']);
  });

  // ── headerText ──────────────────────────────────

  test('testHeadertextWhenNoStatus', () {
    expect(viewModel.headerText, 'No MIL Status');
  });

  test('testHeadertextFormattingOff0DTCs', () async {
    mockProvider.send(makeStatus(milOn: false, dtcCount: 0, monitors: []));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.headerText, 'MIL: Off (0 DTCs)');
  });

  test('testHeadertextFormattingOn1DTCSingular', () async {
    mockProvider.send(makeStatus(milOn: true, dtcCount: 1, monitors: []));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.headerText, 'MIL: On (1 DTC)');
  });

  test('testHeadertextFormattingOn3DTCs', () async {
    mockProvider.send(makeStatus(milOn: true, dtcCount: 3, monitors: []));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.headerText, 'MIL: On (3 DTCs)');
  });

  test('testHeadertextFormattingOff5DTCs', () async {
    mockProvider.send(makeStatus(milOn: false, dtcCount: 5, monitors: []));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.headerText, 'MIL: Off (5 DTCs)');
  });

  // ── Monitor structure ───────────────────────────

  test('testAllSupportedMonitorsHaveNonEmptyNames', () async {
    final monitors = [
      makeMonitor('Alpha', ready: true),
      makeMonitor('Beta', ready: false),
    ];
    mockProvider.send(makeStatus(milOn: true, dtcCount: 0, monitors: monitors));
    await Future.delayed(const Duration(milliseconds: 50));

    for (final m in viewModel.sortedSupportedMonitors) {
      expect(m.name.isNotEmpty, isTrue);
    }
  });

  // ── onChanged callback (mirrors Swift CarPlay hook test) ────

  test('testOnchangedCallbackFiresWhenStatusUpdates', () async {
    bool callbackFired = false;
    viewModel.onChanged = () => callbackFired = true;

    mockProvider.send(makeStatus(milOn: true, dtcCount: 0, monitors: []));
    await Future.delayed(const Duration(milliseconds: 50));

    expect(callbackFired, isTrue);
  });

  test('testSetvisibleTrueRegistersMILStatusPIDInterest', () async {
    viewModel.setVisible(true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested, contains('0101'));
  });

  test('testSetvisibleFalseClearsMILStatusPIDInterest', () async {
    viewModel.setVisible(true);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested, contains('0101'));

    viewModel.setVisible(false);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(interestRegistry.interested.contains('0101'), isFalse);
  });

  test('testSortedsupportedmonitorsExcludesUnsupportedEntries', () async {
    mockProvider.send(
      makeStatus(
        milOn: false,
        dtcCount: 0,
        monitors: [
          makeMonitor('Supported', supported: true, ready: true),
          makeMonitor('Unsupported', supported: false, ready: false),
        ],
      ),
    );
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.sortedSupportedMonitors.any((m) => m.name == 'Unsupported'), isFalse);
    expect(viewModel.sortedSupportedMonitors.any((m) => m.name == 'Supported'), isTrue);
  });

  test('testHeadertextRemainsStableWhenSameStatusResent', () async {
    final status = makeStatus(milOn: true, dtcCount: 1, monitors: []);
    mockProvider.send(status);
    await Future.delayed(const Duration(milliseconds: 50));
    final first = viewModel.headerText;

    mockProvider.send(status);
    await Future.delayed(const Duration(milliseconds: 50));
    final second = viewModel.headerText;
    expect(second, equals(first));
  });

  test('testHasstatusReturnsFalseAfterProviderSendsNull', () async {
    mockProvider.send(makeStatus(milOn: true, dtcCount: 2, monitors: []));
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.hasStatus, isTrue);

    mockProvider.send(null);
    await Future.delayed(const Duration(milliseconds: 50));
    expect(viewModel.hasStatus, isFalse);
  });
}
