import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../utils/constants.dart';
import '../../services/git_form_service.dart';
import 'dialogs.dart';

/// Reads and writes a project's real `.gitignore` file directly, unlike
/// `AppConstants.getRequiredGitignoreLines` which only supplies the template.
class GitignoreEditorDialog extends StatefulWidget {
  final String projectPath;
  final String kind;
  final bool isDark;
  final String lang;

  const GitignoreEditorDialog({
    Key? key,
    required this.projectPath,
    required this.kind,
    required this.isDark,
    required this.lang,
  }) : super(key: key);

  @override
  State<GitignoreEditorDialog> createState() => _GitignoreEditorDialogState();
}

class _GitignoreEditorDialogState extends State<GitignoreEditorDialog> {
  late final TextEditingController _textCtrl;
  late final File _file;
  bool _existed = false;

  @override
  void initState() {
    super.initState();
    _file = File(p.join(widget.projectPath, '.gitignore'));
    _existed = _file.existsSync();
    _textCtrl = TextEditingController(text: _existed ? _file.readAsStringSync() : '');
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _resetToStandard() {
    final existingLines = _textCtrl.text.split('\n');
    final merged = GitFormService.mergeGitignoreLines(existingLines, widget.kind);
    setState(() {
      _textCtrl.text = merged.join('\n').trimRight();
    });
  }

  void _save() {
    _file.writeAsStringSync(_textCtrl.text.trimRight() + '\n', flush: true);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.lang == 'vi';

    return GlassDialog(
      title: isVi ? "Sửa .gitignore: ${p.basename(widget.projectPath)}" : "Edit .gitignore: ${p.basename(widget.projectPath)}",
      width: 620,
      height: 560,
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_existed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                isVi ? "Chưa có file .gitignore — nội dung sẽ được tạo mới khi lưu." : "No .gitignore file yet — it will be created on save.",
                style: const TextStyle(color: Colors.amber, fontSize: 11),
              ),
            ),
          Expanded(
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              expands: true,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: AppConstants.fontMono),
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.isDark ? Colors.black26 : Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _resetToStandard,
                icon: const Icon(Icons.auto_fix_high, size: 16, color: AppConstants.accentCyan),
                label: Text(isVi ? "Đặt lại theo chuẩn" : "Reset to Standard", style: const TextStyle(color: AppConstants.accentCyan)),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(isVi ? "HỦY" : "CANCEL", style: const TextStyle(color: Colors.white54)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
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
}
