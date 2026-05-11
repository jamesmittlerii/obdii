// Port of PIDInterestRegistryTests.swift — Jim Mittler
// Unit tests for PidInterestRegistry.
// Tests demand-driven polling token management, PID interest registration,
// replacement, clearing, and interested PIDs union computation.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_obdii/core/pid_interest_registry.dart';

void main() {
  // ─────────────────────────────────────────────────
  // Shared registry + token cleanup — mirrors Swift setUp/tearDown
  // ─────────────────────────────────────────────────

  // We use a fresh PidInterestRegistry per test group (not the singleton)
  // to avoid cross-test contamination.
  late PidInterestRegistry registry;
  final List<String> testTokens = [];

  setUp(() {
    registry = PidInterestRegistry(); // fresh instance for test isolation
    testTokens.clear();
  });

  tearDown(() {
    for (final token in testTokens) {
      registry.clear(token);
    }
    testTokens.clear();
  });

  // ─────────────────────────────────────────────────
  // singleton
  // ─────────────────────────────────────────────────

  test('testSingletonInstanceExists', () {
    expect(PidInterestRegistry.instance, isNotNull);
  });

  // ─────────────────────────────────────────────────
  // makeToken
  // ─────────────────────────────────────────────────

  test('testEachTokenIsUnique', () {
    final t1 = registry.makeToken()..let((t) => testTokens.add(t));
    final t2 = registry.makeToken()..let((t) => testTokens.add(t));
    expect(t1, isNot(equals(t2)));
  });

  // ─────────────────────────────────────────────────
  // replace
  // ─────────────────────────────────────────────────

  group('replace', () {
    test('testPidsAreRegisteredAsInterested', () {
      final token = registry.makeToken();
      testTokens.add(token);
      registry.replace({'010C', '010D'}, token);

      expect(registry.interested.isEmpty, isFalse);
      expect(registry.interested.contains('010C'), isTrue);
      expect(registry.interested.contains('010D'), isTrue);
    });

    test('testOverwritesPreviousPIDsForSameToken', () {
      final token = registry.makeToken();
      testTokens.add(token);

      registry.replace({'010C'}, token);
      expect(registry.interested.contains('010C'), isTrue);

      registry.replace({'010D'}, token);
      expect(registry.interested.contains('010C'), isFalse,
          reason: 'old PID should be removed');
      expect(registry.interested.contains('010D'), isTrue,
          reason: 'new PID should be added');
    });

    test('testReplaceWithEmptySetClearsTokenPIDs', () {
      final token = registry.makeToken();
      testTokens.add(token);

      registry.replace({'010C'}, token);
      expect(registry.interested.contains('010C'), isTrue);

      registry.replace({}, token);
      expect(registry.interested.contains('010C'), isFalse);
    });
  });

  // ─────────────────────────────────────────────────
  // multiple tokens
  // ─────────────────────────────────────────────────

  group('multiple tokens', () {
    test('testTwoTokensCanRegisterSamePID', () {
      final t1 = registry.makeToken();
      testTokens.add(t1);
      final t2 = registry.makeToken();
      testTokens.add(t2);

      registry.replace({'010C'}, t1);
      registry.replace({'010C'}, t2);

      expect(registry.interested.contains('010C'), isTrue);
    });

    test('testUnionOfDifferentTokensPIDs', () {
      final t1 = registry.makeToken();
      testTokens.add(t1);
      final t2 = registry.makeToken();
      testTokens.add(t2);

      registry.replace({'010C'}, t1);
      registry.replace({'010D'}, t2);

      expect(registry.interested.contains('010C'), isTrue);
      expect(registry.interested.contains('010D'), isTrue);
      expect(registry.interested.length, 2);
    });
  });

  // ─────────────────────────────────────────────────
  // clear
  // ─────────────────────────────────────────────────

  group('clear', () {
    test('testClearsTokenPIDsImmediately', () {
      final token = registry.makeToken();
      testTokens.add(token);

      registry.replace({'010C'}, token);
      expect(registry.interested.contains('010C'), isTrue);

      registry.clear(token);

      expect(registry.interested.contains('010C'), isFalse);
    });

    test('testClearTokenDoesNotAffectOtherTokens', () {
      final t1 = registry.makeToken();
      testTokens.add(t1);
      final t2 = registry.makeToken();
      testTokens.add(t2);

      registry.replace({'010C'}, t1);
      registry.replace({'010D'}, t2);

      registry.clear(t1);

      expect(registry.interested.contains('010C'), isFalse,
          reason: "token1's PID should be cleared");
      expect(registry.interested.contains('010D'), isTrue,
          reason: "token2's PID should remain");
    });

    test('testSharedPIDStaysWhenOnlyOneTokenCleared', () {
      final t1 = registry.makeToken();
      testTokens.add(t1);
      final t2 = registry.makeToken();
      testTokens.add(t2);

      registry.replace({'010C'}, t1);
      registry.replace({'010C'}, t2);

      registry.clear(t1);

      expect(registry.interested.contains('010C'), isTrue,
          reason: 'shared PID should remain while other token holds it');
    });

    test('testReplaceAfterClearKeepsNewPids', () {
      final token = registry.makeToken();
      testTokens.add(token);

      registry.replace({'010C'}, token);
      registry.clear(token);
      registry.replace({'010D'}, token);

      expect(registry.interested.contains('010C'), isFalse);
      expect(registry.interested.contains('010D'), isTrue);
    });
  });

  // ─────────────────────────────────────────────────
  // union / count
  // ─────────────────────────────────────────────────

  test('testInterestedIsUnionOfAllTokens', () {
    final t1 = registry.makeToken();
    testTokens.add(t1);
    final t2 = registry.makeToken();
    testTokens.add(t2);

    registry.replace({'010C', '0105'}, t1);
    registry.replace({'010D', '010C'}, t2);

    expect(registry.interested.length, 3);
    expect(registry.interested, containsAll(['010C', '010D', '0105']));
  });

  // ─────────────────────────────────────────────────
  // stream
  // ─────────────────────────────────────────────────

  test('testInterestedstreamEmitsOnReplace', () async {
    int changeCount = 0;
    final token = registry.makeToken();
    testTokens.add(token);

    final sub = registry.interestedStream.listen((_) => changeCount++);

    registry.replace({'010C'}, token);

    await Future.delayed(const Duration(milliseconds: 50));
    sub.cancel();

    expect(changeCount, greaterThan(1));
  });
}

// Helper extension to avoid var declaration in chained call
extension _Let<T> on T {
  T let(void Function(T) block) {
    block(this);
    return this;
  }
}
