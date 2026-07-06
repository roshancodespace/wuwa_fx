import 'package:flutter/foundation.dart';

enum LogLevel { info, warning, error }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? details;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class AppLogger {
  static final ValueNotifier<List<LogEntry>> logsNotifier =
      ValueNotifier<List<LogEntry>>([]);
  static const int maxLogs = 500;

  static void _addLog(LogLevel level, String message, [Object? details]) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      details: details?.toString(),
    );

    // Print to console
    final prefix = level == LogLevel.error
        ? '🔴 [ERROR]'
        : level == LogLevel.warning
        ? '🟡 [WARN]'
        : '🔵 [INFO]';
    final logStr =
        '$prefix ${entry.formattedTime}: $message ${details != null ? "- $details" : ""}';
    debugPrint(logStr);

    // Add to in-memory list
    final current = List<LogEntry>.from(logsNotifier.value);
    current.insert(0, entry); // newest first
    if (current.length > maxLogs) {
      current.removeLast();
    }
    logsNotifier.value = current;
  }

  static void i(String message, [Object? details]) =>
      _addLog(LogLevel.info, message, details);
  static void w(String message, [Object? details]) =>
      _addLog(LogLevel.warning, message, details);
  static void e(String message, [Object? details]) =>
      _addLog(LogLevel.error, message, details);

  static void clear() {
    logsNotifier.value = [];
    debugPrint('🔵 [INFO] Logs cleared.');
  }
}
