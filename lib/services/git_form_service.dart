import 'dart:io';
import 'package:path/path.dart' as p;
import '../utils/constants.dart';

class GitFormService {
  /// Standardizes a project folder structure: initializes git, main branch,
  /// .gitignore, git_push.bat, LICENSE, README.md (with 9 languages), and ABOUT.txt.
  static Future<bool> fixProjectGitForm(String projectDir, String licenseAuthor, String remoteBase, void Function(String) log) async {
    final absPath = p.absolute(projectDir);
    if (!Directory(absPath).existsSync()) {
      throw FileNotFoundError("Folder not found: $absPath");
    }

    final gitDir = Directory(p.join(absPath, '.git'));
    if (!gitDir.existsSync()) {
      log("[INFO] Initializing Git repository...\n");
      final res = await Process.run('git', ['init'], workingDirectory: absPath);
      if (res.exitCode == 0) {
        log("[OK] Created .git repository.\n");
      } else {
        log("[ERROR] Failed to initialize Git: ${res.stderr}\n");
      }
    }

    // Set branch name to main
    await Process.run('git', ['branch', '-M', AppConstants.defaultBranch], workingDirectory: absPath);

    final list = Directory(absPath).listSync();
    final fileNames = list.map((e) => p.basename(e.path)).toSet();
    final kind = _detectProjectKindForReadme(fileNames) ?? "generic";

    // Apply ensures
    ensureGitignore(absPath, kind);
    ensureGitPushBat(absPath, log);
    ensureLicense(absPath, licenseAuthor, log);
    ensureReadme(absPath, remoteBase, log);
    ensureAboutTxt(absPath, log);

    log("[OK] Git form is ready: .git, main branch, .gitignore, git_push.bat, LICENSE, README.md, ABOUT.txt.\n");
    return true;
  }

  static Future<bool> ensureStandardForms({
    required String path,
    required String projectName,
    required String kind,
    required String authorName,
    required String remoteBaseUrl,
  }) async {
    return fixProjectGitForm(path, authorName, remoteBaseUrl, (_) {});
  }

