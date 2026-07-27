import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/constants.dart';

class SettingsService {
  static String get configPath {
    final devPath = p.join(Directory.current.path, 'config.ini');
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final prodPath = p.join(exeDir, 'config.ini');

    // If we're debugging/running in IDE or dev environment, use devPath (project root).
    // Otherwise check if prodPath exists. If not, default to devPath.
    if (Platform.resolvedExecutable.contains('flutter-tool') ||
        Platform.resolvedExecutable.contains('dart') ||
        !File(prodPath).existsSync()) {
      return devPath;
    }
    return prodPath;
  }

  static String get appCloneDir {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final prodCloneDir = p.join(exeDir, 'Clone');
    if (Platform.resolvedExecutable.contains('flutter-tool') ||
        Platform.resolvedExecutable.contains('dart')) {
      return p.join(Directory.current.path, 'dist', 'Clone');
    }
    return prodCloneDir;
  }

  static Map<String, dynamic> loadSettings() {
    final Map<String, String> data = {};
    final file = File(configPath);

    if (file.existsSync()) {
      try {
        final lines = file.readAsLinesSync();
        String currentSection = '';

        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty || line.startsWith('#') || line.startsWith(';')) {
            continue;
          }

          if (line.startsWith('[') && line.endsWith(']')) {
            currentSection = line.substring(1, line.length - 1).toUpperCase();
            continue;
          }

          // We only read from default or no section (configparser defaults go into DEFAULT)
          if (currentSection == '' || currentSection == 'DEFAULT') {
            final eqIdx = line.indexOf('=');
            if (eqIdx != -1) {
              final key = line.substring(0, eqIdx).trim();
              final val = line.substring(eqIdx + 1).trim();
              data[key] = val;
            }
          }
        }
      } catch (e) {
        // Fallback to defaults on error
        stderr.writeln("Error loading config.ini: $e");
      }
    }

    // Process and expand paths, parse booleans/integers
    final rawCommitMsg = data['commit_message'] ?? AppConstants.defaultCommitMessage;
    final commitMessage = rawCommitMsg == 'Update project' ? '' : rawCommitMsg;

    return {
      'last_root': _expandPath(data['last_root'] ?? AppConstants.defaultRoot),
      'remote_base': data['remote_base'] ?? '',
      'commit_message': commitMessage,
      'max_depth': _safeInt(data['max_depth'], 3),
      'auto_create_repo': _parseBool(data['auto_create_repo'], true),
      'repo_public': _parseBool(data['repo_public'], false),
      'last_explorer_path': _expandPath(data['last_explorer_path'] ?? ''),
      'last_selected_projects': _splitPaths(data['last_selected_projects'] ?? ''),
      'last_selected_cloud_projects': _splitPaths(data['last_selected_cloud_projects'] ?? ''),
      'last_lang': data['last_lang'] ?? 'en',
      'hidden_projects': _splitPaths(data['hidden_projects'] ?? ''),
      'license_author': data['license_author'] ?? 'John Alaa',
      'theme': data['theme'] ?? 'dark',
      'bg_blur': _safeDouble(data['bg_blur'], 10.0),
      'bg_opacity': _safeDouble(data['bg_opacity'], 0.6),
      'dialog_blur': _safeDouble(data['dialog_blur'], 2.0),
      'dialog_opacity': _safeDouble(data['dialog_opacity'], 0.8),
    };
  }

  static void saveSettings(Map<String, dynamic> settings) {
    final file = File(configPath);
    final buffer = StringBuffer();

    buffer.writeln('[DEFAULT]');
    buffer.writeln('last_root = ${settings['last_root'] ?? AppConstants.defaultRoot}');
    buffer.writeln('remote_base = ${settings['remote_base'] ?? ''}');
    buffer.writeln('commit_message = ${settings['commit_message'] ?? AppConstants.defaultCommitMessage}');
    buffer.writeln('max_depth = ${settings['max_depth'] ?? 3}');
    buffer.writeln('auto_create_repo = ${settings['auto_create_repo'] == true ? 'yes' : 'no'}');
    buffer.writeln('repo_public = ${settings['repo_public'] == true ? 'yes' : 'no'}');
    buffer.writeln('last_explorer_path = ${settings['last_explorer_path'] ?? ''}');
    buffer.writeln('last_selected_projects = ${_joinPaths(settings['last_selected_projects'] ?? [])}');
    buffer.writeln('last_selected_cloud_projects = ${_joinPaths(settings['last_selected_cloud_projects'] ?? [])}');
    buffer.writeln('last_lang = ${settings['last_lang'] ?? 'en'}');
    buffer.writeln('hidden_projects = ${_joinPaths(settings['hidden_projects'] ?? [])}');
    buffer.writeln('license_author = ${settings['license_author'] ?? 'John Alaa'}');
    buffer.writeln('theme = ${settings['theme'] ?? 'dark'}');
    buffer.writeln('bg_blur = ${settings['bg_blur'] ?? 10.0}');
    buffer.writeln('bg_opacity = ${settings['bg_opacity'] ?? 0.6}');
    buffer.writeln('dialog_blur = ${settings['dialog_blur'] ?? 2.0}');
    buffer.writeln('dialog_opacity = ${settings['dialog_opacity'] ?? 0.8}');

    try {
      file.writeAsStringSync(buffer.toString());
    } catch (e) {
      stderr.writeln("Error saving config.ini: $e");
    }
  }

  // --- Helpers ---

  static String _expandPath(String path) {
    if (path.isEmpty) return '';
    // Expand ~ user home
    if (path.startsWith('~')) {
      final home = Platform.isWindows
          ? Platform.environment['USERPROFILE'] ?? ''
          : Platform.environment['HOME'] ?? '';
      path = path.replaceFirst('~', home);
    }
    // Expand environment variables e.g. %APPDATA% or $VAR
    path = path.replaceAllMapped(RegExp(r'%([^%]+)%'), (match) {
      final varName = match.group(1);
      return Platform.environment[varName] ?? match.group(0)!;
    });
    path = path.replaceAllMapped(RegExp(r'\$([a-zA-Z0-9_]+)'), (match) {
      final varName = match.group(1);
      return Platform.environment[varName] ?? match.group(0)!;
    });

    return path;
  }

  static int _safeInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static double _safeDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  static bool _parseBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    final s = value.toString().toLowerCase().trim();
    if (s == '1' || s == 'yes' || s == 'true' || s == 'on') return true;
    if (s == '0' || s == 'no' || s == 'false' || s == 'off') return false;
    return defaultValue;
  }

  static List<String> _splitPaths(String value) {
    return value.split('|').where((item) => item.isNotEmpty).toList();
  }

  static String _joinPaths(dynamic paths) {
    if (paths is List) {
      return paths.where((item) => item.toString().isNotEmpty).join('|');
    }
    return '';
  }
}
