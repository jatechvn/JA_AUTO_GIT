import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Helper function to open URLs in default web browser reliably across all platforms
Future<void> openUrlHelper(String url) async {
  if (url.isEmpty) return;
  try {
    final launched = await launchUrlString(url, mode: LaunchMode.externalApplication);
    if (launched) return;
  } catch (_) {}

  if (Platform.isWindows) {
    try {
      await Process.run('cmd', ['/c', 'start', '', url]);
    } catch (_) {}
  }
}

/// Helper function to pick a directory path with automatic Windows PowerShell fallback
Future<String?> pickDirectoryPath({String? initialDirectory}) async {
  // 1. Try native FilePicker first
  try {
    String? initDir;
    if (initialDirectory != null && initialDirectory.trim().isNotEmpty) {
      final dir = Directory(initialDirectory.trim());
      if (dir.existsSync()) {
        initDir = dir.path;
      }
    }
    final selected = await FilePicker.platform.getDirectoryPath(
      initialDirectory: initDir,
      dialogTitle: 'Select Target Root Directory',
    );
    if (selected != null && selected.trim().isNotEmpty) {
      return selected.trim();
    }
  } catch (e) {
    debugPrint('FilePicker error: $e');
  }

  // 2. Windows fallback using PowerShell FolderBrowserDialog with UTF-8 encoding
  if (Platform.isWindows) {
    try {
      final initialPath = (initialDirectory != null && initialDirectory.trim().isNotEmpty && Directory(initialDirectory.trim()).existsSync())
          ? initialDirectory.trim().replaceAll("'", "''")
          : '';
      final psScript = '''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
\$OutputEncoding = [System.Text.Encoding]::UTF8
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
\$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
if ('$initialPath' -ne '' -and (Test-Path -LiteralPath '$initialPath')) { \$dialog.SelectedPath = '$initialPath' }
if (\$dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Out.Write(\$dialog.SelectedPath)
}
''';
      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', psScript],
        stdoutEncoding: utf8,
      );
      if (res.exitCode == 0) {
        final out = res.stdout.toString().trim();
        if (out.isNotEmpty && Directory(out).existsSync()) {
          return out;
        }
      }
    } catch (e) {
      debugPrint('PowerShell directory picker fallback error: $e');
    }
  }
  return null;
}

class AppConstants {
  static const String appId = "JA_AUTO_GIT";
  static const String appName = "JA Auto Git";
  static const String appVersion = "1.5.0";
  static const String appTitle = "JA AUTO GIT - LIQUID GLASS";

  static const double defaultWidth = 1220;
  static const double defaultHeight = 780;

  static const String fontPrimary = "Outfit";
  static const String fontMono = "Consolas";

  static const Color accentCyan = Color(0xFF00ADB5);
  static const Color accentGreen = Color(0xFF00FF9D);
  static const Color accentPurple = Color(0xFFB026FF);

  static const Color colorCloseNormal = Color(0xFFFF5F56);
  static const Color colorCloseBorder = Color(0xFFE0443E);
  static const Color colorCloseHover = Color(0xFFFF7B72);

  static const Color colorMinNormal = Color(0xFFFFBD2E);
  static const Color colorMinBorder = Color(0xFFDEA123);
  static const Color colorMinHover = Color(0xFFFFCA52);

  static const Color colorMaxNormal = Color(0xFF27C93F);
  static const Color colorMaxBorder = Color(0xFF1AAB29);
  static const Color colorMaxHover = Color(0xFF38E04F);

  static const String defaultRoot = "";
  static const String defaultBranch = "main";
  static const String defaultCommitMessage = "";

  static const Map<String, List<String>> projectMarkers = {
    "dart": ["pubspec.yaml"],
    "dotnet": ["*.sln", "*.csproj"],
    "python": ["main.py", "requirements.txt", "pyproject.toml", "setup.py"],
    "node": ["package.json"],
    "ahk": ["*.ahk"],
    "powershell": ["*.ps1"],
    "batch": ["*.bat", "*.cmd"],
  };

  static const Set<String> skipDirs = {
    ".git",
    ".dart_tool",
    ".venv",
    "venv",
    "ENV",
    "__pycache__",
    "node_modules",
    "dist",
    "build",
    "bin",
    "out",
    "target",
    "logs",
    "build_pyinstall",
    "build_nuitka",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
  };

