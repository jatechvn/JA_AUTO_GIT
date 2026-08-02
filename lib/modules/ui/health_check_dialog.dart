import 'package:flutter/material.dart';
import '../../models/project_info.dart';
import '../../services/git_form_service.dart';
import '../../utils/constants.dart';
import 'dialogs.dart';

/// Rollup of every local project missing one of the standard project-form files
/// (`.gitignore`, `git_push.bat`, `README.md`, `LICENSE`, `ABOUT.txt`), with a
/// one-click "Fix All" that reuses `GitFormService.ensureStandardForms` per row
/// (the same call already wired to the per-row "Apply Standard Forms" button).
class HealthCheckDialog extends StatefulWidget {
  final List<ProjectInfo> projects;
  final String authorName;
  final String remoteBaseUrl;
  final bool isDark;
  final String lang;

  const HealthCheckDialog({
    Key? key,
    required this.projects,
    required this.authorName,
    required this.remoteBaseUrl,
    required this.isDark,
    required this.lang,
  }) : super(key: key);

  @override
  State<HealthCheckDialog> createState() => _HealthCheckDialogState();
}

class _HealthCheckDialogState extends State<HealthCheckDialog> {
  bool _isFixing = false;
  int _fixedCount = 0;

  List<ProjectInfo> get _nonStandard => widget.projects.where((p) => !p.standardOk).toList();

  Future<void> _fixAll() async {
    final targets = _nonStandard;
    setState(() {
      _isFixing = true;
      _fixedCount = 0;
    });

    for (final proj in targets) {
      await GitFormService.ensureStandardForms(
        path: proj.path,
        projectName: proj.name,
        kind: proj.kind,
        authorName: widget.authorName,
        remoteBaseUrl: widget.remoteBaseUrl,
      );
      if (mounted) setState(() => _fixedCount++);
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.lang == 'vi';
    final targets = _nonStandard;

    return GlassDialog(
      title: isVi ? "Kiểm tra chuẩn dự án (${targets.length})" : "Project Health Check (${targets.length})",
      width: 580,
      height: 520,
      isDark: widget.isDark,
      child: Column(
        children: [
          Expanded(
            child: targets.isEmpty
                ? Center(
                    child: Text(
                      isVi ? "🎉 Tất cả dự án đều đạt chuẩn." : "🎉 All projects are standard-compliant.",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: targets.length,
                    itemBuilder: (context, index) {
                      final proj = targets[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.black26 : Colors.white12,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(proj.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 4,
                              children: [
                                _badge("Ignore", proj.gitignoreOk),
                                _badge("Push", proj.pushBatOk),
                                _badge("MD", proj.readmeOk),
                                _badge("LIC", proj.licenseOk),
                                _badge("ABT", proj.aboutOk),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isFixing ? null : () => Navigator.of(context).pop(false),
                child: Text(isVi ? "ĐÓNG" : "CLOSE", style: const TextStyle(color: Colors.white54)),
              ),
              const SizedBox(width: 12),
              if (targets.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _isFixing ? null : _fixAll,
                  icon: _isFixing
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.build_circle_outlined, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentCyan, foregroundColor: Colors.black),
                  label: Text(
                    _isFixing
                        ? "${isVi ? 'Đang sửa' : 'Fixing'}... ($_fixedCount/${targets.length})"
                        : (isVi ? "SỬA TẤT CẢ" : "FIX ALL"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, bool ok) {
    return Tooltip(
      message: "$label: ${ok ? 'OK' : 'Missing'}",
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: (ok ? Colors.green : Colors.red).withOpacity(0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(label, style: TextStyle(color: ok ? Colors.green : Colors.red, fontSize: 7, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
