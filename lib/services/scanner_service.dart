import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'git_service.dart';
import '../models/project_info.dart';
import '../utils/constants.dart';

class ScannerService {
  /// Scans the root directory for projects up to a given depth.
  /// Runs asynchronously.
  static Future<List<ProjectInfo>> scanProjects(String rootDir, {int maxDepth = 3}) async {
    final root = Directory(p.absolute(rootDir));
    if (!root.existsSync()) {
      throw FileSystemException("Root folder not found", rootDir);
    }

    final List<ProjectInfo> projects = [];
    await _traverse(root.path, root.path, maxDepth, projects);
    
    // Sort projects alphabetically by path (case-insensitive)
    projects.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return projects;
  }

  static Future<void> _traverse(String rootPath, String currentPath, int maxDepth, List<ProjectInfo> projects) async {
    final currentDir = Directory(currentPath);
    final int depth = _relativeDepth(rootPath, currentPath);

    if (depth > maxDepth) {
      return;
    }

    List<FileSystemEntity> entities;
    try {
      entities = await currentDir.list(followLinks: false).toList();
    } catch (_) {
      // Permission issues or directory deleted during scan
      return;
    }

    final fileNames = <String>{};
    final List<String> subdirsToTraverse = [];

    for (var entity in entities) {
      final name = p.basename(entity.path);
      
      // Skip hidden directories and SKIP_DIRS
      if (name.startsWith('.') || AppConstants.skipDirs.contains(name)) {
        continue;
      }

      if (entity is Directory) {
        subdirsToTraverse.add(entity.path);
      } else if (entity is File) {
        fileNames.add(name);
      }
    }

    final currentKind = _detectProjectKind(currentPath, fileNames);

    // Check if any child subdirectory is itself a project
    bool hasChildProject = false;
    for (var subdir in subdirsToTraverse) {
      final childFiles = _getFileNames(subdir);
      if (_detectProjectKind(subdir, childFiles) != null) {
        hasChildProject = true;
        break;
      }
    }

    // If current directory is a project AND it has no child projects, then it's a leaf project!
    if (currentKind != null && !hasChildProject) {
      final info = await inspectProject(currentPath, currentKind);
      projects.add(info);
      return; // Stop scanning deeper into this project
    }

    // Otherwise, traverse subdirectories to find projects
    for (var subdir in subdirsToTraverse) {
      await _traverse(rootPath, subdir, maxDepth, projects);
    }
  }

  static Set<String> _getFileNames(String dirPath) {
    final names = <String>{};
    try {
      final entities = Directory(dirPath).listSync(followLinks: false);
      for (var e in entities) {
        if (e is File) {
          names.add(p.basename(e.path));
        }
      }
    } catch (_) {}
    return names;
  }

  static int _relativeDepth(String root, String current) {
    final rel = p.relative(current, from: root);
    if (rel == '.') return 0;
    return p.split(rel).length;
  }

  static String? _detectProjectKind(String dirPath, Set<String> fileNames) {
    for (var entry in AppConstants.projectMarkers.entries) {
      final kind = entry.key;
      final markers = entry.value;

      for (var marker in markers) {
        if (marker.contains('*')) {
          // Glob pattern match (e.g., *.ahk, *.csproj)
          final regexStr = '^' + marker.replaceAll('.', r'\.').replaceAll('*', r'.*') + r'$';
          final regex = RegExp(regexStr, caseSensitive: false);
          if (fileNames.any((name) => regex.hasMatch(name))) {
            return kind;
          }
        } else if (fileNames.contains(marker)) {
          return kind;
        }
      }
    }
    
    // Check if it is simply a git repository
    if (Directory(p.join(dirPath, '.git')).existsSync()) {
      return 'git';
    }
    
    return null;
  }

