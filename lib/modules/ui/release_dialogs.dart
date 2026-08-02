import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/constants.dart';
import '../../services/git_service.dart';
import '../../services/system_service.dart';
import 'dialogs.dart';

class PushReleaseDialog extends StatefulWidget {
  final String owner;
  final String projectName;
  final String localPath;
  final bool isDark;
  final String lang;

  const PushReleaseDialog({
    Key? key,
    required this.owner,
    required this.projectName,
    required this.localPath,
    required this.isDark,
    required this.lang,
  }) : super(key: key);

  @override
  _PushReleaseDialogState createState() => _PushReleaseDialogState();
}

class _PushReleaseDialogState extends State<PushReleaseDialog> {
  final _tagCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _selectedAsset = '';
  bool _isPrerelease = false;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isVi = widget.lang == 'vi';

    return GlassDialog(
      title: isVi ? "Đẩy Bản Phát Hành: ${widget.projectName}" : "Push Release: ${widget.projectName}",
      width: 500,
      height: 520,
      isDark: widget.isDark,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isVi ? "Tên Thẻ (Tag)" : "Tag Name", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _tagCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.isDark ? Colors.black26 : Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                hintText: "v1.0.0",
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 16),
            Text(isVi ? "Tiêu Đề Release" : "Release Title", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.isDark ? Colors.black26 : Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                hintText: isVi ? "VD: Phiên bản chính thức 1.0.0" : "Ex: Official Release 1.0.0",
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 16),
            Text(isVi ? "Ghi Chú Phát Hành (Notes)" : "Release Notes", style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: widget.isDark ? Colors.black26 : Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                hintText: isVi ? "Nội dung thay đổi..." : "Changelog details...",
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isVi ? "Tệp Đính Kèm (Asset)" : "Release Asset", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedAsset.isEmpty ? (isVi ? "Chưa chọn tệp nào" : "No file selected") : _selectedAsset,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _selectedAsset.isEmpty ? Colors.white38 : Colors.white, fontSize: 12),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.pickFiles(allowMultiple: false);
                              if (result != null && result.files.single.path != null) {
                                setState(() {
                                  _selectedAsset = result.files.single.path!;
                                });
                              }
                            },
                            icon: const Icon(Icons.folder_open, size: 16, color: AppConstants.accentCyan),
                            label: Text(isVi ? "Chọn Tệp" : "Browse", style: const TextStyle(color: AppConstants.accentCyan)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isPrerelease,
                  onChanged: (val) => setState(() => _isPrerelease = val ?? false),
                  activeColor: AppConstants.accentCyan,
                ),
                Text(isVi ? "Đánh dấu là bản Tiền Phát Hành (Pre-release)" : "Mark as Pre-release", style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
            const Spacer(),
            if (_isProcessing)
              const Center(child: CircularProgressIndicator(color: AppConstants.accentCyan))
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(isVi ? "HỦY" : "CANCEL", style: const TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (_tagCtrl.text.trim().isEmpty) return;
                      setState(() => _isProcessing = true);
                      final ok = await GitService.createGithubRelease(
                        owner: widget.owner,
                        repoName: widget.projectName,
                        tagName: _tagCtrl.text.trim(),
                        releaseTitle: _titleCtrl.text.trim(),
                        releaseNotes: _notesCtrl.text.trim(),
                        isPrerelease: _isPrerelease,
                        assetFilePaths: _selectedAsset.isNotEmpty ? [_selectedAsset] : null,
                        log: (msg) {},
                      );
                      if (mounted) Navigator.of(context).pop(ok);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppConstants.accentCyan, foregroundColor: Colors.black),
                    child: Text(isVi ? "PHÁT HÀNH" : "PUBLISH", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class ListReleasesDialog extends StatefulWidget {
  final String owner;
  final String projectName;
  final bool isDark;
  final String lang;

  const ListReleasesDialog({
    Key? key,
    required this.owner,
    required this.projectName,
    required this.isDark,
    required this.lang,
  }) : super(key: key);

  @override
  _ListReleasesDialogState createState() => _ListReleasesDialogState();
}

class _ListReleasesDialogState extends State<ListReleasesDialog> {
  bool _isLoading = true;
  List<dynamic> _releases = [];

  @override
  void initState() {
    super.initState();
    _loadReleases();
  }

  Future<void> _loadReleases() async {
    final rels = await GitService.getGithubReleases(widget.owner, widget.projectName, log: (m) {});
    if (mounted) {
      setState(() {
        _releases = rels;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVi = widget.lang == 'vi';

    return GlassDialog(
      title: isVi ? "Các Bản Phát Hành: ${widget.projectName}" : "Releases: ${widget.projectName}",
      width: 600,
      height: 500,
      isDark: widget.isDark,
      child: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppConstants.accentCyan))
                : _releases.isEmpty
                    ? Center(child: Text(isVi ? "Không có bản phát hành nào." : "No releases found.", style: const TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _releases.length,
                        itemBuilder: (context, index) {
                          final r = _releases[index];
                          final name = r['name'] ?? '';
                          final tag = r['tag_name'] ?? '';
                          final pubAt = r['published_at'] ?? '';
                          final isPre = r['prerelease'] == true;
                          final url = r['html_url'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.isDark ? Colors.black26 : Colors.white12,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.sell, size: 20, color: Colors.amber),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(name.isNotEmpty ? name : tag, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(width: 8),
                                          if (isPre)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                              child: const Text("Pre-release", style: TextStyle(color: Colors.orange, fontSize: 10)),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(pubAt, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 18),
                                  tooltip: isVi ? "Mở trên trình duyệt" : "Open in Browser",
                                  onPressed: () => SystemService.openUrl(url),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(isVi ? "ĐÓNG" : "CLOSE", style: const TextStyle(color: Colors.white54)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
