import 'dart:io';

class WindowsInfo {
  /// Returns `true` if the platform is Windows.
  static final bool isWindows = Platform.isWindows;

  /// Returns `true` if running on Windows 11 or greater (build version >= 22000).
  static final bool isWindows11OrGreater = _checkIsWindows11OrGreater();

  static bool _checkIsWindows11OrGreater() {
    if (!Platform.isWindows) return false;
    try {
      final versionString = Platform.operatingSystemVersion;
      // Format example: "Windows 10 IoT Enterprise LTSC" 10.0 (Build 19044)
      final match = RegExp(r'Build (\d+)').firstMatch(versionString);
      if (match != null) {
        final buildNum = int.tryParse(match.group(1) ?? '');
        if (buildNum != null && buildNum >= 22000) {
          return true;
        }
      }
    } catch (_) {}
    return false; // Default to false (Windows 10 or older) if checking fails
  }
}