  static Future<ProjectInfo> inspectProject(String projectDir, String kind) async {
    final absPath = p.absolute(projectDir);
    final hasGit = Directory(p.join(absPath, '.git')).existsSync();
    
    String branch = '';
    String remoteUrl = '';
    bool clean = true;

    if (hasGit) {
      branch = await _gitOutput(absPath, ['branch', '--show-current']);
      remoteUrl = await _gitOutput(absPath, ['remote', 'get-url', 'origin']);
      
      final statusOut = await _gitOutput(absPath, ['status', '--short']);
      clean = statusOut.isEmpty;
    }

    final hasGitignore = File(p.join(absPath, '.gitignore')).existsSync();
    final gitignoreOk = await _gitignoreIsStandard(absPath, kind);
    final pushBatOk = File(p.join(absPath, 'git_push.bat')).existsSync();
    final readmeOk = File(p.join(absPath, 'README.md')).existsSync();
    final licenseOk = File(p.join(absPath, 'LICENSE')).existsSync();
    final aboutOk = File(p.join(absPath, 'ABOUT.txt')).existsSync();
    final hasRemote = remoteUrl.isNotEmpty;
    
    final standardOk = hasGit && 
                       branch == AppConstants.defaultBranch && 
                       gitignoreOk && 
                       pushBatOk && 
                       readmeOk && 
                       licenseOk && 
                       aboutOk;

    final status = _buildStatus(
      hasGit,
      branch,
      hasRemote,
      clean,
      gitignoreOk,
      pushBatOk,
      readmeOk,
      licenseOk,
      aboutOk,
      hasGitignore
    );

    final version = await detectVersion(absPath, hasGit: hasGit);

    return ProjectInfo(
      name: p.basename(absPath),
      path: absPath,
      kind: kind,
      hasGit: hasGit,
      branch: branch,
      hasRemote: hasRemote,
      remoteUrl: remoteUrl,
      clean: clean,
      gitignoreOk: gitignoreOk,
      pushBatOk: pushBatOk,
      readmeOk: readmeOk,
      licenseOk: licenseOk,
      aboutOk: aboutOk,
      hasGitignore: hasGitignore,
      standardOk: standardOk,
      status: status,
      version: version,
    );
  }

  static Future<String> detectVersion(String projectDir, {bool hasGit = false}) async {
    final pPath = projectDir;

    // 0. pubspec.yaml
    final pubspecFile = File(p.join(pPath, 'pubspec.yaml'));
    if (pubspecFile.existsSync()) {
      try {
        final content = pubspecFile.readAsStringSync();
        final match = RegExp(r"^\s*version\s*:\s*([^\s+]+)", multiLine: true).firstMatch(content);
        if (match != null) {
          final v = match.group(1)!.split('+')[0].trim();
          if (v.isNotEmpty) return v;
        }
      } catch (_) {}
    }

    // 1. package.json
    final pkgFile = File(p.join(pPath, 'package.json'));
    if (pkgFile.existsSync()) {
      try {
        final content = pkgFile.readAsStringSync();
        final data = json.decode(content);
        final v = data['version']?.toString();
        if (v != null && v.isNotEmpty) return v;
      } catch (_) {}
    }

    // 2. pyproject.toml
    final pptFile = File(p.join(pPath, 'pyproject.toml'));
    if (pptFile.existsSync()) {
      try {
        final content = pptFile.readAsStringSync();
        final match = RegExp(r"""^\s*version\s*=\s*["']([^"']+)["']""", multiLine: true).firstMatch(content);
        if (match != null) return match.group(1)!;
      } catch (_) {}
    }

    // 3. setup.cfg
    final scfgFile = File(p.join(pPath, 'setup.cfg'));
    if (scfgFile.existsSync()) {
      try {
        final content = scfgFile.readAsStringSync();
        final match = RegExp(r"""^\s*version\s*=\s*(.+)""", multiLine: true).firstMatch(content);
        if (match != null) {
          final v = match.group(1)!.trim();
          if (v.isNotEmpty && !v.startsWith('attr:') && !v.startsWith('file:')) {
            return v;
          }
        }
      } catch (_) {}
    }

    // 4. setup.py
    final spyFile = File(p.join(pPath, 'setup.py'));
    if (spyFile.existsSync()) {
      try {
        final content = spyFile.readAsStringSync();
        final match = RegExp(r"""version\s*=\s*["']([^"']+)["']""").firstMatch(content);
        if (match != null) return match.group(1)!;
      } catch (_) {}
    }

    // 5. *.csproj
    try {
      final dir = Directory(pPath);
      final files = dir.listSync();
      for (var f in files) {
        if (f is File && f.path.endsWith('.csproj')) {
          final content = f.readAsStringSync();
          var match = RegExp(r"""<Version>([^<]+)</Version>""").firstMatch(content);
          if (match != null) return match.group(1)!.trim();
          match = RegExp(r"""<AssemblyVersion>([^<]+)</AssemblyVersion>""").firstMatch(content);
          if (match != null) return match.group(1)!.trim();
        }
      }
    } catch (_) {}

    // 6. constants.py / version.py / __version__.py / _version.py
    final possibleFiles = ['constants.py', 'version.py', '__version__.py', '_version.py'];
    for (var fname in possibleFiles) {
      var fpath = p.join(pPath, fname);
      if (!File(fpath).existsSync()) {
        fpath = p.join(pPath, 'modules', fname);
      }
      final file = File(fpath);
      if (file.existsSync()) {
        try {
          final content = file.readAsStringSync();
          var match = RegExp(r"""APP_VERSION\s*=\s*["']([^"']+)["']""").firstMatch(content);
          if (match != null) return match.group(1)!;
          match = RegExp(r"""__version__\s*=\s*["']([^"']+)["']""").firstMatch(content);
          if (match != null) return match.group(1)!;
          match = RegExp(r"""\bVERSION\s*=\s*["']([^"']+)["']""").firstMatch(content);
          if (match != null) return match.group(1)!;
        } catch (_) {}
      }
    }

    // 7. ABOUT.txt
    final aboutFile = File(p.join(pPath, 'ABOUT.txt'));
    if (aboutFile.existsSync()) {
      try {
        final content = aboutFile.readAsStringSync();
        final match = RegExp(r'[Vv]ersion\s*[:\-]\s*([\d][^\s]+)').firstMatch(content);
        if (match != null) return match.group(1)!.trim();
      } catch (_) {}
    }

    // 8. Git Tag
    if (hasGit) {
      try {
        final tag = await _gitOutput(pPath, ['describe', '--tags', '--abbrev=0']);
        if (tag.isNotEmpty) return tag;
      } catch (_) {}
    }

    return '';
  }

