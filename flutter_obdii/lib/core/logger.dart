import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

enum LogCategory {
  app('App'),
  service('Service'),
  communication('Communication'),
  ui('UI');

  final String label;
  const LogCategory(this.label);
}

class LogEntry {
  final DateTime timestamp;
  final LogCategory category;
  final String level;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.category,
    required this.level,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'category': category.label,
        'level': level,
        'message': message,
      };
}

class ObdLogger {
  static final ObdLogger instance = ObdLogger._();
  
  final List<LogEntry> _history = [];
  static const int _maxHistory = 1000;
  static final String _minLevelFromEnv =
      const String.fromEnvironment('LOG_LEVEL', defaultValue: 'debug');

  /// If true, logs won't be printed to the console (useful for tests).
  late bool mutesConsole;

  ObdLogger._() {
    bool isTest = false;
    try {
      isTest = Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      // Platform may throw on web or restricted environments
    }
    mutesConsole = isTest;
  }

  void log(String message,
      {required LogCategory category, required String level}) {
    if (_getLogLevel(level) < _getLogLevel(_minLevelFromEnv)) {
      return;
    }
    final entry = LogEntry(
      timestamp: DateTime.now(),
      category: category,
      level: level,
      message: message,
    );

    // Keep in-memory history for potential export (mirroring collectLogs in Swift)
    _history.add(entry);
    if (_history.length > _maxHistory) {
      _history.removeAt(0);
    }

    // Console output
    if (kDebugMode) {
      final emoji = _getEmoji(level);
      final formattedMessage = '[$emoji ${category.label}] $message';
      
      // Use developer.log for better integration with IDE loggers/DevTools
      developer.log(
        message,
        name: category.label,
        level: _getLogLevel(level),
        time: entry.timestamp,
      );
      
      // Also print to standard output for CLI visibility (flutter run)
      if (!mutesConsole) {
        // ignore: avoid_print
        print(formattedMessage);
      }
    }
  }

  int _getLogLevel(String level) {
    switch (level.toLowerCase()) {
      case 'error': return 1000;
      case 'warning': return 900;
      case 'info': return 800;
      case 'debug': return 500;
      default: return 0;
    }
  }

  String _getEmoji(String level) {
    switch (level.toLowerCase()) {
      case 'error': return '🔴';
      case 'warning': return '🟡';
      case 'info': return '🔵';
      case 'debug': return '⚪';
      default: return '📝';
    }
  }

  List<LogEntry> getHistory({Duration? since}) {
    if (since == null) return List.unmodifiable(_history);
    final cutoff = DateTime.now().subtract(since);
    return _history.where((e) => e.timestamp.isAfter(cutoff)).toList();
  }
}

// Global parity helpers
void obdInfo(String message, {LogCategory category = LogCategory.app}) {
  ObdLogger.instance.log(message, category: category, level: 'info');
}

void obdDebug(String message, {LogCategory category = LogCategory.app}) {
  ObdLogger.instance.log(message, category: category, level: 'debug');
}

void obdWarning(String message, {LogCategory category = LogCategory.app}) {
  ObdLogger.instance.log(message, category: category, level: 'warning');
}

void obdError(String message, {LogCategory category = LogCategory.app}) {
  ObdLogger.instance.log(message, category: category, level: 'error');
}
