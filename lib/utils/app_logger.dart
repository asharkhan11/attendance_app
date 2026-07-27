import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

enum LogLevel { debug, info, warning, error, network }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? details;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
    this.details,
  });

  String get levelLabel {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.network:
        return 'NET';
    }
  }

  String get emoji {
    switch (level) {
      case LogLevel.debug:
        return '🐛';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.network:
        return '🌐';
    }
  }
}

class AppLogger {
  static const int _maxLogs = 250;
  static bool enabled = kDebugMode;

  static final List<LogEntry> _logs = [];
  static final ValueNotifier<List<LogEntry>> logsNotifier = ValueNotifier<List<LogEntry>>([]);

  static List<LogEntry> get logs => List.unmodifiable(_logs);

  static void d(String tag, String message, {Map<String, dynamic>? details}) {
    _log(LogLevel.debug, tag, message, details: details);
  }

  static void i(String tag, String message, {Map<String, dynamic>? details}) {
    _log(LogLevel.info, tag, message, details: details);
  }

  static void w(String tag, String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? details}) {
    _log(LogLevel.warning, tag, message, error: error, stackTrace: stackTrace, details: details);
  }

  static void e(String tag, String message, {Object? error, StackTrace? stackTrace, Map<String, dynamic>? details}) {
    _log(LogLevel.error, tag, message, error: error, stackTrace: stackTrace, details: details);
  }

  static void net(String tag, String message, {Map<String, dynamic>? details}) {
    _log(LogLevel.network, tag, message, details: details);
  }

  static void clear() {
    _logs.clear();
    logsNotifier.value = List.unmodifiable(_logs);
    if (enabled) {
      developer.log('🧹 [APP_LOGGER] Log history cleared', name: 'AppLogger');
    }
  }

  static void _log(
    LogLevel level,
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
  }) {
    if (!enabled) return;

    final sanitizedDetails = details != null ? _sanitizeData(details) as Map<String, dynamic>? : null;
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      error: error,
      stackTrace: stackTrace,
      details: sanitizedDetails,
    );

    _logs.insert(0, entry);
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        logsNotifier.value = List.unmodifiable(_logs);
      });
    } else {
      logsNotifier.value = List.unmodifiable(_logs);
    }

    // Format output for console
    final timeStr = _formatTime(entry.timestamp);
    final logHeader = '${entry.emoji} [$timeStr] [${entry.levelLabel}] [$tag] $message';

    final buffer = StringBuffer(logHeader);
    if (sanitizedDetails != null && sanitizedDetails.isNotEmpty) {
      buffer.write('\n  Details: ${jsonEncode(sanitizedDetails)}');
    }
    if (error != null) {
      buffer.write('\n  Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n  StackTrace: $stackTrace');
    }

    final formattedMsg = buffer.toString();

    // Send to Flutter / Dart Developer Log & Debug Console
    developer.log(
      formattedMsg,
      name: tag,
      time: entry.timestamp,
      error: error,
      stackTrace: stackTrace,
      level: _levelToInt(level),
    );
  }

  static int _levelToInt(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 700;
      case LogLevel.network:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }

  static String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  static dynamic _sanitizeData(dynamic data) {
    if (data is Map) {
      final sanitized = <String, dynamic>{};
      data.forEach((key, value) {
        final keyStr = key.toString().toLowerCase();
        if (keyStr.contains('password') ||
            keyStr.contains('token') ||
            keyStr.contains('secret') ||
            keyStr.contains('authorization')) {
          sanitized[key.toString()] = '***REDACTED***';
        } else {
          sanitized[key.toString()] = _sanitizeData(value);
        }
      });
      return sanitized;
    } else if (data is List) {
      return data.map(_sanitizeData).toList();
    }
    return data;
  }
}
