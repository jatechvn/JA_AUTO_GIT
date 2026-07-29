import 'dart:io';

/// Platform helper service providing OS interaction without native plugins
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

  /// Open Windows FolderBrowserDialog to pick a directory path
  static Future<String?> pickDirectory({String? description}) async {
    if (!Platform.isWindows) return null;

    try {
      final descStr = (description ?? 'Select Root Directory').replaceAll("'", "''");
      final script =
          "Add-Type -AssemblyName System.Windows.Forms; "
          "\$dialog = New-Object System.Windows.Forms.FolderBrowserDialog; "
          "\$dialog.Description = '$descStr'; "
          "if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Write-Output \$dialog.SelectedPath }";

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        script,
      ]);

      final selectedPath = result.stdout.toString().trim();
      if (selectedPath.isNotEmpty && Directory(selectedPath).existsSync()) {
        return selectedPath;
      }
    } catch (_) {}
    return null;
  }
}
