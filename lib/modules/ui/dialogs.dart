// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../utils/constants.dart';
import '../../utils/i18n.dart';
import '../../utils/windows_info.dart';
import '../../services/git_service.dart';
import 'package:flutter/services.dart';
import '../../services/system_service.dart';
import 'styles.dart';
import '../../services/settings_service.dart';

/// Base Glassmorphic Dialog with BackdropFilter Blur
class GlassDialog extends StatelessWidget {
  final Widget child;
  final double width;
  final double height;
  final bool isDark;
  final String title;
  final double? blurSigma;
  final double? bgOpacity;

  const GlassDialog({
    Key? key,
    required this.child,
    required this.title,
    this.width = 640,
    this.height = 480,
    required this.isDark,
    this.blurSigma,
    this.bgOpacity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final settings = SettingsService.loadSettings();
    final double sigma = blurSigma ?? (settings['dialog_blur'] ?? 12.0);
    final double opacity = bgOpacity ?? (settings['dialog_opacity'] ?? 0.45);

    final enableTransparency = Platform.isWindows && WindowsInfo.isWindows11OrGreater;
    final bg = enableTransparency ? c.bgSecondary.withOpacity(opacity) : c.bgSecondary;
    final border = enableTransparency ? c.borderDefault.withOpacity((opacity * 0.5).clamp(0.1, 0.8)) : c.borderDefault;
    final text = c.textPrimary;

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                )
              ],
            ),
            child: Column(
              children: [
                // Custom Window Header Bar
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: border, width: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppConstants.colorCloseNormal,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppConstants.colorCloseBorder),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color: text,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, size: 16, color: c.textMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Conflict Resolution Dialog
class ConflictDialog extends StatelessWidget {
  final String projectName;
  final bool isDark;
  final String lang;

  const ConflictDialog({
    Key? key,
    required this.projectName,
    required this.isDark,
    required this.lang,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: isDark ? Colors.white : Colors.black,
      fontFamily: AppConstants.fontPrimary,
    );

    return GlassDialog(
      title: I18n.t(lang, "conflict_title"),
      width: 480,
      height: 280,
      isDark: isDark,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  I18n.t(lang, "conflict_message", args: {"name": projectName}),
                  style: textStyle.copyWith(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              _buildOption(
                context,
                I18n.t(lang, "conflict_overwrite"),
                Colors.red,
                () => Navigator.of(context).pop('overwrite'),
              ),
              const SizedBox(height: 8),
              _buildOption(
                context,
                I18n.t(lang, "conflict_stash"),
                AppConstants.accentCyan,
                () => Navigator.of(context).pop('stash'),
              ),
              const SizedBox(height: 8),
              _buildOption(
                context,
                I18n.t(lang, "conflict_skip"),
                Colors.grey,
                () => Navigator.of(context).pop('skip'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String text, Color accent, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
          foregroundColor: accent,
          shadowColor: Colors.transparent,
          side: BorderSide(color: accent.withOpacity(0.4), width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }
}

/// GitHub Auth Dialog to prompt browser login
class GithubAuthGuiDialog extends StatefulWidget {
  final bool isDark;
  final String lang;

  const GithubAuthGuiDialog({
    Key? key,
    required this.isDark,
    required this.lang,
  }) : super(key: key);

  @override
  State<GithubAuthGuiDialog> createState() => _GithubAuthGuiDialogState();
}

class _GithubAuthGuiDialogState extends State<GithubAuthGuiDialog> {
  String? _oneTimeCode;
  bool _isAuthenticating = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startAuthProcess();
  }

  Future<void> _startAuthProcess() async {
    setState(() {
      _isAuthenticating = true;
      _hasError = false;
    });

    final success = await GitService.triggerGithubLoginGui((code) {
      if (mounted) {
        setState(() {
          _oneTimeCode = code;
        });
      }
    });

    if (mounted) {
      if (success) {
        Navigator.of(context).pop('login'); // Return success
      } else {
        setState(() {
          _hasError = true;
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassDialog(
      title: widget.lang == 'vi' ? "YÊU CẦU ĐĂNG NHẬP GITHUB" : "GITHUB LOGIN REQUIRED",
      width: 500,
      height: 320,
      isDark: widget.isDark,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.account_circle, color: AppConstants.accentCyan, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lang == 'vi' ? "Xác thực thiết bị mới" : "Device Authentication",
                      style: TextStyle(
                        color: widget.isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.lang == 'vi'
                          ? "Ứng dụng đang kết nối với GitHub CLI để lấy mã xác thực. Vui lòng chờ trong giây lát."
                          : "Connecting to GitHub CLI to fetch authentication code. Please wait a moment.",
                      style: TextStyle(
                        color: widget.isDark ? Colors.white70 : Colors.black87,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          
          if (_hasError)
            Column(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(
                  widget.lang == 'vi' ? "Xác thực thất bại. Vui lòng thử lại!" : "Authentication failed. Please try again!",
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
            )
          else if (_oneTimeCode == null)
            const Column(
              children: [
                CircularProgressIndicator(color: AppConstants.accentCyan),
                SizedBox(height: 16),
              ],
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.black38 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppConstants.accentCyan.withOpacity(0.5)),
                  ),
                  child: Text(
                    _oneTimeCode!,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: widget.isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.lang == 'vi' 
                      ? "Mã sẽ tự động copy khi bấm nút bên dưới.\nHãy dán mã này vào trình duyệt để xác thực."
                      : "Code will be copied automatically.\nPaste this code into your browser to authenticate.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: widget.isDark ? Colors.white54 : Colors.black54),
                ),
              ],
            ),

          const Spacer(),
          
          if (_oneTimeCode != null && !_hasError)
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accentCyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.copy, size: 20),
                label: Text(
                  widget.lang == 'vi' ? "COPY MÃ VÀ MỞ TRÌNH DUYỆT" : "COPY CODE & OPEN BROWSER",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _oneTimeCode!));
                  await SystemService.openUrl("https://github.com/login/device");
                },
              ),
            ),
          
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: Text(
              widget.lang == 'vi' ? "Hủy bỏ" : "Cancel",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Comprehensive Settings, User Guide & About Dialog
class SettingsDialog extends StatefulWidget {
  final bool isDark;
  final String lang;
  final Map<String, dynamic> settings;

  const SettingsDialog({
    Key? key,
    required this.isDark,
    required this.lang,
    required this.settings,
  }) : super(key: key);

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late TextEditingController _authorCtrl;
  late TextEditingController _ownerCtrl;
  late int _maxDepth;
  late bool _autoCreateRepo;
  late bool _repoPublic;
  late double _bgBlur;
  late double _bgOpacity;
  late double _dialogBlur;
  late double _dialogOpacity;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _authorCtrl = TextEditingController(text: widget.settings['license_author'] ?? 'John Alaa');
    _ownerCtrl = TextEditingController(text: widget.settings['remote_base'] ?? '');
    _maxDepth = widget.settings['max_depth'] ?? 3;
    _autoCreateRepo = widget.settings['auto_create_repo'] ?? true;
    _repoPublic = widget.settings['repo_public'] ?? false;

    _bgBlur = (widget.settings['bg_blur'] as num?)?.toDouble() ?? 10.0;
    _bgOpacity = (widget.settings['bg_opacity'] as num?)?.toDouble() ?? 0.6;
    _dialogBlur = (widget.settings['dialog_blur'] as num?)?.toDouble() ?? 12.0;
    _dialogOpacity = (widget.settings['dialog_opacity'] as num?)?.toDouble() ?? 0.45;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _authorCtrl.dispose();
    _ownerCtrl.dispose();
    super.dispose();
  }

  void _resetToDefaults() {
    setState(() {
      _authorCtrl.text = 'John Alaa';
      _ownerCtrl.text = '';
      _maxDepth = 3;
      _autoCreateRepo = true;
      _repoPublic = false;
      _bgBlur = 10.0;
      _bgOpacity = 0.6;
      _dialogBlur = 12.0;
      _dialogOpacity = 0.45;
    });
  }

  void _saveSettings() {
    final updated = Map<String, dynamic>.from(widget.settings);
    updated['license_author'] = _authorCtrl.text.trim();
    updated['remote_base'] = _ownerCtrl.text.trim();
    updated['max_depth'] = _maxDepth;
    updated['auto_create_repo'] = _autoCreateRepo;
    updated['repo_public'] = _repoPublic;

    updated['bg_blur'] = _bgBlur;
    updated['bg_opacity'] = _bgOpacity;
    updated['dialog_blur'] = _dialogBlur;
    updated['dialog_opacity'] = _dialogOpacity;

    SettingsService.saveSettings(updated);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.lang == 'vi';
    final textPrimary = widget.isDark ? Colors.white : Colors.black87;
    final textMuted = widget.isDark ? Colors.white54 : Colors.black54;

    return GlassDialog(
      title: isVi ? "CÀI ĐẶT & HƯỚNG DẪN" : "SETTINGS & USER GUIDE",
      width: 740,
      height: 580,
      isDark: widget.isDark,
      blurSigma: _dialogBlur,
      bgOpacity: _dialogOpacity,
      child: Column(
        children: [
          // Sub TabBar Header
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabCtrl,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppConstants.accentCyan.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppConstants.accentCyan.withOpacity(0.5)),
              ),
              labelColor: AppConstants.accentCyan,
              unselectedLabelColor: textMuted,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: isVi ? "⚙️ Cài đặt Nâng cao" : "⚙️ Advanced Settings"),
                Tab(text: isVi ? "📖 Hướng dẫn Sử dụng" : "📖 User Guide"),
                Tab(text: isVi ? "ℹ️ Giới thiệu (About)" : "ℹ️ About Application"),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildSettingsTab(isVi, textPrimary, textMuted),
                _buildGuideTab(isVi, textPrimary, textMuted),
                _buildAboutTab(isVi, textPrimary, textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: SETTINGS ---
  Widget _buildSettingsTab(bool isVi, Color textPrimary, Color textMuted) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(isVi ? "CẤU HÌNH BẢN QUYỀN & TIÊU CHUẨN GIT" : "LICENSE & GIT FORM DEFAULTS"),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _authorCtrl,
                        label: isVi ? "Tác giả bản quyền (LICENSE Author)" : "Default License Author",
                        hint: "John Alaa",
                        icon: Icons.person_outline,
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVi ? "Độ sâu quét thư mục (Scan Depth)" : "Directory Scan Depth",
                            style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: widget.isDark ? Colors.black26 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppConstants.accentCyan.withOpacity(0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _maxDepth,
                                isExpanded: true,
                                dropdownColor: widget.isDark ? const Color(0xFF1E222D) : Colors.white,
                                style: TextStyle(color: textPrimary, fontSize: 12),
                                items: [1, 2, 3, 4, 5].map((d) {
                                  return DropdownMenuItem<int>(
                                    value: d,
                                    child: Text(isVi ? "$d cấp thư mục" : "$d levels deep"),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _maxDepth = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildSectionHeader(isVi ? "CẤU HÌNH GITHUB PUSH TỰ ĐỘNG" : "AUTOMATED GITHUB PUSH CONFIG"),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _ownerCtrl,
                  label: isVi ? "GitHub Base Owner / Org Mặc định" : "Default GitHub Owner / Org",
                  hint: "jatechvn",
                  icon: Icons.cloud_sync_outlined,
                  textPrimary: textPrimary,
                  textMuted: textMuted,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(
                    isVi ? "Tự động tạo GitHub Repository mới nếu chưa có" : "Auto create GitHub repository if missing",
                    style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isVi ? "Tạo kho lưu trữ tự động trên GitHub khi thực hiện Push" : "Automatically create remote repository on GitHub before push",
                    style: TextStyle(color: textMuted, fontSize: 10),
                  ),
                  value: _autoCreateRepo,
                  activeColor: AppConstants.accentCyan,
                  onChanged: (v) => setState(() => _autoCreateRepo = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: Text(
                    isVi ? "Tạo kho lưu trữ mặc định là PUBLIC" : "Create repository as PUBLIC by default",
                    style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isVi ? "Nếu tắt, các kho lưu trữ mới sẽ tạo dưới dạng PRIVATE" : "If disabled, new repositories will be created as PRIVATE",
                    style: TextStyle(color: textMuted, fontSize: 10),
                  ),
                  value: _repoPublic,
                  activeColor: AppConstants.accentCyan,
                  onChanged: (v) => setState(() => _repoPublic = v),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.accentCyan.withOpacity(0.3)),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                      iconColor: AppConstants.accentCyan,
                      collapsedIconColor: textMuted,
                      title: Row(
                        children: [
                          const Icon(Icons.palette_outlined, size: 18, color: AppConstants.accentCyan),
                          const SizedBox(width: 8),
                          Text(
                            isVi ? "TÙY CHỈNH GIAO DIỆN KÍNH (GLASSMORPHISM)" : "GLASSMORPHISM & TRANSPARENCY",
                            style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      children: [
                        const SizedBox(height: 4),
                        // App Blur Slider
                        _buildSliderTile(
                          label: isVi ? "Độ làm mờ giao diện chính (App Blur Sigma)" : "App Background Blur (Sigma)",
                          valueText: "${_bgBlur.toStringAsFixed(1)} px",
                          value: _bgBlur,
                          min: 0.0,
                          max: 30.0,
                          icon: Icons.blur_on,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          onChanged: (v) => setState(() => _bgBlur = v),
                        ),
                        const SizedBox(height: 8),

                        // App Opacity Slider
                        _buildSliderTile(
                          label: isVi ? "Độ trong suốt giao diện chính (App Opacity)" : "App Background Opacity",
                          valueText: "${(_bgOpacity * 100).toInt()}%",
                          value: _bgOpacity,
                          min: 0.1,
                          max: 1.0,
                          icon: Icons.opacity,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          onChanged: (v) => setState(() => _bgOpacity = v),
                        ),
                        const SizedBox(height: 8),

                        // Dialog Blur Slider
                        _buildSliderTile(
                          label: isVi ? "Độ làm mờ cửa sổ bật lên (Popup Dialog Blur)" : "Popup Dialog Blur (Sigma)",
                          valueText: "${_dialogBlur.toStringAsFixed(1)} px",
                          value: _dialogBlur,
                          min: 0.0,
                          max: 30.0,
                          icon: Icons.filter_center_focus,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          onChanged: (v) => setState(() => _dialogBlur = v),
                        ),
                        const SizedBox(height: 8),

                        // Dialog Opacity Slider
                        _buildSliderTile(
                          label: isVi ? "Độ trong suốt cửa sổ bật lên (Popup Dialog Opacity)" : "Popup Dialog Opacity",
                          valueText: "${(_dialogOpacity * 100).toInt()}%",
                          value: _dialogOpacity,
                          min: 0.1,
                          max: 1.0,
                          icon: Icons.tonality,
                          textPrimary: textPrimary,
                          textMuted: textMuted,
                          onChanged: (v) => setState(() => _dialogOpacity = v),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _buildSectionHeader(isVi ? "NHẬT KÝ VÀ HỆ THỐNG" : "SYSTEM & LOG RETENTION"),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.accentGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cleaning_services, color: AppConstants.accentGreen, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVi ? "Tự động dọn dẹp Nhật ký (Log Auto-Cleanup)" : "Log Auto-Cleanup System",
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isVi ? "Hệ thống tự động xóa toàn bộ các file log cũ hơn 7 ngày khi ứng dụng khởi động." : "Automatically purges log files older than 7 days upon app startup.",
                              style: TextStyle(color: textMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppConstants.accentGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isVi ? "ĐÁNG HOẠT ĐỘNG" : "ACTIVE",
                          style: const TextStyle(color: AppConstants.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: BorderSide(color: Colors.amberAccent.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.restart_alt_rounded, size: 18),
                  label: Text(
                    isVi ? "KHÔI PHỤC MẶC ĐỊNH" : "RESET DEFAULTS",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  onPressed: _resetToDefaults,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.accentCyan,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    isVi ? "LƯU CÀI ĐẶT" : "SAVE SETTINGS",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  onPressed: _saveSettings,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- TAB 2: USER GUIDE ---
  Widget _buildGuideTab(bool isVi, Color textPrimary, Color textMuted) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGuideCard(
            icon: Icons.folder_special_outlined,
            title: isVi ? "1. Ghi nhớ & Quét thư mục dự án" : "1. Directory Memory & Scanning",
            content: isVi
                ? "• Chọn hoặc dán đường dẫn chứa các thư mục dự án của bạn.\n• Ứng dụng tự động GHI NHỚ thư mục bạn chọn lần cuối cho mọi lần mở sau.\n• Khi chọn thư mục mới, hệ thống tự động BỎ CHỌN toàn bộ các dự án đã chọn trước đó để tránh nhầm lẫn."
                : "• Pick or paste the target workspace directory path.\n• The app automatically REMEMBERS your last selected workspace folder.\n• Selecting a new folder automatically CLEARS previous project selections.",
            accent: AppConstants.accentCyan,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.bubble_chart_outlined,
            title: isVi ? "2. Trạng thái dự án (Git Status)" : "2. Project Status Types",
            content: isVi
                ? "• CLEAN (Xanh): Kho lưu trữ Git sạch sẽ, không có file chỉnh sửa dở dang.\n• DIRTY (Vàng): Có file mới hoặc thay đổi chưa commit lên Git.\n• No Git (Đỏ): Thư mục chưa được khởi tạo kho lưu trữ Git.\n• Missing Form: Thiếu các file chuẩn hóa (.gitignore, LICENSE, README, script push)."
                : "• CLEAN (Green): Working tree is clean, no uncommitted changes.\n• DIRTY (Yellow): Modified or untracked files present.\n• No Git (Red): Directory has no .git repository.\n• Missing Form: Lacks standard project files (.gitignore, LICENSE, etc.).",
            accent: Colors.amber,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.bolt_outlined,
            title: isVi ? "3. Quy trình Commit & Push hàng loạt" : "3. Batch Commit & Push Workflow",
            content: isVi
                ? "• Tích chọn các dự án cần thực hiện.\n• Nhấn 'TẠO / SỬA FORM GIT CHUẨN' để tạo nhanh bộ file tiêu chuẩn.\n• Nhấn 'COMMIT & PUSH SELECTED' để tự động đóng gói và đẩy code lên GitHub.\n• Nếu GitHub có cập nhật mới hơn, hệ thống tự động 'pull --rebase' để đồng bộ."
                : "• Select target projects via checkboxes.\n• Click 'CREATE / EDIT GIT FORM' to build standard files.\n• Click 'COMMIT & PUSH SELECTED' to auto-commit and push to GitHub.\n• Automatically runs 'pull --rebase' if remote commits exist.",
            accent: AppConstants.accentGreen,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
          const SizedBox(height: 10),
          _buildGuideCard(
            icon: Icons.vpn_key_outlined,
            title: isVi ? "4. Đăng nhập GitHub bằng mã Device Code" : "4. GitHub Device Authentication",
            content: isVi
                ? "• Nhấn vào nút GITHUB trên thanh công cụ.\n• Mã xác thực 8 chữ số sẽ xuất hiện ngay lập tức.\n• Nhấn 'COPY MÃ VÀ MỞ TRÌNH DUYỆT' để xác nhận trên trang GitHub.\n• Đăng nhập 1 lần và ứng dụng sẽ tự động ghi nhớ trạng thái."
                : "• Click the GITHUB button in the header bar.\n• An 8-digit device code will be fetched directly via HTTP API.\n• Click 'COPY CODE & OPEN BROWSER' to authorize on GitHub.\n• Authenticate once and your session is saved.",
            accent: Colors.purpleAccent,
            textPrimary: textPrimary,
            textMuted: textMuted,
          ),
        ],
      ),
    );
  }

  // --- TAB 3: ABOUT ---
  Widget _buildAboutTab(bool isVi, Color textPrimary, Color textMuted) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppConstants.accentCyan.withOpacity(0.4), AppConstants.accentPurple.withOpacity(0.4)],
                    ),
                    border: Border.all(color: AppConstants.accentCyan.withOpacity(0.6), width: 2),
                    boxShadow: [
                      BoxShadow(color: AppConstants.accentCyan.withOpacity(0.3), blurRadius: 16),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: AppConstants.fontPrimary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppConstants.accentCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppConstants.accentCyan.withOpacity(0.4)),
                  ),
                  child: Text(
                    "v${AppConstants.appVersion} • Liquid Glass Edition",
                    style: const TextStyle(color: AppConstants.accentCyan, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: AppConstants.fontMono),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    isVi
                        ? "Phần mềm tự động hóa quản lý kho lưu trữ Git, tạo bộ khung file chuẩn hóa dự án và đồng bộ hàng loạt lên GitHub dành cho các lập trình viên chuyên nghiệp."
                        : "Cross-platform Git workspace automation tool for standardizing project structures and performing high-speed batch GitHub synchronization.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textMuted, fontSize: 12, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),

                // Info Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.person,
                        label: isVi ? "TÁC GIẢ" : "AUTHOR",
                        value: "John Alaa (JA Tech)",
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.computer,
                        label: isVi ? "HỆ ĐIỀU HÀNH" : "PLATFORM",
                        value: "Windows 10/11 x64",
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.code,
                        label: isVi ? "CÔNG NGHỆ" : "FRAMEWORK",
                        value: "Flutter Desktop / Dart",
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoTile(
                        icon: Icons.history,
                        label: isVi ? "BẢO TRÌ LOG" : "LOG CLEANUP",
                        value: isVi ? "Tự xóa sau 7 ngày" : "7-Day Auto Purge",
                        textPrimary: textPrimary,
                        textMuted: textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "© 2026 JA Tech / John Alaa. All rights reserved.",
          style: TextStyle(color: textMuted, fontSize: 10),
        ),
      ],
    );
  }

  // --- HELPER WIDGETS ---
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppConstants.accentCyan,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            controller: controller,
            style: TextStyle(color: textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: textMuted, fontSize: 11),
              prefixIcon: Icon(icon, size: 16, color: AppConstants.accentCyan),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: widget.isDark ? Colors.black26 : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppConstants.accentCyan.withOpacity(0.3)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required String title,
    required String content,
    required Color accent,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(color: textMuted, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color textPrimary,
    required Color textMuted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppConstants.accentCyan),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required IconData icon,
    required Color textPrimary,
    required Color textMuted,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.black26 : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.accentCyan.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppConstants.accentCyan),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppConstants.accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  valueText,
                  style: const TextStyle(color: AppConstants.accentCyan, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: AppConstants.fontMono),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppConstants.accentCyan,
              inactiveTrackColor: AppConstants.accentCyan.withOpacity(0.2),
              thumbColor: AppConstants.accentCyan,
              overlayColor: AppConstants.accentCyan.withOpacity(0.2),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// GitHub Account Switcher & Logout Dialog
class GithubAccountDialog extends StatefulWidget {
  final bool isDark;
  final String lang;
  final Map<String, String> accountInfo;

  const GithubAccountDialog({
    Key? key,
    required this.isDark,
    required this.lang,
    required this.accountInfo,
  }) : super(key: key);

  @override
  State<GithubAccountDialog> createState() => _GithubAccountDialogState();
}

class _GithubAccountDialogState extends State<GithubAccountDialog> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final username = widget.accountInfo['login'] ?? 'Unknown User';
    final name = widget.accountInfo['name'] ?? '';
    final isVi = widget.lang == 'vi';

    return GlassDialog(
      title: isVi ? "QUẢN LÝ TÀI KHOẢN GITHUB" : "GITHUB ACCOUNT MANAGEMENT",
      width: 460,
      height: 300,
      isDark: widget.isDark,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.accentCyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppConstants.accentCyan.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppConstants.accentCyan.withOpacity(0.2),
                  child: const Icon(Icons.person, color: AppConstants.accentCyan, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      if (name.isNotEmpty)
                        Text(
                          name,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppConstants.accentGreen, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            isVi ? "Đã xác thực thành công" : "Authenticated & Connected",
                            style: const TextStyle(color: AppConstants.accentGreen, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_isProcessing)
            const CircularProgressIndicator(color: AppConstants.accentCyan)
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      setState(() => _isProcessing = true);
                      await GitService.logoutGithub();
                      if (mounted) {
                        Navigator.of(context).pop('switch');
                      }
                    },
                    icon: const Icon(Icons.sync_alt_rounded, size: 16),
                    label: Text(isVi ? "Đổi tài khoản" : "Switch Account"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppConstants.accentCyan,
                      side: BorderSide(color: AppConstants.accentCyan.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      setState(() => _isProcessing = true);
                      await GitService.logoutGithub();
                      if (mounted) {
                        Navigator.of(context).pop('logout');
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16),
                    label: Text(isVi ? "Đăng xuất" : "Log Out"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
