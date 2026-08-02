import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../services/git_service.dart';
import 'dialogs.dart';

/// Full in-app Repository Settings dialog (General / Features / Pull Requests / Danger Zone),
/// mirroring the GitHub web settings page instead of opening it in a browser.
class RepoSettingsDialog extends StatefulWidget {
  final String owner;
  final String projectName;
  final bool isDark;
  final String lang;

  const RepoSettingsDialog({
    Key? key,
    required this.owner,
    required this.projectName,
    required this.isDark,
    required this.lang,
  }) : super(key: key);

  @override
  State<RepoSettingsDialog> createState() => _RepoSettingsDialogState();
}

class _RepoSettingsDialogState extends State<RepoSettingsDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMsg;

  final _descCtrl = TextEditingController();
  final _homepageCtrl = TextEditingController();
  String _defaultBranch = '';
  String _visibility = 'private';

  bool _hasIssues = false;
  bool _hasWiki = false;
  bool _hasProjects = false;
  bool _hasDiscussions = false;
  bool _squashMerge = false;
  bool _mergeCommit = false;
  bool _rebaseMerge = false;
  bool _deleteBranchOnMerge = false;

  Map<String, dynamic> _original = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _homepageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final data = await GitService.getRepoSettings(widget.owner, widget.projectName);
    if (!mounted) return;

    if (data == null) {
      setState(() {
        _isLoading = false;
        _errorMsg = widget.lang == 'vi' ? "Không thể tải cài đặt repository." : "Failed to load repository settings.";
      });
      return;
    }

    setState(() {
      _original = data;
      _descCtrl.text = (data['description'] ?? '').toString();
      _homepageCtrl.text = (data['homepageUrl'] ?? '').toString();
      _defaultBranch = (data['defaultBranchRef'] is Map ? data['defaultBranchRef']['name'] : null)?.toString() ?? '';
      _visibility = (data['visibility'] ?? 'PRIVATE').toString().toLowerCase();
      _hasIssues = data['hasIssuesEnabled'] == true;
      _hasWiki = data['hasWikiEnabled'] == true;
      _hasProjects = data['hasProjectsEnabled'] == true;
      _hasDiscussions = data['hasDiscussionsEnabled'] == true;
      _squashMerge = data['squashMergeAllowed'] == true;
      _mergeCommit = data['mergeCommitAllowed'] == true;
      _rebaseMerge = data['rebaseMergeAllowed'] == true;
      _deleteBranchOnMerge = data['deleteBranchOnMerge'] == true;
      _isLoading = false;
    });
  }

  Map<String, dynamic> _buildChanges() {
    final changes = <String, dynamic>{};
    if (_descCtrl.text.trim() != (_original['description'] ?? '').toString()) {
      changes['description'] = _descCtrl.text.trim();
    }
    if (_homepageCtrl.text.trim() != (_original['homepageUrl'] ?? '').toString()) {
      changes['homepageUrl'] = _homepageCtrl.text.trim();
    }
    if (_hasIssues != (_original['hasIssuesEnabled'] == true)) changes['hasIssuesEnabled'] = _hasIssues;
    if (_hasWiki != (_original['hasWikiEnabled'] == true)) changes['hasWikiEnabled'] = _hasWiki;
    if (_hasProjects != (_original['hasProjectsEnabled'] == true)) changes['hasProjectsEnabled'] = _hasProjects;
    if (_hasDiscussions != (_original['hasDiscussionsEnabled'] == true)) changes['hasDiscussionsEnabled'] = _hasDiscussions;
    if (_squashMerge != (_original['squashMergeAllowed'] == true)) changes['squashMergeAllowed'] = _squashMerge;
    if (_mergeCommit != (_original['mergeCommitAllowed'] == true)) changes['mergeCommitAllowed'] = _mergeCommit;
    if (_rebaseMerge != (_original['rebaseMergeAllowed'] == true)) changes['rebaseMergeAllowed'] = _rebaseMerge;
    if (_deleteBranchOnMerge != (_original['deleteBranchOnMerge'] == true)) {
      changes['deleteBranchOnMerge'] = _deleteBranchOnMerge;
    }
    return changes;
  }

  Future<void> _save() async {
    final changes = _buildChanges();
    if (changes.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMsg = null;
    });

    final ok = await GitService.updateRepoSettings(widget.owner, widget.projectName, changes, (_) {});
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSaving = false;
        _errorMsg = widget.lang == 'vi' ? "Lưu cài đặt thất bại." : "Failed to save settings.";
      });
    }
  }

  Future<void> _changeVisibility() async {
    final isVi = widget.lang == 'vi';
    final newVis = _visibility == 'private' ? 'public' : 'private';

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
    if (confirm != true) return;

    setState(() => _isSaving = true);
    final ok = await GitService.changeCloudReposVisibility(widget.owner, [MapEntry(widget.projectName, newVis)], (_) {}, (_) {});
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      if (ok) {
        _visibility = newVis;
      } else {
        _errorMsg = isVi ? "Đổi quyền thất bại." : "Failed to change visibility.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.lang == 'vi';
    final sectionStyle = const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8);
    final labelStyle = const TextStyle(color: Colors.white54, fontSize: 11);
    final fieldFill = widget.isDark ? Colors.black26 : Colors.white12;
    final fieldBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none);

    return GlassDialog(
      title: isVi ? "Cài Đặt Repository: ${widget.projectName}" : "Repository Settings: ${widget.projectName}",
      width: 560,
      height: 640,
      isDark: widget.isDark,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppConstants.accentCyan))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isVi ? "TỔNG QUAN" : "GENERAL", style: sectionStyle),
                        const SizedBox(height: 10),
                        Text(isVi ? "Mô tả" : "Description", style: labelStyle),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _descCtrl,
                          maxLines: 2,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(filled: true, fillColor: fieldFill, border: fieldBorder),
                        ),
                        const SizedBox(height: 12),
                        Text(isVi ? "Website" : "Website", style: labelStyle),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _homepageCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: fieldFill,
                            border: fieldBorder,
                            hintText: "https://...",
                            hintStyle: const TextStyle(color: Colors.white38),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(isVi ? "Nhánh mặc định: " : "Default branch: ", style: labelStyle),
                            Text(_defaultBranch.isEmpty ? '—' : _defaultBranch, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(isVi ? "TÍNH NĂNG" : "FEATURES", style: sectionStyle),
                        _buildCheckbox(isVi ? "Vấn đề (Issues)" : "Issues", _hasIssues, (v) => setState(() => _hasIssues = v)),
                        _buildCheckbox("Wiki", _hasWiki, (v) => setState(() => _hasWiki = v)),
                        _buildCheckbox(isVi ? "Dự án (Projects)" : "Projects", _hasProjects, (v) => setState(() => _hasProjects = v)),
                        _buildCheckbox(isVi ? "Thảo luận (Discussions)" : "Discussions", _hasDiscussions, (v) => setState(() => _hasDiscussions = v)),
                        const SizedBox(height: 12),
                        Text("PULL REQUESTS", style: sectionStyle),
                        _buildCheckbox(isVi ? "Cho phép Squash merging" : "Allow squash merging", _squashMerge, (v) => setState(() => _squashMerge = v)),
                        _buildCheckbox(isVi ? "Cho phép Merge commits" : "Allow merge commits", _mergeCommit, (v) => setState(() => _mergeCommit = v)),
                        _buildCheckbox(isVi ? "Cho phép Rebase merging" : "Allow rebase merging", _rebaseMerge, (v) => setState(() => _rebaseMerge = v)),
                        _buildCheckbox(
                          isVi ? "Tự động xoá nhánh sau khi merge" : "Automatically delete head branches",
                          _deleteBranchOnMerge,
                          (v) => setState(() => _deleteBranchOnMerge = v),
                        ),
                        const SizedBox(height: 20),
                        Text(isVi ? "VÙNG NGUY HIỂM" : "DANGER ZONE", style: sectionStyle.copyWith(color: Colors.redAccent)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(isVi ? "Thay đổi khả năng hiển thị" : "Change repository visibility",
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    Text(
                                      _visibility == 'private' ? (isVi ? "Hiện đang: Riêng tư" : "Currently: Private") : (isVi ? "Hiện đang: Công khai" : "Currently: Public"),
                                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: _isSaving ? null : _changeVisibility,
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                child: Text(
                                  _visibility == 'private' ? (isVi ? "Đổi Công Khai" : "Make Public") : (isVi ? "Đổi Riêng Tư" : "Make Private"),
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_errorMsg!, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                      child: Text(isVi ? "HỦY" : "CANCEL", style: const TextStyle(color: Colors.white54)),
                    ),
                    const SizedBox(width: 12),
                    _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppConstants.accentCyan))
                        : ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentCyan, foregroundColor: Colors.black),
                            child: Text(isVi ? "LƯU" : "SAVE", style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: (v) => onChanged(v ?? false), activeColor: AppConstants.accentCyan),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
