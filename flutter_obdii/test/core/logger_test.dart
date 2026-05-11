import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_obdii/core/logger.dart';

void main() {
  setUp(() {
    ObdLogger.instance.mutesConsole = true;
  });

  test('LogEntry serializes category label and fields', () {
    final timestamp = DateTime.utc(2026, 5, 8, 12, 30);
    final entry = LogEntry(
      timestamp: timestamp,
      category: LogCategory.communication,
      level: 'info',
      message: 'adapter responded',
    );

    expect(entry.toJson(), {
      'timestamp': timestamp.toIso8601String(),
      'category': 'Communication',
      'level': 'info',
      'message': 'adapter responded',
    });
  });

  test('global helpers append entries at their expected levels', () {
    final before = ObdLogger.instance.getHistory().length;

    obdInfo('info helper', category: LogCategory.app);
    obdDebug('debug helper', category: LogCategory.service);
    obdWarning('warning helper', category: LogCategory.ui);
    obdError('error helper', category: LogCategory.communication);

    final added = ObdLogger.instance.getHistory().skip(before).toList();
    expect(added.map((entry) => entry.level), [
      'info',
      'debug',
      'warning',
      'error',
    ]);
    expect(added.map((entry) => entry.category), [
      LogCategory.app,
      LogCategory.service,
      LogCategory.ui,
      LogCategory.communication,
    ]);
  });

  test('getHistory can filter recent entries', () {
    final message = 'recent-${DateTime.now().microsecondsSinceEpoch}';

    ObdLogger.instance.log(message, category: LogCategory.app, level: 'info');

    final recent = ObdLogger.instance.getHistory(
      since: const Duration(minutes: 1),
    );
    expect(recent.any((entry) => entry.message == message), isTrue);
  });

  test('history is capped at the most recent entries', () {
    final prefix = 'cap-${DateTime.now().microsecondsSinceEpoch}';

    for (var i = 0; i < 1005; i++) {
      ObdLogger.instance.log(
        '$prefix-$i',
        category: LogCategory.service,
        level: 'info',
      );
    }

    final history = ObdLogger.instance.getHistory();
    expect(history.length, lessThanOrEqualTo(1000));
    expect(history.any((entry) => entry.message == '$prefix-0'), isFalse);
    expect(history.any((entry) => entry.message == '$prefix-1004'), isTrue);
  });
}