  static Future<bool> _gitignoreIsStandard(String projectDir, String kind) async {
    final path = p.join(projectDir, '.gitignore');
    final file = File(path);
    if (!file.existsSync()) return false;

    try {
      final contentLines = file.readAsLinesSync().map((l) => l.trim()).toSet();
      final requiredLines = AppConstants.getRequiredGitignoreLines(kind)
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.startsWith('#'))
          .toSet();
      
      return requiredLines.every((line) => contentLines.contains(line));
    } catch (_) {
      return false;
    }
  }

  static String _buildStatus(
    bool hasGit,
    String branch,
    bool hasRemote,
    bool clean,
    bool gitignoreOk,
    bool pushBatOk,
    bool readmeOk,
    bool licenseOk,
    bool aboutOk,
    bool hasGitignore
  ) {
    final List<String> missing = [];
    if (!hasGit) {
      missing.add(".git");
    }
    if (hasGit && branch != AppConstants.defaultBranch) {
      missing.add("branch main");
    }
    if (!hasGitignore) {
      missing.add(".gitignore");
    } else if (!gitignoreOk) {
      missing.add(".gitignore (non-standard)");
    }
    if (!pushBatOk) {
      missing.add("git_push.bat");
    }
    if (!readmeOk) {
      missing.add("README.md");
    }
    if (!licenseOk) {
      missing.add("LICENSE");
    }
    if (!aboutOk) {
      missing.add("ABOUT.txt");
    }
    if (hasGit && !hasRemote) {
      missing.add("remote");
    }
    if (hasGit && !clean) {
      missing.add("uncommitted");
    }
    
    return missing.isEmpty ? "OK" : "Missing: " + missing.join(", ");
  }

  // --- Subprocess execution helpers ---

  static Future<String> _gitOutput(String workingDir, List<String> args) async {
    try {
      final res = await Process.run(
        GitService.findGitExecutable(),
        args,
        workingDirectory: workingDir,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        return res.stdout.toString().trim();
      }
    } catch (_) {}
    return '';
  }
}