  static const List<String> globalGitignoreLines = [
    "# Local IDE / OS files",
    ".vscode/",
    ".idea/",
    ".DS_Store",
    "Thumbs.db",
    "",
    "# Personal config - uncomment if config has password/token/key",
    "# config.ini",
    "# config.json",
    "",
    "# License that should absolutely not be committed",
    "license.key",
  ];

  static const List<String> pythonGitignoreLines = [
    "# Virtual environment",
    ".venv/",
    "venv/",
    "ENV/",
    "",
    "# Python cache / compiled files",
    "__pycache__/",
    "*.py[cod]",
    r"*$py.class",
    "*.pyd",
    "",
    "# Build output",
    "build/",
    "dist/",
    "build_pyinstall/",
    "build_nuitka/",
    "*.spec",
    "",
    "# Logs and temporary files",
    "logs/*.log",
    "assets/temp/",
    "",
    "# Hybrid native libraries",
    "modules/native/*.dll",
    "modules/native/*.so",
    "modules/native/*.dylib",
  ];

  static const List<String> nodeGitignoreLines = [
    "# Dependency directories",
    "node_modules/",
    "",
    "# Log files",
    "npm-debug.log*",
    "yarn-debug.log*",
    "yarn-error.log*",
  ];

  static const List<String> dotnetGitignoreLines = [
    "# User-specific files",
    "*.rsuser",
    "*.suo",
    "*.user",
    "*.userosscache",
    "*.sln.docstates",
    "",
    "# Build results",
    "[Dd]ebug/",
    "[Dd]ebugPublic/",
    "[Rr]elease/",
    "x64/",
    "x86/",
    "build/",
    "bin/",
    "obj/",
  ];

  static const List<String> dartGitignoreLines = [
    "# Dart/Flutter exclusion patterns",
    ".dart_tool/",
    ".flutter-plugins",
    ".flutter-plugins-dependencies",
    ".pub-cache/",
    ".pub/",
    "build/",
    "windows/flutter/ephemeral/",
    "linux/flutter/ephemeral/",
    "macos/Flutter/ephemeral/",
  ];

  static List<String> getRequiredGitignoreLines(String kind) {
    final List<String> lines = [];
    lines.addAll(globalGitignoreLines);
    lines.add("");

    final k = kind.toLowerCase();
    if (k == 'python') {
      lines.addAll(pythonGitignoreLines);
    } else if (k == 'node') {
      lines.addAll(nodeGitignoreLines);
    } else if (k == 'dotnet') {
      lines.addAll(dotnetGitignoreLines);
    } else if (k == 'dart') {
      lines.addAll(dartGitignoreLines);
    }
    return lines;
  }

  static const String gitPushBat = """@echo off
cd /d %~dp0

set /p remote_url="Nhap GitHub repo URL: "
set /p commit_msg="Nhap commit message: "
if "%commit_msg%"=="" set commit_msg=Update project

if exist "license.key" (
    echo [WARNING] Phat hien license.key. File nay phai nam trong .gitignore va khong duoc commit.
)

if not exist ".git" (
    git init
    git branch -M main
)

git status --short
git add .
git commit -m "%commit_msg%"
git remote remove origin 2>nul
git remote add origin "%remote_url%"
git push -u origin main

pause
""";

  static const String licenseTemplate = """MIT License

Copyright (c) {year} {author}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
""";

