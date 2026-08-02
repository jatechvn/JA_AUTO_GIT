# 📜 CHANGELOG - JA_Auto_Git

All notable changes to **JA_Auto_Git** will be documented in this file.

---

## [v1.7.0] - 2026-08-02

### 🚀 Major Features & Enhancements
- **🚀 Push Release Dialog:** New in-app dialog to tag, title, write notes, attach a binary asset, and publish a GitHub Release directly from a local project row.
- **⚙️ In-App Repository Settings:** The Cloud tab's Settings action now opens a full native dialog (General description/website, Features, Pull Request merge options, Danger Zone visibility toggle) instead of opening the GitHub web settings page.
- **🗂️ Cloud Row Actions Redesign:** Replaced the single "..." popup menu with dedicated icon buttons (Settings, Clone, Releases, Visibility, Rename, Delete) for faster access.
- **🔍 Smarter Local Scanner:** Distinguishes "weak" project kinds (bare `.bat`/`.ps1`/`.ahk` folders) from "strong" kinds (Dart, Python, Node, etc.) so workspace root folders are no longer misclassified as leaf projects.
- **📄 Dynamic README Structure Section:** The generated project structure tree now reflects the actual Dart project layout (`lib/models`, `lib/services`, `lib/widgets`) instead of always showing the Python layout.

- **🔔 Toast Notifications:** Success/failure confirmations (Rename, Delete, Clone, Visibility, Push Release, Repository Settings, Commit & Push) now surface as snackbar toasts, not just the console log.
- **🔄 Local Sync Column:** The Local Workspace table now shows an "↑ahead / ↓behind" indicator per project, computed from local refs only (no `git fetch` during scan, so scanning stays fast).
- **📊 Scan Delta Indicators:** Dashboard stat cards show the +/- change since the previous scan.
- **🩺 Health Check Panel:** Click the "Standard Git Form" stat card to see every project missing a standard file, with a one-click "Fix All".
- **📝 In-App .gitignore Editor:** Edit a project's real `.gitignore` directly from the Local tab, with a "Reset to Standard" merge helper.
- **🔔 Startup Update Checker:** The app checks its own GitHub Releases on launch and shows a dismissible banner when a newer version is available.
- **💀 Cloud Loading Skeleton:** Replaced the spinner with pulsing placeholder rows while fetching cloud repositories.

### 🛠️ Fixes
- Fixed Cloud project `url`/`is_private` fields being read from the wrong JSON keys, which broke the repo link and Private/Public badge.

### 🧹 Maintenance
- Removed dead code: unused `lib/modules/constants.dart` and `lib/modules/modules.dart` (stale duplicates/barrel file with no importers), unused `_isAuthenticating` field.
- `build_release.bat` now reads the app version from `pubspec.yaml` instead of a hard-coded string.
- Added unit tests for the scanner's weak/strong project classification and the local ahead/behind computation.

---

## [v1.6.0] - 2026-07-30

### 🚀 Major Features & Enhancements
- **🌐 Automated GitHub Cloud Fetching:**
  - The application now automatically scans and fetches your cloud repositories in the background on startup.
- **🗂️ Redesigned Cloud Data Table:**
  - Upgraded the Cloud Tab UI to a full-width **DataTable** with sortable columns: Project, Sync Status, Updated, Visibility, and Actions.
- **⚙️ Integrated Git Action Menu for Cloud:**
  - Added an interactive action menu to each cloud repository for quick web access, toggling visibility (Public/Private), renaming projects, and permanently deleting repositories.

---

## [v1.5.0] - 2026-07-28

### 🚀 Major Features & Enhancements
- **🌐 GitHub Cloud Tab & Account Management:**
  - Added dedicated **GitHub Cloud Repositories** tab with real-time repo listing, search, and cloning capabilities.
  - Added **Account Switching Modal Dialog** for logging out and logging in with different GitHub credentials.
  - Added **Automatic Directory Allocation:** Cloned repositories are automatically saved into `dist/Clone/[RepoName]` without cluttering the root folder.
  - Added **Delete Downloaded Clone Folder:** Easily delete downloaded clone directories directly from the UI with read-only file lock clearing.

- **📦 Full-Featured GitHub New Release Publishing:**
  - Complete Release modal matching GitHub web UI: **Tag Version**, **Target Branch**, **Release Title**, **Release Notes Editor**, **Release Label / Type** (Latest, Pre-release, Draft).
  - **Live Remote Doc Fetching:** Real-time fetching of `README.md`, `CHANGELOG.md`, GitHub AI Release Notes Generator, and recent Git Commits directly via GitHub API (`gh api`).
  - **Interactive Drag & Drop File Upload:** Drag and drop binary release assets (`.exe`, `.zip`, `.apk`, `.tar.gz`) directly into the release dialog with glowing visual feedback.
  - **Custom Rich Markdown & HTML Preview:** Live formatted rendering of Markdown headings, subheadings, Cyan bullet points, bold text, blockquotes, and code blocks.
  - **Clipboard Paste Buttons:** Quick paste buttons for Release Title and Release Notes.

- **🎨 UI/UX & Glassmorphism Design System:**
  - Custom Glassmorphism dialogs with real-time **Blur** and **Opacity** slider settings.
  - Curated dark/light themes with Cyan, GreenAccent, and Amber highlight palettes.
  - Clean floating console log drawer with multi-level color coding.

---

## [v1.0.0] - 2026-07-26
- Initial release converted to Dart & Flutter.
- Multi-repository workspace scanner and automated commit/push workflows.