  static bool gitignoreIsStandardSync(String projectDir, String kind) {
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

  /// Merges the required template lines for [kind] into [existingLines], skipping any
  /// non-comment line already present. Pure — does not touch disk, so it's safe to preview
  /// against an in-memory editing buffer (e.g. the .gitignore editor dialog).
  static List<String> mergeGitignoreLines(List<String> existingLines, String kind) {
    final existingSet = existingLines.map((line) => line.trim()).toSet();
    final List<String> merged = List.from(existingLines);

    if (merged.isNotEmpty && merged.last.trim().isNotEmpty) {
      merged.add("");
    }

    for (var line in AppConstants.getRequiredGitignoreLines(kind)) {
      if (line.isNotEmpty && !line.startsWith('#') && existingSet.contains(line.trim())) {
        continue;
      }
      merged.add(line);
    }

    return merged;
  }

  static void ensureGitignore(String projectDir, String kind) {
    final path = p.join(projectDir, '.gitignore');
    final file = File(path);
    final List<String> existing = file.existsSync() ? file.readAsLinesSync() : [];

    final merged = mergeGitignoreLines(existing, kind);
    file.writeAsStringSync(merged.join('\n').trimRight() + '\n', flush: true);
  }

  static void ensureGitPushBat(String projectDir, void Function(String) log) {
    final path = p.join(projectDir, 'git_push.bat');
    final file = File(path);
    
    // Windows bat files require \r\n endings
    final content = AppConstants.gitPushBat.replaceAll('\n', '\r\n');
    file.writeAsStringSync(content, flush: true);
    log("[OK] Created/Updated git_push.bat.\n");
  }

  static void ensureLicense(String projectDir, String author, void Function(String) log) {
    final path = p.join(projectDir, 'LICENSE');
    final file = File(path);
    final year = DateTime.now().year.toString();

    final content = AppConstants.licenseTemplate
        .replaceAll('{year}', year)
        .replaceAll('{author}', author);

    file.writeAsStringSync(content, flush: true);
    log("[OK] Created/Updated LICENSE file (Author: $author).\n");
  }

  static void ensureReadme(String projectDir, String remoteBase, void Function(String) log) {
    final path = p.join(projectDir, 'README.md');
    final file = File(path);
    final list = Directory(projectDir).listSync();
    
    final fileNames = list.map((e) => p.basename(e.path)).toSet();
    final kind = _detectProjectKindForReadme(fileNames) ?? "project";
    final projectName = p.basename(projectDir);

    // Resolve project remote url
    final repoName = p.basename(projectDir);
    String owner = remoteBase.trim().replaceAll(RegExp(r'^https://github.com/'), '').replaceAll(RegExp(r'/$'), '');
    if (owner.contains('/')) {
      owner = owner.split('/')[0];
    }
    if (owner.isEmpty) {
      owner = "JohnAlaa";
    }
    
    final repoUrl = "https://github.com/$owner/$repoName";

    // 1. Create/Update English README.md
    final enContent = generateReadmeContent(projectName, kind, "en", repoUrl);
    file.writeAsStringSync(enContent, flush: true);
    log("[OK] Created/Updated main README.md (English).\n");

    // 2. Create/Update i18n/ directory & translations
    final i18nDir = Directory(p.join(projectDir, 'i18n'));
    if (!i18nDir.existsSync()) {
      i18nDir.createSync(recursive: true);
    }

    final List<String> languages = ["vi", "zh-CN", "ja-JP", "es", "fr", "de", "ru", "pt", "ko"];
    for (var lang in languages) {
      final langPath = p.join(i18nDir.path, 'README.$lang.md');
      final langContent = generateReadmeContent(projectName, kind, lang, repoUrl);
      File(langPath).writeAsStringSync(langContent, flush: true);
    }
    log("[OK] Created/Updated translated READMEs in i18n/.\n");
  }

  static void ensureAboutTxt(String projectDir, void Function(String) log) {
    final path = p.join(projectDir, 'ABOUT.txt');
    final file = File(path);

    if (file.existsSync()) {
      try {
        if (file.readAsStringSync().trim().isNotEmpty) {
          return; // Skip if already exists and is not empty
        }
      } catch (_) {}
    }

    final list = Directory(projectDir).listSync();
    final fileNames = list.map((e) => p.basename(e.path)).toSet();
    final kind = _detectProjectKindForReadme(fileNames);
    final projectName = p.basename(projectDir);

    String techStack = "General / Polyglot";
    String description = "A structured project configuration optimized for automated CI/CD and Git workflows.";

    if (kind == "python") {
      techStack = "Python 3.13 / PySide6";
      description = "A high-performance Python application designed with modular architecture for robust operations.";
    } else if (kind == "node") {
      techStack = "Node.js / JavaScript";
      description = "A modern Node.js application built for scale and efficiency using JavaScript/TypeScript.";
    } else if (kind == "ahk") {
      techStack = "AutoHotkey (AHK)";
      description = "An efficient automation script developed in AutoHotkey to streamline Windows workflows.";
    } else if (kind == "dotnet") {
      techStack = ".NET / C#";
      description = "A robust C#/.NET application engineered for reliability and high performance.";
    } else if (kind == "dart") {
      techStack = "Dart / Flutter";
      description = "A modern cross-platform application developed in Dart/Flutter for high performance.";
    }

    final card = """========================================================================
                       PROJECT INFORMATION CARD
========================================================================
Project Name : $projectName
Tech Stack   : $techStack
Managed By   : JA Auto Git
Website      : https://jatechvn.github.io/
------------------------------------------------------------------------
Description  : $description
========================================================================
""";

    file.writeAsStringSync(card, flush: true);
    log("[OK] Created/Updated ABOUT.txt.\n");
  }

  static String generateReadmeContent(String projectName, String kind, String lang, String repoUrl, {String? websiteUrl}) {
    var l = lang.toLowerCase();
    if (l == 'zh-cn' || l == 'zh_cn') l = 'zh-cn';
    if (l == 'ja-jp' || l == 'ja_jp') l = 'ja-jp';

    final t = AppConstants.readmeTranslations[l] ?? AppConstants.readmeTranslations['en']!;
    final webUrl = websiteUrl ?? "https://jatechvn.github.io/";

    String intro = "";
    String techBadges = "";
    String installSteps = "";
    String treeModules = "";

    if (kind == "python") {
      intro = "$projectName ${t['intro_python']}";
      const logoUrl = "https://img.shields.io/badge/Python-3.13-blue.svg?style=flat-square&logo=python";
      techBadges = '<img src="$logoUrl" alt="Python Version">\n  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License">';
      installSteps = """### ${t['setup_run_title']}
1. ${t['setup_run_python_install']}
   ```cmd
   pip install -r requirements.txt
   ```
2. ${t['setup_run_run']}
   ```cmd
   run.bat
   ```""";

      final uiDirDesc = lang != "vi" ? "User Interface package" : "Package chứa giao diện người dùng";
      final uiInitDesc = lang != "vi" ? "UI package marker" : "Đánh dấu package UI";
      final uiMainDesc = lang != "vi" ? "Main window interface" : "Cửa sổ giao diện chính của ứng dụng";
      final uiStylesDesc = lang != "vi" ? "UI stylesheet & styling" : "Stylesheet CSS và cấu hình giao diện";
      final uiDialogsDesc = lang != "vi" ? "Popup dialogs (optional)" : "Hộp thoại popup phụ (nếu có)";
      final logicDesc = lang != "vi" ? "Core logic / Business rules" : "Logic nghiệp vụ chính";
      final utilsDesc = lang != "vi" ? "Shared helper functions" : "Các hàm tiện ích dùng chung";
      final constDesc = lang != "vi" ? "Global constants" : "Hằng số cấu hình";
      final loggerDesc = lang != "vi" ? "Logger configuration" : "Cấu hình logging";
      final nativeDirDesc = lang != "vi" ? "Hybrid core engine package" : "Tầng quản lý xử lý lai (Hybrid Engine Core)";
      final nativeInitDesc = lang != "vi" ? "Native core package marker" : "Đánh dấu package native";
      final winCoreDesc = lang != "vi" ? "Windows optimized core (PowerShell/C++)" : "Tối ưu Windows (Win32 API/PowerShell)";
      final macCoreDesc = lang != "vi" ? "macOS optimized core" : "Tối ưu macOS (Objective-C/dylib)";
      final linuxCoreDesc = lang != "vi" ? "Linux optimized core" : "Tối ưu Linux (Bash/so)";
      final bridgeDesc = lang != "vi" ? "Dynamic routing bridge to active OS core" : "Bộ định tuyến động kết nối Logic và OS";

      treeModules = """│   ├── ui/                    # $uiDirDesc
│   │   ├── __init__.py        # $uiInitDesc
│   │   ├── main_window.py     # $uiMainDesc
│   │   ├── styles.py          # $uiStylesDesc
│   │   └── dialogs.py         # $uiDialogsDesc
│   ├── native/                # $nativeDirDesc
│   │   ├── __init__.py        # $nativeInitDesc
│   │   ├── win_core.py        # $winCoreDesc
│   │   ├── mac_core.py        # $macCoreDesc
│   │   └── linux_core.py      # $linuxCoreDesc
│   ├── native_bridge.py       # $bridgeDesc
│   ├── logic.py               # $logicDesc
│   ├── utils.py               # $utilsDesc
│   ├── constants.py           # $constDesc
│   └── logger_config.py       # $loggerDesc""";
    } else if (kind == "node") {
      intro = "$projectName ${t['intro_node']}";
      const logoUrl = "https://img.shields.io/badge/Node.js-JS-green.svg?style=flat-square&logo=node.js";
      techBadges = '<img src="$logoUrl" alt="Node.js">\n  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License">';
      installSteps = """### ${t['setup_run_title']}
1. ${t['setup_run_node_install']}
   ```cmd
   npm install
   ```
2. ${t['setup_run_run']}
   ```cmd
   npm start
   ```""";
      treeModules = "│   # ${t['struct_modules']}";
    } else if (kind == "ahk") {
      intro = "$projectName ${t['intro_ahk']}";
      techBadges = '<img src="https://img.shields.io/badge/Language-AutoHotkey-orange.svg?style=flat-square" alt="AutoHotkey">\n  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License">';
      installSteps = """### ${t['setup_run_title']}
${t['setup_run_ahk']}
```cmd
"C:\\\\Program Files\\\\AutoHotkey\\\\AutoHotkey.exe" main.ahk
```""";
      treeModules = "│   # ${t['struct_modules']}";
    } else if (kind == "dotnet") {
      intro = "$projectName ${t['intro_dotnet']}";
      techBadges = '<img src="https://img.shields.io/badge/.NET-C%23-purple.svg?style=flat-square&logo=dotnet" alt=".NET">\n  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License">';
      installSteps = """### ${t['setup_run_title']}
${t['setup_run_dotnet_build']}
```cmd
dotnet build
dotnet run
```""";
      treeModules = "│   # ${t['struct_modules']}";
    } else if (kind == "dart") {
      intro = "$projectName ${t['intro_dart']}";
      const logoUrl = "https://img.shields.io/badge/Dart-Flutter-blue.svg?style=flat-square&logo=flutter";
      techBadges = '<img src="$logoUrl" alt="Dart & Flutter">\n  <img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License">';
      installSteps = """### ${t['setup_run_title']}
1. ${t['setup_run_python_install']}
   ```cmd
   flutter pub get
   ```
2. ${t['setup_run_run']}
   ```cmd
   flutter run
   ```""";

      final srcDirDesc = lang != "vi" ? "Application source code" : "Thư mục chứa mã nguồn chính";
      final entryDesc = lang != "vi" ? "Program entry point" : "Điểm khởi chạy ứng dụng";
      final modelsDesc = lang != "vi" ? "Data models" : "Thư mục chứa các mô hình dữ liệu";
      final servicesDesc = lang != "vi" ? "Business logic and APIs" : "Các dịch vụ xử lý logic chính";
      final widgetsDesc = lang != "vi" ? "UI component widgets" : "Các widget giao diện người dùng";

      treeModules = """│   ├── lib/                   # $srcDirDesc
│   │   ├── main.dart          # $entryDesc
│   │   ├── models/            # $modelsDesc
│   │   ├── services/          # $servicesDesc
│   │   └── widgets/           # $widgetsDesc""";
    } else {
      intro = "$projectName ${t['intro_generic']}";
      techBadges = '<img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square" alt="License">';
      installSteps = """### ${t['setup_run_title']}
${t['setup_run_run']}""";
      treeModules = "│   # ${t['struct_modules']}";
    }

    
    final String structureText;
    if (kind == "dart") {
      final srcDirDesc = lang != "vi" ? "Application source code" : "Thư mục chứa mã nguồn chính";
      final entryDesc = lang != "vi" ? "Program entry point" : "Điểm khởi chạy ứng dụng";
      final modelsDesc = lang != "vi" ? "Data models" : "Thư mục chứa các mô hình dữ liệu";
      final servicesDesc = lang != "vi" ? "Business logic and APIs" : "Các dịch vụ xử lý logic chính";
      final widgetsDesc = lang != "vi" ? "UI component widgets" : "Các widget giao diện người dùng";
      final pubspecDesc = lang != "vi" ? "Flutter package dependencies and version" : "Cấu hình thư viện và phiên bản ứng dụng";

      structureText = """$projectName/
├── lib/                       # $srcDirDesc
│   ├── main.dart              # $entryDesc
│   ├── models/                # $modelsDesc
│   ├── services/              # $servicesDesc
│   └── widgets/               # $widgetsDesc
├── assets/                    # ${t['struct_assets']}
├── .gitignore                 # ${t['struct_gitignore']}
├── README.md                  # ${t['struct_readme']}
├── LICENSE                    # ${t['struct_license']}
├── ABOUT.txt                  # ${t['struct_about']}
├── git_push.bat               # ${t['struct_push_bat']}
└── pubspec.yaml               # $pubspecDesc""";
    } else {
      structureText = """$projectName/
├── main.py                    # ${t['struct_main']}
├── run.bat                    # ${t['struct_run']}
├── requirements.txt           # ${t['struct_req']}
├── config.ini                 # ${t['struct_config_ini']}
├── config.json                # ${t['struct_config_json']}
├── .gitignore                 # ${t['struct_gitignore']}
├── README.md                  # ${t['struct_readme']}
├── LICENSE                    # ${t['struct_license']}
├── ABOUT.txt                  # ${t['struct_about']}
├── git_push.bat               # ${t['struct_push_bat']}
│
├── logs/                      # ${t['struct_logs']}
│
├── modules/                   # ${t['struct_modules']}
$treeModules
│
└── assets/                    # ${t['struct_assets']}""";
    }

    final langBar = generateLanguageBar(lang);
    final navQuick = t["nav_quick_start"] ?? "🚀 Quick Start";
    final navFeat = t["nav_features"] ?? "💡 Features";
    final navSet = t["nav_setup"] ?? "📖 Setup";
    final navWeb = t["nav_website"] ?? "🌐 Website";
    final navBar = '<a href="#quick-start">$navQuick</a> • <a href="#features">$navFeat</a> • <a href="#setup">$navSet</a> • <a href="$webUrl">$navWeb</a>';

    return """# 🤖 $projectName

<p align="center">
  <br>
  <i>**$intro**</i>
</p>

<p align="center">
  $techBadges
</p>

<p align="center">$navBar</p>

<p align="center">$langBar</p>

---

<a id="introduction"></a>
## ${t['title_intro']}

${t['intro_desc']}

<a id="features"></a>
## ${t['title_features']}

- ${t['feature_1']}
- ${t['feature_2']}
- ${t['feature_3']}

---

## ${t['title_structure']}

```text
$structureText
```

---

<a id="setup"></a>
## ${t['title_setup']}

### ${t['setup_reqs']}
*   ${t['setup_os']}
*   ${t['setup_interpreter_python']}

<a id="quick-start"></a>
$installSteps

---

## ${t['title_license']}

${t['license_body']}
""";
  }

  static String generateLanguageBar(String currentLang) {
    final List<Map<String, String>> langs = [
      {"code": "en", "label": "🇺🇸 English", "rel": "../README.md", "root": "README.md"},
      {"code": "vi", "label": "🇻🇳 Tiếng Việt", "rel": "README.vi.md", "root": "i18n/README.vi.md"},
      {"code": "zh-cn", "label": "🇨🇳 中文", "rel": "README.zh-CN.md", "root": "i18n/README.zh-CN.md"},
      {"code": "ja-jp", "label": "🇯🇵 日本語", "rel": "README.ja-JP.md", "root": "i18n/README.ja-JP.md"},
      {"code": "es", "label": "🇪🇸 Español", "rel": "README.es.md", "root": "i18n/README.es.md"},
      {"code": "fr", "label": "🇫🇷 Français", "rel": "README.fr.md", "root": "i18n/README.fr.md"},
      {"code": "de", "label": "🇩🇪 Deutsch", "rel": "README.de.md", "root": "i18n/README.de.md"},
      {"code": "ru", "label": "🇷🇺 Русский", "rel": "README.ru.md", "root": "i18n/README.ru.md"},
      {"code": "pt", "label": "🇵🇹 Português", "rel": "README.pt.md", "root": "i18n/README.pt.md"},
      {"code": "ko", "label": "🇰🇷 한국어", "rel": "README.ko.md", "root": "i18n/README.ko.md"},
    ];

    final cur = currentLang.toLowerCase();
    final List<String> parts = [];

    for (var lang in langs) {
      final code = lang['code']!;
      final label = lang['label']!;
      if (code == cur) {
        parts.add(label);
      } else {
        final path = cur == 'en' ? lang['root']! : lang['rel']!;
        parts.add('<a href="$path">$label</a>');
      }
    }
    return parts.join(' • ');
  }

  static String? _detectProjectKindForReadme(Set<String> fileNames) {
    for (var entry in AppConstants.projectMarkers.entries) {
      final kind = entry.key;
      final markers = entry.value;

      for (var marker in markers) {
        if (marker.contains('*')) {
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
    return null;
  }
}

class FileNotFoundError implements Exception {
  final String message;
  FileNotFoundError(this.message);
  @override
  String toString() => "FileNotFoundError: $message";
}