  static const Map<String, Map<String, String>> readmeTranslations = {
    "en": {
      "intro_python": "is an application developed in Python.",
      "intro_node": "is a project developed on Node.js.",
      "intro_ahk": "is an automation tool written in AutoHotkey.",
      "intro_dotnet": "is a software developed on the .NET platform.",
      "intro_dart": "is a cross-platform application developed in Dart/Flutter.",
      "intro_generic": "is a project/automation tool.",
      "intro_desc": "The project is standardized according to professional project structures, supporting efficient source code management via Git.",
      "title_intro": "Introduction",
      "title_features": "Key Features",
      "feature_1": "Quick setup and professional packaging.",
      "feature_2": "Lightweight configuration, easy to maintain and extend.",
      "feature_3": "Automated Git push workflow with the included script.",
      "title_structure": "Directory Structure",
      "struct_main": "Application entry point",
      "struct_run": "Quick start script on Windows",
      "struct_req": "Dependencies list",
      "struct_config_ini": "Simple configuration file",
      "struct_config_json": "Structured JSON configuration file",
      "struct_gitignore": "Git exclusion patterns",
      "struct_readme": "Project documentation (this file)",
      "struct_license": "License file",
      "struct_about": "Short description of the project",
      "struct_push_bat": "Auto push script to GitHub",
      "struct_logs": "Application logs",
      "struct_modules": "Core modules containing business logic",
      "struct_assets": "Application static resources",
      "title_setup": "Installation & Usage Guide",
      "setup_reqs": "System Requirements",
      "setup_os": "OS: **Windows 10/11**",
      "setup_interpreter_python": "Interpreter: **Python 3.13** or equivalent environment.",
      "setup_run_title": "How to Run",
      "setup_run_python_install": "Install required dependencies:",
      "setup_run_node_install": "Install package dependencies:",
      "setup_run_dotnet_build": "Build the project using .NET CLI:",
      "setup_run_ahk": "Run the script directly via AutoHotkey:",
      "setup_run_run": "Run the application:",
      "title_license": "License",
      "license_body": "This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details."
    },
    "vi": {
      "intro_python": "là một ứng dụng được phát triển bằng ngôn ngữ Python.",
      "intro_node": "là một dự án chạy trên nền tảng Node.js.",
      "intro_ahk": "là một công cụ tự động hóa được viết bằng AutoHotkey.",
      "intro_dotnet": "là một phần mềm được xây dựng trên nền tảng .NET.",
      "intro_dart": "là một ứng dụng đa nền tảng được phát triển bằng Dart/Flutter.",
      "intro_generic": "là một dự án/công cụ tự động hóa.",
      "intro_desc": "Dự án được chuẩn hóa theo cấu trúc thư mục chuyên nghiệp, hỗ trợ quản lý mã nguồn hiệu quả qua Git.",
      "title_intro": "Giới thiệu",
      "title_features": "Tính năng nổi bật",
      "feature_1": "Thiết lập nhanh chóng và đóng gói chuyên nghiệp.",
      "feature_2": "Cấu trúc tinh gọn, dễ dàng bảo trì và phát triển thêm.",
      "feature_3": "Quy trình đẩy code lên Git tự động hóa thông qua script đi kèm.",
      "title_structure": "Cấu trúc thư mục",
      "struct_main": "File chạy chính của ứng dụng",
      "struct_run": "File khởi động nhanh trên Windows",
      "struct_req": "Danh sách các thư viện phụ thuộc",
      "struct_config_ini": "File cấu hình đơn giản",
      "struct_config_json": "File cấu hình JSON cấu trúc",
      "struct_gitignore": "Các mẫu loại trừ khỏi Git",
      "struct_readme": "Tài liệu hướng dẫn (chính là file này)",
      "struct_license": "File bản quyền phần mềm",
      "struct_about": "Thông tin tóm tắt về dự án",
      "struct_push_bat": "Script tự động đẩy code lên GitHub",
      "struct_logs": "Thư mục chứa logs ghi nhận lỗi",
      "struct_modules": "Các mô-đun xử lý logic chính của ứng dụng",
      "struct_assets": "Tài nguyên tĩnh (hình ảnh, cấu hình mặc định...)",
      "title_setup": "Hướng dẫn cài đặt & Sử dụng",
      "setup_reqs": "Yêu cầu hệ thống",
      "setup_os": "Hệ điều hành: **Windows 10/11**",
      "setup_interpreter_python": "Trình thông dịch: **Python 3.13** hoặc môi trường tương đương.",
      "setup_run_title": "Cách khởi chạy",
      "setup_run_python_install": "Cài đặt các thư viện cần thiết:",
      "setup_run_node_install": "Cài đặt các gói phụ thuộc node:",
      "setup_run_dotnet_build": "Biên dịch dự án sử dụng .NET CLI:",
      "setup_run_ahk": "Chạy script trực tiếp bằng AutoHotkey:",
      "setup_run_run": "Chạy ứng dụng:",
      "title_license": "Bản quyền",
      "license_body": "Dự án này được phân phối dưới **Giấy phép MIT**. Xem file [LICENSE](LICENSE) để biết thêm chi tiết."
    },
    "zh-cn": {
      "intro_python": "是一个基于 Python 开发的应用程序。",
      "intro_node": "是一个基于 Node.js 开发的项目。",
      "intro_ahk": "是一个使用 AutoHotkey 编写的自动化工具。",
      "intro_dotnet": "是一个在 .NET 平台上构建的软件。",
      "intro_dart": "是一个基于 Dart/Flutter 开发的跨平台应用程序。",
      "intro_generic": "是一个项目或自动化工具。",
      "intro_desc": "该项目已按照专业项目结构进行标准化配置，支持通过 Git 进行高效的源码管理。",
      "title_intro": "介绍",
      "title_features": "核心功能",
      "feature_1": "快速部署与专业化打包。",
      "feature_2": "配置轻量，易于维护和扩展。",
      "feature_3": "通过附带的脚本实现自动化 Git 提交与推送工作流。",
      "title_structure": "目录结构",
      "struct_main": "应用程序入口文件",
      "struct_run": "Windows 快速启动脚本",
      "struct_req": "依赖包列表",
      "struct_config_ini": "简单配置文件",
      "struct_config_json": "结构化 JSON 配置文件",
      "struct_gitignore": "Git 忽略规则文件",
      "struct_readme": "项目说明文档（即当前文件）",
      "struct_license": "开源协议授权文件",
      "struct_about": "项目简要信息卡片",
      "struct_push_bat": "GitHub 自动推送脚本",
      "struct_logs": "日志文件存放目录",
      "struct_modules": "包含业务逻辑的核心模块目录",
      "struct_assets": "静态资源文件目录",
      "title_setup": "安装与使用指南",
      "setup_reqs": "系统需求",
      "setup_os": "操作系统: **Windows 10/11**",
      "setup_interpreter_python": "解释器: **Python 3.13** 或同等环境。",
      "setup_run_title": "如何运行",
      "setup_run_python_install": "安装所需的依赖库:",
      "setup_run_node_install": "安装项目依赖:",
      "setup_run_dotnet_build": "使用 .NET CLI 构建项目:",
      "setup_run_ahk": "通过 AutoHotkey 直接运行脚本:",
      "setup_run_run": "运行应用程序:",
      "title_license": "协议",
      "license_body": "本项目采用 **MIT 协议** 进行授权。详情请参阅 [LICENSE](LICENSE) 文件。"
    },
    "ja-jp": {
      "intro_python": "は Python で開発されたアプリケーションです。",
      "intro_node": "は Node.js プラットフォーム上で開発されたプロジェクトです。",
      "intro_ahk": "は AutoHotkey で記述された自動化ツールです。",
      "intro_dotnet": "は .NET プラットフォームで構築されたソフトウェアです。",
      "intro_dart": "は Dart/Flutter で開発されたクロスプラットフォームアプリケーションです。",
      "intro_generic": "はプロジェクト/自動化ツールです。",
      "intro_desc": "このプロジェクトはプロフェッショナルな設計思想に準拠して標準化されており、Git による効率的なソースコード管理をサポートしています。",
      "title_intro": "概要",
      "title_features": "主な機能",
      "feature_1": "迅速なセットアップとプロフェッショナルなパッケージング。",
      "feature_2": "軽量な構成で、保守と拡張が容易。",
      "feature_3": "同梱のスクリプトによる Git プッシュの自動化ワークフロー。",
      "title_structure": "ディレクトリ構造",
      "struct_main": "アプリケーションのエントリポイント",
      "struct_run": "Windows 用クイックスタートスクリプト",
      "struct_req": "依存関係リスト",
      "struct_config_ini": "簡易設定ファイル",
      "struct_config_json": "構造化 JSON 設定ファイル",
      "struct_gitignore": "Git 除外パターン設定ファイル",
      "struct_readme": "プロジェクト解説書（本書）",
      "struct_license": "ライセンス許諾ファイル",
      "struct_about": "プロジェクト概要カード",
      "struct_push_bat": "GitHub 自動プッシュスクリプト",
      "struct_logs": "ログ保存ディレクトリ",
      "struct_modules": "主要なロジックを含むモジュール群",
      "struct_assets": "静的リソース（画像など）",
      "title_setup": "セットアップと使用方法",
      "setup_reqs": "システム要件",
      "setup_os": "OS: **Windows 10/11**",
      "setup_interpreter_python": "環境: **Python 3.13** または同等の実行環境。",
      "setup_run_title": "実行方法",
      "setup_run_python_install": "必要な依存ライブラリのインストール:",
      "setup_run_node_install": "依存パッケージのインストール:",
      "setup_run_dotnet_build": ".NET CLI を使用したプロジェクトのビルド:",
      "setup_run_ahk": "AutoHotkey を使用したスクリプトの直接実行:",
      "setup_run_run": "アプリケーションの起動:",
      "title_license": "ライセンス",
      "license_body": "このプロジェクトは **MIT ライセンス** の下で提供されています。詳細は [LICENSE](LICENSE) ファイルをご参照ください。"
    },
    "es": {
      "intro_python": "es una aplicación desarrollada en Python.",
      "intro_node": "es un proyecto desarrollado en Node.js.",
      "intro_ahk": "es una herramienta de automatización escrita en AutoHotkey.",
      "intro_dotnet": "es un software desarrollado en la plataforma .NET.",
      "intro_dart": "es una aplicación multiplataforma desarrollada en Dart/Flutter.",
      "intro_generic": "es un proyecto/herramienta de automatización.",
      "intro_desc": "El proyecto está estandarizado de acuerdo con estructuras de proyectos profesionales, lo que admite una gestión eficiente del código fuente a través de Git.",
      "title_intro": "Introducción",
      "title_features": "Características Clave",
      "feature_1": "Configuración rápida y empaquetado profesional.",
      "feature_2": "Configuración ligera, fácil de mantener y extender.",
      "feature_3": "Flujo de trabajo de empuje Git automatizado con el script incluido.",
      "title_structure": "Estructura de Directorios",
      "struct_main": "Punto de entrada de la aplicación",
      "struct_run": "Script de inicio rápido en Windows",
      "struct_req": "Lista de dependencias",
      "struct_config_ini": "Archivo de configuración simple",
      "struct_config_json": "Archivo de configuración JSON estructurado",
      "struct_gitignore": "Patrones de exclusión de Git",
      "struct_readme": "Documentación del proyecto (este archivo)",
      "struct_license": "Archivo de licencia",
      "struct_about": "Breve descripción del proyecto",
      "struct_push_bat": "Script de empuje automático a GitHub",
      "struct_logs": "Logs de la aplicación",
      "struct_modules": "Módulos principales con la lógica de negocio",
      "struct_assets": "Recursos estáticos de la aplicación",
      "title_setup": "Guía de Instalación y Uso",
      "setup_reqs": "Requisitos del Sistema",
      "setup_os": "SO: **Windows 10/11**",
      "setup_interpreter_python": "Intérprete: **Python 3.13** o entorno equivalente.",
      "setup_run_title": "Cómo Ejecutar",
      "setup_run_python_install": "Instalar dependencias requeridas:",
      "setup_run_node_install": "Instalar dependencias del paquete:",
      "setup_run_dotnet_build": "Compilar el proyecto usando la CLI de .NET:",
      "setup_run_ahk": "Ejecutar el script directamente a través de AutoHotkey:",
      "setup_run_run": "Ejecutar la aplicación:",
      "title_license": "Licencia",
      "license_body": "Este proyecto está licenciado bajo la **Licencia MIT**. Consulte el archivo [LICENSE](LICENSE) para obtener más detalles."
    },
    "fr": {
      "intro_python": "est une application développée en Python.",
      "intro_node": "est un projet développé sur Node.js.",
      "intro_ahk": "est un outil d'automatisation écrit en AutoHotkey.",
      "intro_dotnet": "est un logiciel développé sur la plateforme .NET.",
      "intro_dart": "est une application multiplateforme développée en Dart/Flutter.",
      "intro_generic": "est un projet/outil d'automatisation.",
      "intro_desc": "Le projet est standardisé selon des structures de projets professionnelles, prenant en charge une gestion efficace du code source via Git.",
      "title_intro": "Introduction",
      "title_features": "Caractéristiques Principales",
      "feature_1": "Configuration rapide et empaquetage professionnel.",
      "feature_2": "Configuration légère, facile à maintenir et à étendre.",
      "feature_3": "Flux de travail de push automatique Git avec le script inclus.",
      "title_structure": "Estructure des Répertoires",
      "struct_main": "Point d'entrée de l'application",
      "struct_run": "Script de démarrage rapide sur Windows",
      "struct_req": "Liste des dépendances",
      "struct_config_ini": "Fichier de configuration simple",
      "struct_config_json": "Fichier de configuration JSON structuré",
      "struct_gitignore": "Modèles d'exclusion Git",
      "struct_readme": "Documentation du projet (ce fichier)",
      "struct_license": "Fichier de licence",
      "struct_about": "Description abrégée du projet",
      "struct_push_bat": "Script de push automatique vers GitHub",
      "struct_logs": "Logs de l'application",
      "struct_modules": "Modules principaux contenant la logique métier",
      "struct_assets": "Ressources statiques de l'application",
      "title_setup": "Guide d'Installation et d'Utilisation",
      "setup_reqs": "Configuration Requise",
      "setup_os": "Système d'exploitation: **Windows 10/11**",
      "setup_interpreter_python": "Interpréteur: **Python 3.13** ou environnement équivalent.",
      "setup_run_title": "Comment Lancer",
      "setup_run_python_install": "Installer les dépendances requises:",
      "setup_run_node_install": "Installer les dépendances du paquet:",
      "setup_run_dotnet_build": "Construire le projet via l'interface CLI .NET:",
      "setup_run_ahk": "Exécuter le script directement via AutoHotkey:",
      "setup_run_run": "Lancer l'application:",
      "title_license": "Licence",
      "license_body": "Ce projet est sous licence **MIT**. Voir le fichier [LICENSE](LICENSE) pour plus de détails."
    },
    "de": {
      "intro_python": "ist eine in Python entwickelte Anwendung.",
      "intro_node": "ist ein auf Node.js entwickeltes Projekt.",
      "intro_ahk": "ist ein in AutoHotkey geschriebenes Automatisierungstool.",
      "intro_dotnet": "ist eine Software, die auf der .NET-Plattform entwickelt wurde.",
      "intro_dart": "ist eine plattformübergreifende Anwendung, die in Dart/Flutter entwickelt wurde.",
      "intro_generic": "ist ein Projekt/Automatisierungstool.",
      "intro_desc": "Das Projekt ist nach professionellen Projektstrukturen standardisiert und unterstützt eine effiziente Quellcodeverwaltung über Git.",
      "title_intro": "Einführung",
      "title_features": "Hauptmerkmale",
      "feature_1": "Schnelle Einrichtung und professionelle Paketierung.",
      "feature_2": "Leichte Konfiguration, einfach zu warten und zu erweitern.",
      "feature_3": "Automatisierter Git-Push-Workflow mit dem mitgelieferten Skript.",
      "title_structure": "Verzeichnisstruktur",
      "struct_main": "Haupteinstiegspunkt der Anwendung",
      "struct_run": "Schnellstartskript für Windows",
      "struct_req": "Liste der Abhängigkeiten",
      "struct_config_ini": "Einfache Konfigurationsdatei",
      "struct_config_json": "Strukturierte JSON-Konfigurationsdatei",
      "struct_gitignore": "Git-Ausschlussmuster",
      "struct_readme": "Projektdokumentation (diese Datei)",
      "struct_license": "Lizenzdatei",
      "struct_about": "Kurzbeschreibung des Projekts",
      "struct_push_bat": "Automatisches Push-Skript für GitHub",
      "struct_logs": "Anwendungsprotokolle",
      "struct_modules": "Kernmodule mit der Geschäftslogik",
      "struct_assets": "Statische Ressourcen der Anwendung",
      "title_setup": "Installations- und Benutzerhandbuch",
      "setup_reqs": "Systemanforderungen",
      "setup_os": "Betriebssystem: **Windows 10/11**",
      "setup_interpreter_python": "Interpreter: **Python 3.13** oder gleichwertige Umgebung.",
      "setup_run_title": "Ausführung",
      "setup_run_python_install": "Erforderliche Abhängigkeiten installieren:",
      "setup_run_node_install": "Paketabhängigkeiten installieren:",
      "setup_run_dotnet_build": "Projekt mit der .NET CLI erstellen:",
      "setup_run_ahk": "Skript direkt über AutoHotkey ausführen:",
      "setup_run_run": "Anwendung ausführen:",
      "title_license": "Lizenz",
      "license_body": "Dieses Projekt steht unter der **MIT-Lizenz**. Weitere Details finden Sie in der [LICENSE](LICENSE)-Datei."
    },
    "ru": {
      "intro_python": "— это приложение, разработанное на Python.",
      "intro_node": "— это проект, разработанный на платформе Node.js.",
      "intro_ahk": "— это инструмент автоматизации, написанный на AutoHotkey.",
      "intro_dotnet": "— это программное обеспечение, разработанное на платформе .NET.",
      "intro_dart": "— это кроссплатформенное приложение, разработанное на Dart/Flutter.",
      "intro_generic": "— это проект/инструмент автоматизации.",
      "intro_desc": "Проект стандартизирован в соответствии с профессиональной структурой проектов, что обеспечивает эффективное управление исходным кодом с помощью Git.",
      "title_intro": "Введение",
      "title_features": "Ключевые Особенности",
      "feature_1": "Быстрая настройка и профессиональная упаковка.",
      "feature_2": "Легковесная конфигурация, простота обслуживания и расширения.",
      "feature_3": "Автоматизированный рабочий процесс отправки изменений в Git с помощью встроенного скрипта.",
      "title_structure": "Структура Каталогов",
      "struct_main": "Точка входа в приложение",
      "struct_run": "Скрипт быстрого запуска в Windows",
      "struct_req": "Список зависимостей",
      "struct_config_ini": "Простой конфигурационный файл",
      "struct_config_json": "Структурированный конфигурационный файл JSON",
      "struct_gitignore": "Шаблоны исключений Git",
      "struct_readme": "Документация проекта (этот файл)",
      "struct_license": "Лицензионный файл",
      "struct_about": "Краткое описание проекта",
      "struct_push_bat": "Скрипт автоматической отправки изменений на GitHub",
      "struct_logs": "Журналы событий приложения",
      "struct_modules": "Основные модули с бизнес-логикой",
      "struct_assets": "Статические ресурсы приложения",
      "title_setup": "Руководство по Установке и Использованию",
      "setup_reqs": "Системные требования",
      "setup_os": "Операционная система: **Windows 10/11**",
      "setup_interpreter_python": "Интерпретатор: **Python 3.13** или соответствующая среда.",
      "setup_run_title": "Запуск",
      "setup_run_python_install": "Установите необходимые зависимости:",
      "setup_run_node_install": "Установите зависимости пакета:",
      "setup_run_dotnet_build": "Соберите проект с помощью .NET CLI:",
      "setup_run_ahk": "Запустите скрипт напрямую через AutoHotkey:",
      "setup_run_run": "Запустите приложение:",
      "title_license": "Лицензия",
      "license_body": "Этот проект распространяется под **лицензией MIT**. Подробности см. в файле [LICENSE](LICENSE)."
    },
    "pt": {
      "intro_python": "é um aplicativo desenvolvido em Python.",
      "intro_node": "é um projeto desenvolvido em Node.js.",
      "intro_ahk": "é uma ferramenta de automação escrita em AutoHotkey.",
      "intro_dotnet": "é um software desenvolvido na plataforma .NET.",
      "intro_dart": "é um aplicativo multiplataforma desenvolvido em Dart/Flutter.",
      "intro_generic": "é um projeto/ferramenta de automação.",
      "intro_desc": "O projeto é padronizado de acordo com estruturas de projetos profissionais, suportando gerenciamento eficiente de código-fonte via Git.",
      "title_intro": "Introdução",
      "title_features": "Recursos Principais",
      "feature_1": "Configuração rápida e empacotamento profissional.",
      "feature_2": "Configuração leve, fácil de manter e estender.",
      "feature_3": "Fluxo de trabalho de push automatizado para Git com o script incluso.",
      "title_structure": "Estrutura de Diretórios",
      "struct_main": "Ponto de entrada do aplicativo",
      "struct_run": "Script de início rápido no Windows",
      "struct_req": "Lista de dependências",
      "struct_config_ini": "Arquivo de configuração simples",
      "struct_config_json": "Arquivo de configuração JSON estruturado",
      "struct_gitignore": "Padrões de exclusão do Git",
      "struct_readme": "Documentação do projeto (este arquivo)",
      "struct_license": "Arquivo de licença",
      "struct_about": "Breve descrição do projeto",
      "struct_push_bat": "Script de push automático para o GitHub",
      "struct_logs": "Logs do aplicativo",
      "struct_modules": "Módulos principais contendo a lógica de negócios",
      "struct_assets": "Recursos estáticos do aplicativo",
      "title_setup": "Guia de Instalação e Uso",
      "setup_reqs": "Requisitos do Sistema",
      "setup_os": "SO: **Windows 10/11**",
      "setup_interpreter_python": "Intérprete: **Python 3.13** ou ambiente equivalente.",
      "setup_run_title": "Como Executar",
      "setup_run_python_install": "Instalar as dependências necessárias:",
      "setup_run_node_install": "Instalar as dependências do pacote:",
      "setup_run_dotnet_build": "Compilar o projeto usando a CLI do .NET:",
      "setup_run_ahk": "Executar o script diretamente via AutoHotkey:",
      "setup_run_run": "Executar o aplicativo:",
      "title_license": "Licença",
      "license_body": "Este projeto está licenciado sob a **Licença MIT**. Consulte o arquivo [LICENSE](LICENSE) para obter detalhes."
    },
    "ko": {
      "intro_python": "Python으로 개발된 애플리케이션입니다.",
      "intro_node": "Node.js 플랫폼에서 개발된 프로젝트입니다.",
      "intro_ahk": "AutoHotkey로 작성된 자동화 도구입니다.",
      "intro_dotnet": ".NET 플랫폼에서 개발된 소프트웨어입니다.",
      "intro_dart": "Dart/Flutter로 개발된 크로스 플랫폼 애플리케이션입니다.",
      "intro_generic": "프로젝트/자동화 도구입니다.",
      "intro_desc": "본 프로젝트는 전문적인 프로젝트 구조에 따라 표준화되어 있으며, Git을 통한 효율적인 소스 코드 관리를 지원합니다.",
      "title_intro": "소개",
      "title_features": "주요 기능",
      "feature_1": "빠른 설정 및 전문가 수준의 패키징.",
      "feature_2": "유지 관리와 확장이 용이한 가벼운 구성.",
      "feature_3": "포함된 스크립트를 통한 자동 Git 푸시 워크플로우.",
      "title_structure": "디렉토리 구조",
      "struct_main": "애플리케이션 진입점",
      "struct_run": "Windows용 빠른 시작 스크립트",
      "struct_req": "의존성 목록",
      "struct_config_ini": "간단한 설정 파일",
      "struct_config_json": "구조화된 JSON 설정 파일",
      "struct_gitignore": "Git 제외 패턴",
      "struct_readme": "프로젝트 문서 (본 파일)",
      "struct_license": "라이센스 파일",
      "struct_about": "프로젝트에 대한 짧은 설명",
      "struct_push_bat": "GitHub 자동 푸시 스크립트",
      "struct_logs": "애플리케이션 로그",
      "struct_modules": "비즈니스 로직을 포함하는 핵심 모듈",
      "struct_assets": "애플리케이션 정적 리소스",
      "title_setup": "설치 및 사용 가이드",
      "setup_reqs": "시스템 요구 사항",
      "setup_os": "운영체제: **Windows 10/11**",
      "setup_interpreter_python": "인터프리터: **Python 3.13** 또는 해당 환경.",
      "setup_run_title": "실행 방법",
      "setup_run_python_install": "필수 의존성 설치:",
      "setup_run_node_install": "패키지 의존성 설치:",
      "setup_run_dotnet_build": ".NET CLI를 사용하여 프로젝트 빌드:",
      "setup_run_ahk": "AutoHotkey를 통해 스크립트 직접 실행:",
      "setup_run_run": "애플리케이션 실행:",
      "title_license": "라이센스",
      "license_body": "본 프로젝트는 **MIT 라이센스**에 따라 라이센스가 부여됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하십시오."
    }
  };
}
