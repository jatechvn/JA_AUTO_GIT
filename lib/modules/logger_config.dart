// lib/modules/logger_config.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class LoggerConfig {
  static final List<String> _inMemoryLogs = [];
  static File? _logFile;
  static bool isDebugMode = kDebugMode;

  static void init({bool debug = false}) {
    isDebugMode = debug || kDebugMode || Platform.environment.containsKey('DEBUG');
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final logDir = Directory('logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      _logFile = File('logs/$dateStr.log');
      _rotateOldLogs(logDir, now);
      log("Logger initialized (DebugMode: $isDebugMode)", level: 'SYSTEM');
    } catch (_) {}
  }

  /// Deletes daily log files older than 7 days so `logs/` doesn't grow forever.
  static void _rotateOldLogs(Directory logDir, DateTime now) {
    const maxAgeDays = 7;
    try {
      for (final entity in logDir.listSync()) {
        if (entity is! File || !entity.path.endsWith('.log')) continue;
        final ageDays = now.difference(entity.statSync().modified).inDays;
        if (ageDays > maxAgeDays) {
          entity.deleteSync();
        }
      }
    } catch (_) {}
  }

  static void log(String message, {String level = 'INFO', Object? error, StackTrace? stackTrace}) {
    final timestamp = isDebugMode ? DateTime.now().toIso8601String() : DateTime.now().toIso8601String().substring(11, 19);
    var formatted = '[$timestamp] [$level] $message';
    
    if (error != null && isDebugMode) {
      formatted += ' | Error: $error';
    }
    if (stackTrace != null && isDebugMode) {
      formatted += '\nStackTrace: $stackTrace';
    }

    _inMemoryLogs.add(formatted);
    
    // Print to stdout
    if (isDebugMode || level == 'ERROR' || level == 'WARN') {
      debugPrint(formatted);
    }

    // Append to file
    if (_logFile != null) {
      try {
        _logFile!.writeAsStringSync('$formatted\n', mode: FileMode.append);
      } catch (_) {}
    }
  }

  static List<String> get logs => List.unmodifiable(_inMemoryLogs);

  static void clear() {
    _inMemoryLogs.clear();
  }
}
