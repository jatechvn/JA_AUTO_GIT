// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../services/system_service.dart';

import 'styles.dart';
import 'dialogs.dart';
import 'release_dialogs.dart';
import 'repo_settings_dialog.dart';
import 'gitignore_editor_dialog.dart';
import 'health_check_dialog.dart';
import '../../models/project_info.dart';
import '../../services/settings_service.dart';
import '../../services/scanner_service.dart';
import '../../services/git_form_service.dart';
import '../../services/git_service.dart';
import '../../utils/constants.dart';
import '../../utils/i18n.dart';
import '../../utils/windows_info.dart';
import '../build_info.dart';
import '../logger_config.dart';
import '../native_bridge.dart';

enum ViewMode { table, grid }

class MainWindow extends StatefulWidget {
  final ThemeNotifier themeNotifier;

  const MainWindow({
    Key? key,
    required this.themeNotifier,
  }) : super(key: key);

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  AppColors get _c => widget.themeNotifier.colors;

  // Settings & state
  Map<String, dynamic> _settings = {};
  String _currentLang = 'en';
  bool _showHidden = false;

  // Delta vs. the previous scan, shown under the dashboard stat cards. Null = no baseline yet.
  int? _deltaTotal;
  int? _deltaGit;
  int? _deltaStandard;
  int? _deltaDirty;
  int? _deltaCloud;
  ViewMode _viewMode = ViewMode.table;
  bool _isGithubLoggedIn = false;

  // Controllers
  final _rootCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _consoleScrollCtrl = ScrollController();

  // Lists
  List<ProjectInfo> _localProjects = [];
  List<CloudProjectInfo> _cloudProjects = [];

  // Selection sets
  final Set<String> _selectedLocalPaths = {};
  final Set<String> _selectedCloudUrls = {};
  final Set<String> _hiddenProjects = {};

  // Statuses
  bool _scanningLocal = false;
  bool _scanningCloud = false;
  String _statusMessage = 'Ready';
  final List<String> _consoleLogs = [];

  // Active filters
  String _localFilter = 'all'; // all, has_git, no_git, missing_form, dirty
  String _searchQuery = '';
  String _selectedKindFilter = 'all';

