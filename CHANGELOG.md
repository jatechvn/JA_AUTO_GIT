# 📜 CHANGELOG - JA_Auto_Git

All notable changes to **JA_Auto_Git** will be documented in this file.

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
