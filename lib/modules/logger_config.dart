// lib/modules/logger_config.dart
import 'dart:io';

class LoggerConfig {
  static final List<String> _inMemoryLogs = [];
  static File? _logFile;

  static void init() {
    try {
      final now = DateTime.now();
      final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final logDir = Directory('logs');
      if (!logDir.existsSync()) {
        logDir.createSync(recursive: true);
      }
      _logFile = File('logs/$dateStr.log');
    } catch (_) {}
  }

  static void log(String message, {String level = 'INFO'}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final formatted = '[$timestamp] [$level] $message';
    _inMemoryLogs.add(formatted);
    
    // Print to stdout
    print(formatted);

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
