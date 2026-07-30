// lib/modules/build_info.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

class BuildInfo {
  /// Set at startup if launched with -debug or --debug CLI argument
  static bool isCliDebug = false;

  /// Build timestamp based on executable's last modified time
  static final String debugTimestamp = _generateBuildTimestamp();

  static String _generateBuildTimestamp() {
    try {
      final exeFile = File(Platform.resolvedExecutable);
      final appSoFile = File('${exeFile.parent.path}${Platform.pathSeparator}data${Platform.pathSeparator}app.so');
      
      // Use app.so if it exists (Release mode AOT snapshot), otherwise fallback to the exe file
      final targetFile = appSoFile.existsSync() ? appSoFile : exeFile;

      if (targetFile.existsSync()) {
        final modified = targetFile.lastModifiedSync();
        final yyyy = modified.year.toString();
        final mm = modified.month.toString().padLeft(2, '0');
        final dd = modified.day.toString().padLeft(2, '0');
        final hh = modified.hour.toString().padLeft(2, '0');
        final min = modified.minute.toString().padLeft(2, '0');
        final ss = modified.second.toString().padLeft(2, '0');
        return '$yyyy-$mm-$dd $hh:$min:$ss';
      }
    } catch (_) {}

    final now = DateTime.now();
    final yyyy = now.year.toString();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min:$ss';
  }

  /// Returns true if app is running in Flutter debug mode OR launched with -debug flag
  static bool get isDebug => kDebugMode || isCliDebug;

  /// Returns 'DEBUG' or 'RELEASE'
  static String get modeName => isDebug ? 'DEBUG' : 'RELEASE';

  /// Badge text for UI header
  static String get badgeLabel {
    if (isDebug) {
      return 'DEBUG • v${AppConstants.appVersion} ($debugTimestamp)';
    }
    return 'v${AppConstants.appVersion}';
  }
}
