import 'dart:io';
import 'package:file_picker/file_picker.dart';

/// Platform helper service providing OS interaction (URL opening, directory picking)
class SystemService {
  /// Open a URL in default system browser
  static Future<bool> openUrl(String url) async {
    final target = url.trim();
    if (target.isEmpty) return false;

    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', target]);
        return true;
      } else if (Platform.isMacOS) {
        await Process.run('open', [target]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [target]);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Open the native OS folder picker to select a directory path
  static Future<String?> pickDirectory({String? description, String? initialDirectory}) async {
    try {
      final selectedPath = await FilePicker.getDirectoryPath(
        dialogTitle: description ?? 'Select Root Directory',
        initialDirectory: (initialDirectory != null && Directory(initialDirectory).existsSync()) ? initialDirectory : null,
      );
      if (selectedPath != null && Directory(selectedPath).existsSync()) {
        return selectedPath;
      }
    } catch (_) {}
    return null;
  }
}