  // Console visibility
  bool _showConsole = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() async {
      if (_tabCtrl.index == 1 && !_tabCtrl.indexIsChanging) {
        if (_ownerCtrl.text.trim().isEmpty) {
          final uname = await GitService.getGithubUsername();
          if (uname.isNotEmpty && mounted) {
            setState(() {
              _ownerCtrl.text = uname;
            });
          }
        }
        if (_cloudProjects.isEmpty && _ownerCtrl.text.trim().isNotEmpty) {
          _scanCloud();
        }
      }
    });
    LoggerConfig.init(debug: BuildInfo.isDebug);
    _loadSettingsAndScan();
  }

  Future<void> _loadSettingsAndScan() async {
    final settings = SettingsService.loadSettings();
    final loggedIn = await GitService.isGithubLoggedIn();
    String owner = settings['remote_base'] ?? '';
    if (owner.isEmpty && loggedIn) {
      owner = await GitService.getGithubUsername();
    }
    setState(() {
      _isGithubLoggedIn = loggedIn;
      _settings = settings;
      _currentLang = settings['last_lang'] ?? 'en';
      _rootCtrl.text = settings['last_root'] ?? '';
      _ownerCtrl.text = owner;
      _msgCtrl.text = settings['commit_message'] ?? '';
      _authorCtrl.text = settings['license_author'] ?? 'John Alaa';

      _selectedLocalPaths.clear();
      _selectedLocalPaths.addAll(List<String>.from(settings['last_selected_projects'] ?? []));
      _selectedCloudUrls.clear();
      _selectedCloudUrls.addAll(List<String>.from(settings['last_selected_cloud_projects'] ?? []));
      _hiddenProjects.clear();
      _hiddenProjects.addAll(List<String>.from(settings['hidden_projects'] ?? []));
      _statusMessage = I18n.t(_currentLang, "status_waiting");
    });

    if (_rootCtrl.text.isNotEmpty && Directory(_rootCtrl.text).existsSync()) {
      _scanLocal();
    }
    
    if (_isGithubLoggedIn && _ownerCtrl.text.isNotEmpty) {
      _scanCloud();
    }

    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    try {
      final tag = await GitService.getLatestReleaseTag(AppConstants.updateCheckOwner, AppConstants.updateCheckRepo);
      if (tag.isEmpty || !mounted) return;

      final latest = tag.replaceFirst(RegExp(r'^v'), '');
      if (latest == (_settings['dismissed_update_version'] ?? '')) return;
      if (!_isNewerVersion(latest, AppConstants.appVersion)) return;

      _showUpdateBanner(latest);
    } catch (_) {
      // Silent — update checking is a best-effort background nicety.
    }
  }

  bool _isNewerVersion(String latest, String current) {
    final l = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv != cv) return lv > cv;
    }
    return false;
  }

  void _showUpdateBanner(String latest) {
    final isVi = _currentLang == 'vi';
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        backgroundColor: _c.bgTertiary,
        leading: const Icon(Icons.system_update_alt, color: AppConstants.accentCyan),
        content: Text(
          isVi ? "Bản mới v$latest đã có sẵn (đang dùng v${AppConstants.appVersion})." : "A new version v$latest is available (you're on v${AppConstants.appVersion}).",
          style: TextStyle(color: _c.textPrimary, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => SystemService.openUrl("https://github.com/${AppConstants.updateCheckOwner}/${AppConstants.updateCheckRepo}/releases/latest"),
            child: Text(isVi ? "XEM" : "VIEW", style: const TextStyle(color: AppConstants.accentCyan, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              final updated = {..._settings, 'dismissed_update_version': latest};
              setState(() => _settings = updated);
              SettingsService.saveSettings(updated);
            },
            child: Text(isVi ? "BỎ QUA" : "DISMISS", style: TextStyle(color: _c.textMuted)),
          ),
        ],
      ),
    );
  }

  void _saveCurrentSettings() {
    final updated = Map<String, dynamic>.from(_settings);
    updated['last_root'] = _rootCtrl.text.trim();
    updated['remote_base'] = _ownerCtrl.text.trim();
    updated['commit_message'] = _msgCtrl.text;
    updated['license_author'] = _authorCtrl.text;
    updated['last_selected_projects'] = _selectedLocalPaths.toList();
    updated['last_selected_cloud_projects'] = _selectedCloudUrls.toList();
    updated['last_lang'] = _currentLang;
    updated['hidden_projects'] = _hiddenProjects.toList();
    updated['theme'] = widget.themeNotifier.mode == AppThemeMode.dark
        ? 'dark'
        : (widget.themeNotifier.mode == AppThemeMode.light ? 'light' : 'system');
    _settings = updated;
    SettingsService.saveSettings(updated);
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? Colors.redAccent : AppConstants.accentGreen, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _addLog(String msg, {String level = 'INFO'}) {
    LoggerConfig.log(msg, level: level);
    setState(() {
      _consoleLogs.add('[${DateTime.now().toString().substring(11, 19)}] [$level] $msg');
    });
    if (_consoleScrollCtrl.hasClients) {
      _consoleScrollCtrl.animateTo(
        _consoleScrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _scanLocal() async {
    final path = _rootCtrl.text.trim();
    if (path.isEmpty || !Directory(path).existsSync()) return;

    _saveCurrentSettings();

    setState(() {
      _scanningLocal = true;
      _statusMessage = I18n.t(_currentLang, "status_scanning_local");
    });
    _addLog("Starting local directory scan: $path");

    try {
      final list = await ScannerService.scanProjects(path);
      nativeAgent.executeHeavyTask("Scanned ${list.length} items");

      final newGit = list.where((p) => p.hasGit).length;
      final newStandard = list.where((p) => p.standardOk).length;
      final newDirty = list.where((p) => !p.clean).length;

      final prevTotal = _settings['last_scan_total'] as int? ?? -1;
      final prevGit = _settings['last_scan_git'] as int? ?? -1;
      final prevStandard = _settings['last_scan_standard'] as int? ?? -1;
      final prevDirty = _settings['last_scan_dirty'] as int? ?? -1;

      setState(() {
        _localProjects = list;
        _scanningLocal = false;
        _statusMessage = I18n.t(_currentLang, "status_done");
        _deltaTotal = prevTotal >= 0 ? list.length - prevTotal : null;
        _deltaGit = prevGit >= 0 ? newGit - prevGit : null;
        _deltaStandard = prevStandard >= 0 ? newStandard - prevStandard : null;
        _deltaDirty = prevDirty >= 0 ? newDirty - prevDirty : null;
        _settings = {
          ..._settings,
          'last_scan_total': list.length,
          'last_scan_git': newGit,
          'last_scan_standard': newStandard,
          'last_scan_dirty': newDirty,
        };
      });
      SettingsService.saveSettings(_settings);
      _addLog("Local scan complete. Found ${list.length} projects.", level: 'SUCCESS');
    } catch (e) {
      setState(() {
        _scanningLocal = false;
        _statusMessage = "Scan error: $e";
      });
      _addLog("Scan error: $e", level: 'ERROR');
    }
  }

  Future<bool> _ensureGithubAuth() async {
    final loggedIn = await GitService.isGithubLoggedIn();
    if (!loggedIn) {
      if (!mounted) return false;
      final res = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => GithubAuthGuiDialog(isDark: widget.themeNotifier.isDark, lang: _currentLang),
      );
      if (res == 'login') {
        _addLog("GitHub login successful via GUI.", level: 'INFO');
        setState(() => _isGithubLoggedIn = true);
        return true;
      }
      return false;
    }
    return true;
  }

  Future<void> _scanCloud() async {
    final owner = _ownerCtrl.text.trim();
    if (owner.isEmpty) return;

    final authed = await _ensureGithubAuth();
    if (!authed) return;

    setState(() {
      _scanningCloud = true;
      _statusMessage = I18n.t(_currentLang, "status_scanning_cloud");
    });
    _addLog("Fetching cloud repos for $owner");

    try {
      final repos = await GitService.getRemoteRepos(owner, log: (m) => _addLog(m));
      final root = _rootCtrl.text.trim();

      List<CloudProjectInfo> result = [];
      for (var r in repos) {
        final name = r['name'] ?? '';
        final htmlUrl = r['url'] ?? '';
        final updatedAt = r['updated_at'] ?? '';
        final isPrivate = r['is_private'] ?? false;
        final localPath = "$root/$name";

        String syncStatus = "Not Cloned";
        if (Directory(localPath).existsSync()) {
          final isBehind = await GitService.isBehindRemote(localPath);
          final clean = await GitService.isClean(localPath);
          if (isBehind) {
            syncStatus = "Needs Pull";
          } else if (!clean) {
            syncStatus = "Local Modified";
          } else {
            syncStatus = "Up to date";
          }
        }

        result.add(CloudProjectInfo(
          name: name,
          kind: 'Git',
          url: htmlUrl,
          updatedAt: updatedAt,
          localPath: localPath,
          syncStatus: syncStatus,
          isPrivate: isPrivate,
        ));
      }

      final prevCloud = _settings['last_scan_cloud'] as int? ?? -1;
      setState(() {
        _cloudProjects = result;
        _scanningCloud = false;
        _statusMessage = "Found ${result.length} cloud repositories.";
        _deltaCloud = prevCloud >= 0 ? result.length - prevCloud : null;
        _settings = {..._settings, 'last_scan_cloud': result.length};
      });
      SettingsService.saveSettings(_settings);
      _addLog("Cloud scan complete. ${result.length} repos found.", level: 'SUCCESS');
    } catch (e) {
      setState(() {
        _scanningCloud = false;
        _statusMessage = "Cloud error: $e";
      });
      _addLog("Cloud scan failed: $e", level: 'ERROR');
    }
  }

  void _applyPresetMessage(String msg) {
    setState(() {
      _msgCtrl.text = msg;
    });
  }

  // Filtered Local Projects
  List<ProjectInfo> get _filteredLocalProjects {
    return _localProjects.where((p) {
      if (!_showHidden && _hiddenProjects.contains(p.path)) return false;

      // Category filter
      if (_localFilter == 'has_git' && !p.hasGit) return false;
      if (_localFilter == 'no_git' && p.hasGit) return false;
      if (_localFilter == 'missing_form' && p.standardOk) return false;
      if (_localFilter == 'dirty' && p.clean) return false;

      // Kind filter
      if (_selectedKindFilter != 'all' && p.kind.toLowerCase() != _selectedKindFilter.toLowerCase()) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return p.name.toLowerCase().contains(q) || p.path.toLowerCase().contains(q) || p.kind.toLowerCase().contains(q);
      }

      return true;
    }).toList();
  }

  // Stats calculation
  int get _countGit => _localProjects.where((p) => p.hasGit).length;
  int get _countStandardOk => _localProjects.where((p) => p.standardOk).length;
  int get _countDirty => _localProjects.where((p) => !p.clean).length;

  @override
  Widget build(BuildContext context) {
    final double bgBlur = _settings['bg_blur'] ?? 10.0;
    final double bgOpacity = _settings['bg_opacity'] ?? 0.6;
    final enableTransparency = Platform.isWindows && WindowsInfo.isWindows11OrGreater;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: bgBlur, sigmaY: bgBlur),
        child: Container(
          color: enableTransparency ? _c.bgPrimary.withOpacity(bgOpacity) : _c.bgPrimary,
          child: SafeArea(
            child: Column(
              children: [
                _buildCustomHeader(),
                _buildStatsOverviewBar(),
                _buildControlBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildLocalTabContent(),
                      _buildCloudTabContent(),
                    ],
                  ),
                ),
                if (_selectedLocalPaths.isNotEmpty && _tabCtrl.index == 0) _buildBatchFloatingBar(),
                _buildConsoleDrawer(),
                _buildStatusBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Custom Header App Bar
  Widget _buildCustomHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _c.bgSecondary.withOpacity(0.4),
        border: Border(bottom: BorderSide(color: _c.borderDefault, width: 0.5)),
      ),
      child: Row(
        children: [
          // App Brand & Logo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppConstants.accentCyan.withOpacity(0.3), AppConstants.accentPurple.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppConstants.accentCyan.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(color: AppConstants.accentCyan.withOpacity(0.2), blurRadius: 8),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppConstants.appName,
                style: TextStyle(
                  color: _c.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  fontFamily: AppConstants.fontPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                children: [
                  BlinkingDot(size: 6, color: BuildInfo.isDebug ? Colors.amber : AppConstants.accentGreen),
                  const SizedBox(width: 6),
                  Text(
                    BuildInfo.badgeLabel,
                    style: TextStyle(
                      color: BuildInfo.isDebug ? Colors.amber : AppConstants.accentCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: AppConstants.fontMono,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Right side (Tabs, View Mode, Settings, GITHUB, Lang) wrapped in scrollable view to prevent squeezing
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Navigation Tabs
                    SizedBox(
                      width: 280,
                      height: 32,
                      child: TabBar(
                        controller: _tabCtrl,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: AppConstants.accentCyan.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppConstants.accentCyan.withOpacity(0.5)),
                        ),
                        labelColor: AppConstants.accentCyan,
                        unselectedLabelColor: _c.textSecondary,
                        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        tabs: [
                          Tab(text: "🗂️ ${I18n.t(_currentLang, "tab_local")}"),
                          Tab(text: "☁️ ${I18n.t(_currentLang, "tab_cloud")}"),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // View Mode Switcher
                    IconButton(
                      tooltip: _viewMode == ViewMode.table ? "Switch to Grid Cards" : "Switch to Compact Table",
                      icon: Icon(
                        _viewMode == ViewMode.table ? Icons.grid_view_rounded : Icons.table_rows_rounded,
                        color: AppConstants.accentCyan,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          _viewMode = _viewMode == ViewMode.table ? ViewMode.grid : ViewMode.table;
                        });
                      },
                    ),

                    // Settings & User Guide Button
                    IconButton(
            tooltip: _currentLang == 'vi' ? "Cài đặt & Hướng dẫn (About)" : "Settings & Guide (About)",
            icon: const Icon(
              Icons.settings_rounded,
              color: AppConstants.accentCyan,
              size: 18,
            ),
            onPressed: () async {
              final updated = await showDialog<bool>(
                context: context,
                builder: (_) => SettingsDialog(
                  isDark: widget.themeNotifier.isDark,
                  lang: _currentLang,
                  settings: _settings,
                ),
              );
              if (updated == true) {
                _loadSettingsAndScan();
              }
            },
          ),
          const SizedBox(width: 4),

          // Theme Switcher
          IconButton(
            tooltip: "Switch Theme (Light/Dark/Auto)",
            icon: Icon(
              widget.themeNotifier.mode == AppThemeMode.dark
                  ? Icons.dark_mode_rounded
                  : (widget.themeNotifier.mode == AppThemeMode.light ? Icons.light_mode_rounded : Icons.brightness_auto_rounded),
              color: _c.textPrimary,
              size: 18,
            ),
            onPressed: () => widget.themeNotifier.cycleTheme(),
          ),

          // GitHub Auth Status & Account Switcher
          Tooltip(
            message: _isGithubLoggedIn 
                ? (_currentLang == 'vi' ? "Tài khoản GitHub (Nhấn để quản lý / đăng xuất)" : "GitHub Account (Click to manage / logout)") 
                : (_currentLang == 'vi' ? "Chưa đăng nhập GitHub (Nhấn để đăng nhập)" : "GitHub Not Logged In (Click to login)"),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                if (!_isGithubLoggedIn) {
                  await _ensureGithubAuth();
                } else {
                  final info = await GitService.getGithubAccountInfo();
                  if (!mounted) return;
                  final action = await showDialog<String>(
                    context: context,
                    builder: (_) => GithubAccountDialog(
                      isDark: widget.themeNotifier.isDark,
                      lang: _currentLang,
                      accountInfo: info,
                    ),
                  );
                  if (action == 'logout' || action == 'switch') {
                    setState(() {
                      _isGithubLoggedIn = false;
                    });
                    _addLog(_currentLang == 'vi' ? "Đã đăng xuất GitHub." : "Logged out from GitHub.", level: 'INFO');
                    if (action == 'switch') {
                      await _ensureGithubAuth();
                    }
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _c.bgTertiary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _isGithubLoggedIn ? AppConstants.accentGreen.withOpacity(0.5) : _c.borderDefault),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isGithubLoggedIn ? Icons.check_circle : Icons.cancel,
                      color: _isGithubLoggedIn ? AppConstants.accentGreen : Colors.redAccent,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "GITHUB",
                      style: TextStyle(color: _c.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Language Cycle Switcher
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () {
              setState(() {
                if (_currentLang == 'en') {
                  _currentLang = 'vi';
                } else if (_currentLang == 'vi') {
                  _currentLang = 'zh-cn';
                } else {
                  _currentLang = 'en';
                }
                _statusMessage = I18n.t(_currentLang, "status_waiting");
                SettingsService.saveSettings({'last_lang': _currentLang});
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _c.bgTertiary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _c.borderDefault),
              ),
              child: Row(
                children: [
                  const Icon(Icons.language, size: 14, color: AppConstants.accentCyan),
                  const SizedBox(width: 4),
                  Text(
                    (_currentLang == 'zh-cn' ? 'ZH' : _currentLang).toUpperCase(),
                    style: TextStyle(color: _c.textPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  ],
              ),
            ),
          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Dashboard Summary Header Cards
  Widget _buildStatsOverviewBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildStatCard(I18n.t(_currentLang, "tab_local"), "${_localProjects.length}", Icons.folder_copy_outlined, AppConstants.accentCyan, delta: _deltaTotal),
          const SizedBox(width: 12),
          _buildStatCard(I18n.t(_currentLang, "btn_check_has_git"), "$_countGit", Icons.account_tree_outlined, AppConstants.accentGreen, delta: _deltaGit),
          const SizedBox(width: 12),
          _buildStatCard(
            I18n.t(_currentLang, "grp_standard"),
            "$_countStandardOk/${_localProjects.length}",
            Icons.verified_outlined,
            Colors.purpleAccent,
            delta: _deltaStandard,
            onTap: _localProjects.isEmpty
                ? null
                : () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => HealthCheckDialog(
                        projects: _localProjects,
                        authorName: _authorCtrl.text,
                        remoteBaseUrl: _ownerCtrl.text,
                        isDark: widget.themeNotifier.mode == AppThemeMode.dark,
                        lang: _currentLang,
                      ),
                    );
                    if (ok == true) {
                      _showToast(_currentLang == 'vi' ? "Đã áp dụng chuẩn cho các dự án còn thiếu" : "Applied standard forms to the flagged projects");
                      _scanLocal();
                    }
                  },
          ),
          const SizedBox(width: 12),
          _buildStatCard(I18n.t(_currentLang, "status_local_modified"), "$_countDirty", Icons.difference_outlined, Colors.amber, delta: _deltaDirty),
          const SizedBox(width: 12),
          _buildStatCard(I18n.t(_currentLang, "tab_cloud"), "${_cloudProjects.length}", Icons.cloud_done_outlined, Colors.blueAccent, delta: _deltaCloud),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color accent, {int? delta, VoidCallback? onTap}) {
    final card = GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 14,
        borderColor: accent.withOpacity(0.3),
        backgroundColor: _c.bgCard.withOpacity(0.6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        value,
                        style: TextStyle(color: _c.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, fontFamily: AppConstants.fontPrimary),
                      ),
                      if (delta != null && delta != 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          delta > 0 ? "+$delta" : "$delta",
                          style: TextStyle(
                            color: delta > 0 ? AppConstants.accentGreen : Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
    );

    return Expanded(
      child: onTap != null
          ? InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: card)
          : card,
    );
  }

  // Control & Search Bar
  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _c.bgSecondary,
        border: Border(bottom: BorderSide(color: _c.borderDefault, width: 0.5)),
      ),
      child: Column(
        children: [
          // Path input & Owner Input Row
          Row(
            children: [
              // Root directory picker
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _rootCtrl,
                    style: TextStyle(color: _c.textPrimary, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "Target Root Directory Path...",
                      hintStyle: TextStyle(color: _c.textMuted, fontSize: 11),
                      prefixIcon: const Icon(Icons.folder_open, size: 16, color: AppConstants.accentCyan),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.folder, size: 14, color: AppConstants.accentCyan),
                        onPressed: () async {
                          final selected = await SystemService.pickDirectory();
                          if (selected != null) {
                            setState(() {
                              _rootCtrl.text = selected;
                              _selectedLocalPaths.clear();
                            });
                            _saveCurrentSettings();
                            _scanLocal();
                          }
                        },
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: _c.bgTertiary,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _c.borderDefault)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.accentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _scanningLocal ? null : _scanLocal,
                  icon: const Icon(Icons.search, size: 14),
                  label: Text(_scanningLocal ? "..." : I18n.t(_currentLang, "btn_scan"), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),

              // Remote GitHub Owner
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _ownerCtrl,
                    style: TextStyle(color: _c.textPrimary, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "GitHub Owner / Org Username...",
                      hintStyle: TextStyle(color: _c.textMuted, fontSize: 11),
                      prefixIcon: const Icon(Icons.cloud_sync_outlined, size: 16, color: Colors.blueAccent),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: _c.bgTertiary,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _c.borderDefault)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: _scanningCloud ? null : _scanCloud,
                  icon: const Icon(Icons.cloud_download_outlined, size: 14),
                  label: Text(_scanningCloud ? "..." : I18n.t(_currentLang, "btn_scan_cloud"), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Preset Commit Message & Search Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Search input
                SizedBox(
                  width: 240,
                  height: 30,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: _c.textPrimary, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "Instant search projects...",
                      hintStyle: TextStyle(color: _c.textMuted, fontSize: 10),
                      prefixIcon: const Icon(Icons.filter_alt_outlined, size: 14, color: AppConstants.accentCyan),
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      filled: true,
                      fillColor: _c.bgTertiary,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _c.borderDefault)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Filter pills
                _buildFilterChip(I18n.t(_currentLang, "btn_check_all"), 'all'),
                _buildFilterChip(I18n.t(_currentLang, "btn_check_has_git"), 'has_git'),
                _buildFilterChip(I18n.t(_currentLang, "btn_check_no_git"), 'no_git'),
                _buildFilterChip(I18n.t(_currentLang, "btn_check_missing_form"), 'missing_form'),
                _buildFilterChip(I18n.t(_currentLang, "status_local_modified"), 'dirty'),

                const SizedBox(width: 16),

                // Preset Commit Message Chips
                Text("Preset Msg: ", style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                _buildPresetChip("feat: initial commit"),
                _buildPresetChip("fix: dependencies"),
                _buildPresetChip("docs: update README"),
                _buildPresetChip("chore: release bump"),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String code) {
    final isSelected = _localFilter == code;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 10, color: isSelected ? Colors.black : _c.textPrimary)),
        selected: isSelected,
        selectedColor: AppConstants.accentCyan,
        backgroundColor: _c.bgTertiary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        onSelected: (val) {
          if (val) setState(() => _localFilter = code);
        },
      ),
    );
  }

  Widget _buildPresetChip(String msg) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: InkWell(
        onTap: () => _applyPresetMessage(msg),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppConstants.accentPurple.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppConstants.accentPurple.withOpacity(0.3)),
          ),
          child: Text(
            msg,
            style: const TextStyle(color: AppConstants.accentPurple, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // Local Tab Content (Table / Grid Mode)
  Widget _buildLocalTabContent() {
    if (_scanningLocal) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppConstants.accentCyan),
            const SizedBox(height: 12),
            Text("Scanning local projects...", style: TextStyle(color: _c.textSecondary)),
          ],
        ),
      );
    }

    final projects = _filteredLocalProjects;
    if (projects.isEmpty) {
      return Center(
        child: Text("No local projects match the current filter.", style: TextStyle(color: _c.textMuted)),
      );
    }

    if (_viewMode == ViewMode.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
          childAspectRatio: 1.4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: projects.length,
        itemBuilder: (context, index) => _buildProjectCard(projects[index]),
      );
    }

    // Data Table View
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 36,
                dataRowHeight: 40,
                columnSpacing: 24,
                columns: [
                  DataColumn(label: Text(I18n.translateList(_currentLang, "tree_headers")[0].toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(I18n.translateList(_currentLang, "tree_headers")[1].toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(I18n.translateList(_currentLang, "tree_headers")[4].toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text((_currentLang == 'vi' ? "ĐỒNG BỘ" : "SYNC"), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(I18n.translateList(_currentLang, "tree_headers")[2].toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(I18n.t(_currentLang, "grp_standard").toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(I18n.translateList(_currentLang, "tree_headers")[11].toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(I18n.t(_currentLang, "btn_more").toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
                rows: projects.map((proj) {
            final isSelected = _selectedLocalPaths.contains(proj.path);
            return DataRow(
              selected: isSelected,
              onSelectChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedLocalPaths.add(proj.path);
                  } else {
                    _selectedLocalPaths.remove(proj.path);
                  }
                });
              },
              cells: [
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(proj.name, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 11)),
                      Text(proj.path, style: TextStyle(color: _c.textMuted, fontSize: 9)),
                    ],
                  ),
                ),
                DataCell(_buildKindBadge(proj.kind)),
                DataCell(
                  proj.hasGit
                      ? Text(proj.branch.isEmpty ? "main" : proj.branch, style: const TextStyle(color: AppConstants.accentGreen, fontSize: 10, fontWeight: FontWeight.bold))
                      : Text("No Git", style: TextStyle(color: _c.textMuted, fontSize: 10)),
                ),
                DataCell(_buildSyncBadge(proj)),
                DataCell(Text(proj.version.isEmpty ? "1.0.0" : proj.version, style: TextStyle(color: _c.textSecondary, fontSize: 10))),
                DataCell(_buildChecklistBadges(proj)),
                DataCell(_buildCleanBadge(proj.clean)),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_note, size: 16, color: AppConstants.accentCyan),
                        tooltip: "Apply Standard Forms",
                        onPressed: () {
                          GitFormService.ensureStandardForms(
                            path: proj.path,
                            projectName: proj.name,
                            kind: proj.kind,
                            authorName: _authorCtrl.text,
                            remoteBaseUrl: _ownerCtrl.text,
                          );
                          _scanLocal();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.block_flipped, size: 16, color: Colors.orangeAccent),
                        tooltip: ".gitignore",
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => GitignoreEditorDialog(
                              projectPath: proj.path,
                              kind: proj.kind,
                              isDark: widget.themeNotifier.mode == AppThemeMode.dark,
                              lang: _currentLang,
                            ),
                          );
                          if (ok == true) {
                            _showToast(_currentLang == 'vi' ? "Đã lưu .gitignore cho ${proj.name}" : "Saved .gitignore for ${proj.name}");
                            _scanLocal();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open, size: 16, color: Colors.amber),
                        tooltip: "Open Directory",
                        onPressed: () {
                          if (Platform.isWindows) {
                            Process.run('explorer.exe', [proj.path]);
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.rocket_launch, size: 16, color: Colors.purpleAccent),
                        tooltip: "Push Release",
                        onPressed: () async {
                          final ok = await showDialog(
                            context: context,
                            builder: (_) => PushReleaseDialog(
                              owner: _ownerCtrl.text.trim(),
                              projectName: proj.name,
                              localPath: proj.path,
                              isDark: widget.themeNotifier.mode == AppThemeMode.dark,
                              lang: _currentLang,
                            ),
                          );
                          if (ok == true) {
                            _showToast(_currentLang == 'vi' ? "Đã phát hành release cho ${proj.name}" : "Release published for ${proj.name}");
                            _scanLocal();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
            }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  // Visual Glass Card Grid View Item
  Widget _buildProjectCard(ProjectInfo proj) {
    final isSelected = _selectedLocalPaths.contains(proj.path);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedLocalPaths.remove(proj.path);
          } else {
            _selectedLocalPaths.add(proj.path);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.accentCyan.withOpacity(0.12) : _c.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppConstants.accentCyan : _c.borderDefault, width: isSelected ? 1.5 : 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildKindBadge(proj.kind),
                const Spacer(),
                _buildCleanBadge(proj.clean),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              proj.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              proj.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _c.textMuted, fontSize: 9),
            ),
            const Spacer(),
            _buildChecklistBadges(proj),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.account_tree_outlined, size: 12, color: proj.hasGit ? AppConstants.accentGreen : _c.textMuted),
                const SizedBox(width: 4),
                Text(
                  proj.hasGit ? (proj.branch.isEmpty ? "main" : proj.branch) : "No Git",
                  style: TextStyle(color: proj.hasGit ? AppConstants.accentGreen : _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text("v${proj.version.isEmpty ? '1.0.0' : proj.version}", style: TextStyle(color: _c.textMuted, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKindBadge(String kind) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppConstants.accentCyan.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppConstants.accentCyan.withOpacity(0.3)),
      ),
      child: Text(
        kind.toUpperCase(),
        style: const TextStyle(color: AppConstants.accentCyan, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCleanBadge(bool clean) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (clean ? Colors.green : Colors.amber).withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: (clean ? Colors.green : Colors.amber).withOpacity(0.3)),
      ),
      child: Text(
        clean ? "CLEAN" : "DIRTY",
        style: TextStyle(color: clean ? Colors.green : Colors.amber, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildChecklistBadges(ProjectInfo p) {
    return Row(
      children: [
        _checkIcon("Git", p.hasGit),
        _checkIcon("Ignore", p.gitignoreOk),
        _checkIcon("Push", p.pushBatOk),
        _checkIcon("MD", p.readmeOk),
        _checkIcon("LIC", p.licenseOk),
        _checkIcon("ABT", p.aboutOk),
      ],
    );
  }

  Widget _buildSyncBadge(ProjectInfo proj) {
    if (!proj.hasGit || !proj.hasRemote) {
      return Text("—", style: TextStyle(color: _c.textMuted, fontSize: 10));
    }
    if (proj.ahead == 0 && proj.behind == 0) {
      return Tooltip(
        message: _currentLang == 'vi' ? "Đồng bộ với remote" : "In sync with remote",
        child: Icon(Icons.check_circle_outline, size: 14, color: AppConstants.accentGreen),
      );
    }
    return Tooltip(
      message: _currentLang == 'vi'
          ? "Tính từ lần fetch/pull/push gần nhất, có thể chưa cập nhật realtime"
          : "Based on the last fetch/pull/push, may not reflect the live remote",
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (proj.ahead > 0)
            Text("↑${proj.ahead}", style: const TextStyle(color: AppConstants.accentGreen, fontSize: 10, fontWeight: FontWeight.bold)),
          if (proj.ahead > 0 && proj.behind > 0) const SizedBox(width: 4),
          if (proj.behind > 0)
            Text("↓${proj.behind}", style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCloudSkeletonRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SkeletonBar(width: 180, height: 14),
          const SizedBox(width: 32),
          const SkeletonBar(width: 90, height: 14),
          const SizedBox(width: 32),
          const SkeletonBar(width: 70, height: 14),
          const SizedBox(width: 32),
          const SkeletonBar(width: 60, height: 14),
          const Spacer(),
          const SkeletonBar(width: 140, height: 14),
        ],
      ),
    );
  }

  Widget _checkIcon(String label, bool ok) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: "$label: ${ok ? 'OK' : 'Missing'}",
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: (ok ? Colors.green : Colors.red).withOpacity(0.15),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(color: ok ? Colors.green : Colors.red, fontSize: 7, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // Cloud Tab Content
  Widget _buildCloudTabContent() {
    if (_scanningCloud) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: List.generate(6, (i) => _buildCloudSkeletonRow()),
        ),
      );
    }

    if (_cloudProjects.isEmpty) {
      return Center(
        child: Text("No cloud repositories fetched. Enter owner and click 'Fetch Cloud'.", style: TextStyle(color: _c.textMuted)),
      );
    }

    final isVi = _currentLang == 'vi';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 36,
                dataRowHeight: 48,
                columnSpacing: 24,
                columns: [
                  DataColumn(label: Text(I18n.translateList(_currentLang, "tree_headers")[0].toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(I18n.translateList(_currentLang, "tree_headers")[11].toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(isVi ? "CẬP NHẬT" : "UPDATED", style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text(isVi ? "QUYỀN" : "VISIBILITY", style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                  DataColumn(label: Text((isVi ? "CHỨC NĂNG" : "ACTIONS").toUpperCase(), style: TextStyle(color: _c.textMuted, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
                rows: _cloudProjects.map((cp) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            Icon(Icons.language, size: 16, color: _c.textMuted),
                            const SizedBox(width: 8),
                            Text(cp.name, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      DataCell(
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppConstants.accentCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(cp.syncStatus, style: const TextStyle(color: AppConstants.accentCyan, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(cp.updatedAt.isNotEmpty && cp.updatedAt.length > 10 ? cp.updatedAt.substring(0, 10) : cp.updatedAt, style: TextStyle(color: _c.textSecondary, fontSize: 11)),
                      ),
                      DataCell(
                        Text(cp.isPrivate ? 'Private' : 'Public', style: TextStyle(color: cp.isPrivate ? Colors.amber : Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.open_in_new, size: 16, color: Colors.blueAccent),
                              tooltip: isVi ? "Mở trong trình duyệt" : "Open in Browser",
                              onPressed: () => SystemService.openUrl(cp.url),
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings, size: 16, color: Colors.grey),
                              tooltip: isVi ? "Cài đặt Repository" : "Repository Settings",
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => RepoSettingsDialog(
                                    owner: _ownerCtrl.text.trim(),
                                    projectName: cp.name,
                                    isDark: widget.themeNotifier.mode == AppThemeMode.dark,
                                    lang: _currentLang,
                                  ),
                                );
                                if (ok == true) {
                                  _showToast(isVi ? "Đã lưu cài đặt repository ${cp.name}" : "Repository settings saved for ${cp.name}");
                                  _scanCloud();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.download, size: 16, color: AppConstants.accentGreen),
                              tooltip: isVi ? "Clone xuống máy" : "Clone Repository",
                              onPressed: () async {
                                final root = _rootCtrl.text.trim();
                                if (root.isEmpty) return;
                                setState(() => _scanningCloud = true);
                                final task = {
                                  'action_type': 'clone',
                                  'repo_name': cp.name,
                                  'repo_url': cp.url,
                                  'local_path': "$root/Clone/${cp.name}"
                                };
                                await GitService.syncCloudProject(task, _addLog);
                                setState(() => _scanningCloud = false);
                                _showToast(isVi ? "Đã clone ${cp.name}" : "Cloned ${cp.name}");
                                _scanLocal();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.archive, size: 16, color: Colors.purpleAccent),
                              tooltip: isVi ? "Xem Releases" : "View Releases",
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ListReleasesDialog(
                                    owner: _ownerCtrl.text.trim(),
                                    projectName: cp.name,
                                    isDark: widget.themeNotifier.mode == AppThemeMode.dark,
                                    lang: _currentLang,
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(cp.isPrivate ? Icons.public : Icons.lock, size: 16, color: Colors.amber),
                              tooltip: isVi ? "Đổi sang ${cp.isPrivate ? 'Public' : 'Private'}" : "Change to ${cp.isPrivate ? 'Public' : 'Private'}",
                              onPressed: () async {
                                final newVis = cp.isPrivate ? 'public' : 'private';
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(isVi ? "Thay Đổi Quyền" : "Change Visibility"),
                                    content: Text(isVi ? "Bạn có chắc muốn đổi repo thành $newVis không?" : "Are you sure you want to make this repo $newVis?"),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(isVi ? "Hủy" : "Cancel")),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true), 
                                        child: Text(isVi ? "Đồng ý" : "Confirm", style: const TextStyle(color: Colors.amber)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final ok = await GitService.changeCloudReposVisibility(_ownerCtrl.text, [MapEntry(cp.name, newVis)], _addLog, (_) {});
                                  if (ok) {
                                    _showToast(isVi ? "Đã đổi ${cp.name} thành $newVis" : "${cp.name} is now $newVis");
                                    _scanCloud();
                                  } else {
                                    _showToast(isVi ? "Đổi quyền thất bại cho ${cp.name}" : "Failed to change visibility for ${cp.name}", isError: true);
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Colors.blueAccent),
                              tooltip: isVi ? "Đổi tên dự án" : "Rename repository",
                              onPressed: () async {
                                final newName = await showDialog<String>(
                                  context: context,
                                  builder: (_) => RenameCloudRepoDialog(
                                    projectName: cp.name,
                                    isDark: widget.themeNotifier.mode == AppThemeMode.dark,
                                    lang: _currentLang,
                                  ),
                                );
                                if (newName != null && newName.isNotEmpty) {
                                  final ok = await GitService.renameCloudRepo(_ownerCtrl.text, cp.name, newName, _addLog);
                                  if (ok) {
                                    _showToast(isVi ? "Đã đổi tên thành $newName" : "Renamed to $newName");
                                    _scanCloud();
                                  } else {
                                    _showToast(isVi ? "Đổi tên thất bại cho ${cp.name}" : "Failed to rename ${cp.name}", isError: true);
                                  }
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever, size: 16, color: Colors.redAccent),
                              tooltip: isVi ? "Xóa vĩnh viễn" : "Delete repository",
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => DeleteCloudRepoDialog(
                                    projectName: cp.name,
                                    isDark: widget.themeNotifier.mode == AppThemeMode.dark,
                                    lang: _currentLang,
                                  ),
                                );
                                if (confirm == true) {
                                  final ok = await GitService.deleteCloudRepos(_ownerCtrl.text, [cp.name], _addLog, (_) {});
                                  if (ok) {
                                    _showToast(isVi ? "Đã xóa ${cp.name}" : "Deleted ${cp.name}");
                                    _scanCloud();
                                  } else {
                                    _showToast(isVi ? "Xóa thất bại cho ${cp.name}" : "Failed to delete ${cp.name}", isError: true);
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  // Floating Batch Action Toolbar
  Widget _buildBatchFloatingBar() {
    final count = _selectedLocalPaths.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.accentCyan,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppConstants.accentCyan.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Text(
            "$count ${I18n.t(_currentLang, "lbl_tree_stat").replaceAll('({total} project(s), {selected} selected last)', 'Selected')}",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            icon: const Icon(Icons.play_arrow, size: 14),
            label: Text("Init Git ($count)", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            onPressed: () async {
              for (var path in _selectedLocalPaths) {
                await GitService.initRepo(path);
              }
              _scanLocal();
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            icon: const Icon(Icons.article_outlined, size: 14),
            label: Text("${I18n.t(_currentLang, "btn_fix")} ($count)", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            onPressed: () {
              for (var path in _selectedLocalPaths) {
                final proj = _localProjects.firstWhere((p) => p.path == path);
                GitFormService.ensureStandardForms(
                  path: path,
                  projectName: proj.name,
                  kind: proj.kind,
                  authorName: _authorCtrl.text,
                  remoteBaseUrl: _ownerCtrl.text,
                );
              }
              _scanLocal();
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: AppConstants.accentGreen),
            icon: const Icon(Icons.cloud_upload_rounded, size: 14),
            label: Text("🚀 ${I18n.t(_currentLang, "btn_push")} ($count)", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final authed = await _ensureGithubAuth();
              if (!authed) return;
              setState(() => _showConsole = true);
              int successCount = 0;
              int failCount = 0;
              for (var path in _selectedLocalPaths) {
                _addLog("Starting Git Commit & Push for: $path");
                try {
                  final result = await GitService.commitAndPushProject(
                    path,
                    _ownerCtrl.text,
                    _msgCtrl.text.isNotEmpty ? _msgCtrl.text : "Update project",
                    (msg) => _addLog(msg),
                    autoCreateRepo: _settings['auto_create_repo'] ?? true,
                    isPublic: _settings['repo_public'] ?? false,
                  );
                  if (result) {
                    _addLog("✅ Commit & Push completed for: $path", level: 'SUCCESS');
                    successCount++;
                  } else {
                    _addLog("❌ Commit & Push failed for: $path", level: 'ERROR');
                    failCount++;
                  }
                } catch (e, stackTrace) {
                  _addLog("❌ Exception during Commit & Push for: $path\n$e\n$stackTrace", level: 'ERROR');
                  failCount++;
                }
              }
              final isVi = _currentLang == 'vi';
              if (failCount == 0) {
                _showToast(isVi ? "Đã push thành công $successCount dự án" : "Pushed $successCount project(s) successfully");
              } else {
                _showToast(
                  isVi ? "Push xong: $successCount thành công, $failCount thất bại" : "Push done: $successCount succeeded, $failCount failed",
                  isError: true,
                );
              }
              _scanLocal();
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => setState(() => _selectedLocalPaths.clear()),
          ),
        ],
      ),
    );
  }

  // Console Log Drawer
  Widget _buildConsoleDrawer() {
    if (!_showConsole) return const SizedBox.shrink();

    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.accentCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text("CONSOLE LOGS", style: TextStyle(color: AppConstants.accentCyan, fontSize: 10, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear_all, size: 14, color: Colors.white70),
                onPressed: () => setState(() => _consoleLogs.clear()),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 14, color: Colors.white70),
                onPressed: () => setState(() => _showConsole = false),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              controller: _consoleScrollCtrl,
              itemCount: _consoleLogs.length,
              itemBuilder: (context, index) {
                return Text(
                  _consoleLogs[index],
                  style: const TextStyle(color: Colors.white, fontFamily: AppConstants.fontMono, fontSize: 9),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Status Bar
  Widget _buildStatusBar() {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: _c.bgSecondary,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 12, color: _c.textMuted),
          const SizedBox(width: 6),
          Text(_statusMessage, style: TextStyle(color: _c.textMuted, fontSize: 10)),
          const Spacer(),
          InkWell(
            onTap: () => setState(() => _showConsole = !_showConsole),
            child: Row(
              children: [
                Icon(Icons.terminal_outlined, size: 12, color: AppConstants.accentCyan),
                const SizedBox(width: 4),
                Text("Console (${_consoleLogs.length})", style: const TextStyle(color: AppConstants.accentCyan, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
