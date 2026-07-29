<div align="center">

  <img src="assets/images/icon.ico" width="96" height="96" alt="JA Auto Git Logo" />

  # 🤖 JA Auto Git
  
  ### *The Ultimate Glassmorphism Multi-Repository & GitHub Cloud Studio*

  [![Flutter](https://img.shields.io/badge/Flutter-v3.29.0-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-v3.7.0-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Platform](https://img.shields.io/badge/Platform-Windows_10_%7C_11-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://microsoft.com/windows)
  [![Release](https://img.shields.io/badge/Release-v1.5.0-00ADB5?style=for-the-badge&logo=github&logoColor=white)](https://github.com/jatechvn/JA_AUTO_GIT/releases)
  [![License](https://img.shields.io/badge/License-MIT-FFB100?style=for-the-badge)](LICENSE)

  <p align="center">
    <b>Automate workspace scanning • Manage GitHub Cloud • Publish Rich Releases with Drag & Drop</b>
  </p>

  ---

</div>

## 📑 Table of Contents

- [✨ Core Capabilities](#-core-capabilities)
- [🎨 Glassmorphism & UX Architecture](#-glassmorphism--ux-architecture)
- [📦 Release Management Suite](#-release-management-suite)
- [📐 Directory & Technical Architecture](#-directory--technical-architecture)
- [🚀 Quick Start Guide](#-quick-start-guide)
- [⚙️ Configuration & Settings](#%EF%B8%8F-configuration--settings)
- [📜 Changelog](#-changelog)
- [📄 License & Author](#-license--author)

---

## ✨ Core Capabilities

### ⚡ 1. Local Workspace Engine
* **Concurrent Repository Scanning:** Recursively scans workspace folders up to customized depth levels (`1` to `5` levels deep).
* **Smart Workspace Memory:** Automatically remembers the last selected workspace folder across app restarts.
* **Instant Selection Reset:** Changing target folder automatically clears stale project selections to prevent accidental batch operations.
* **Batch Git Standardization:** Instantly generates or updates standard project files (`.gitignore`, `LICENSE`, `README.md`, `git_push.bat`) across selected repos.
* **Batch Commit & Push:** One-click automated staging, commit writing, and pushing to remote branches with automatic `pull --rebase` conflict prevention.

### 🌐 2. GitHub Cloud Management Suite
* **Live Cloud Repositories:** Real-time fetching of all user and organizational repositories directly via embedded GitHub CLI (`gh.exe`).
* **Multi-Account Switching:** Switch GitHub user accounts on the fly with custom device authentication popups (`Device Code Flow`).
* **Structured Directory Allocation:** Automatically clones cloud repos directly into `dist/Clone/[RepoName]` without cluttering root directories.
* **Safe Clone Deletion:** Includes read-only file lock clearing to safely delete downloaded clone folders directly from the app interface.

---

## 🎨 Glassmorphism & UX Architecture

| Visual Feature | Description | Highlight |
| :--- | :--- | :--- |
| **Liquid Glass Design** | Translucent glassmorphism panels with customizable **Blur** (Sigma 0-30px) and **Opacity** (10-100%). | 💎 Premium Aesthetics |
| **Dual Theme System** | Curated Dark Glass and Light Glass color schemes tuned for high readability. | 🌓 Dark & Light |
| **Interactive Console Drawer** | Slide-out terminal log viewer with multi-level color coding (Cyan, Amber, Red). | 📟 Real-Time Logs |
| **Responsive Controls** | Instant search filter, status summary counters, and smooth micro-animations. | ⚡ Instant Filter |

---

## 📦 Release Management Suite

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        PUBLISH NEW RELEASE                              │
├────────────────────────────────────────────────────────────────────────┤
│ 🏷️ Auto Version Tag    │ Automatically detects v1.5.0 from CHANGELOG/pubspec │
│ 🌿 Target Branch       │ Configurable (main, master, release/v1.x)             │
│ 📋 Title & Copy Paste  │ One-click Clipboard Paste icons for Title & Notes      │
│ 🤖 Live Auto-Read Docs │ Reads CHANGELOG.md, README.md, & Git Commits live     │
│ 📂 Drag & Drop Zone    │ Drag .exe, .zip, .apk assets directly from Explorer    │
│ 👁️ Rich Markdown View  │ Render styled headings, Cyan bullet lists, & code      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📐 Directory & Technical Architecture

```text
JA_Auto_Git/
├── dist/                                  # Portable distribution folder
│   ├── ja_auto_git.exe                   # Main production Windows executable
│   ├── JA_Auto_Git_v1.5.0_Windows.zip    # Ready-to-publish release package
│   ├── Clone/                            # Dedicated sub-folder for cloned cloud repositories
│   └── bin/                              # Portable embedded tools
│       ├── git/                          # Portable Git 64-bit runtime
│       └── gh.exe                        # Official GitHub CLI tool
│
├── lib/                                   # Flutter / Dart source code
│   ├── main.dart                          # Application entry point & theme initializations
│   ├── dialogs.dart                       # Glassmorphism dialogs & Release publisher
│   ├── services/                          # Core service contracts
│   │   ├── git_service.dart               # Git CLI & GitHub REST API bridge
│   │   ├── scanner_service.dart           # Multithreaded workspace file scanner
│   │   └── settings_service.dart          # Persistent configuration manager
│   ├── modules/                           # Native Windows integrations & UI views
│   └── utils/                             # Constants, design tokens, & i18n helpers
│
├── assets/                                # Static visual branding assets & icons
├── CHANGELOG.md                           # Comprehensive version history log
├── README.md                              # Scientific project documentation
└── pubspec.yaml                           # Dependency definitions & Flutter manifest
```

---

## 🚀 Quick Start Guide

### Option A: Portable Run (No Installation Required)
1. Download the latest release package `JA_Auto_Git_v1.5.0_Windows.zip` from [Releases](https://github.com/jatechvn/JA_AUTO_GIT/releases).
2. Extract the archive to any location.
3. Run `dist/ja_auto_git.exe`. Embedded `git.exe` and `gh.exe` binaries run out of the box!

### Option B: Building from Source (Developers)

#### Prerequisites
* **Windows 10 / 11** (64-bit)
* **Flutter SDK v3.29.0+** & **Dart SDK v3.7.0+**
* **Visual Studio 2022 / Build Tools** (Desktop development with C++)

```bash
# 1. Clone source repository
git clone https://github.com/jatechvn/JA_AUTO_GIT.git
cd JA_AUTO_GIT

# 2. Install Flutter packages
flutter pub get

# 3. Launch live developer mode
flutter run -d windows

# 4. Compile standalone Windows Release executable
flutter build windows
```

---

## ⚙️ Configuration & Settings

The application persists user preferences in local JSON storage:

```json
{
  "license_author": "John Alaa",
  "max_depth": 3,
  "auto_create_repo": true,
  "repo_public": false,
  "bg_blur": 10.0,
  "bg_opacity": 0.6,
  "dialog_blur": 2.0,
  "dialog_opacity": 0.8
}
```

---

## 📜 Changelog

Refer to [CHANGELOG.md](CHANGELOG.md) for full version history details.

- **v1.5.0 (2026-07-28):** Added GitHub Cloud Release publisher, Drag & Drop binary attachment zone, auto-version tag detection, account switching dialog, and Glassmorphism blur/opacity sliders.
- **v1.0.0 (2026-07-26):** Initial Flutter/Dart architecture conversion and multi-repo workspace scanner.

---

## 📄 License & Author

Distributed under the **MIT License**. See [LICENSE](LICENSE) for details.

* **Author:** John Alaa (`jatechvn`)
* **Repository:** [https://github.com/jatechvn/JA_AUTO_GIT](https://github.com/jatechvn/JA_AUTO_GIT)
