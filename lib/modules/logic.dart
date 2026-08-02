// lib/modules/logic.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/project_info.dart';
import '../services/scanner_service.dart';
import '../services/git_service.dart';
import '../services/git_form_service.dart';
import 'logger_config.dart';
import 'native_bridge.dart';

class MainLogic extends ChangeNotifier {
  List<ProjectInfo> _localProjects = [];
  List<CloudProjectInfo> _cloudProjects = [];
  bool _isScanningLocal = false;
  bool _isScanningCloud = false;
  String _statusMessage = 'Ready';
  int _progress = 0;

  List<ProjectInfo> get localProjects => _localProjects;
  List<CloudProjectInfo> get cloudProjects => _cloudProjects;
  bool get isScanningLocal => _isScanningLocal;
  bool get isScanningCloud => _isScanningCloud;
  String get statusMessage => _statusMessage;
  int get progress => _progress;

  /// Scans local folder for projects
  Future<void> scanLocalProjects(String rootPath) async {
    if (rootPath.isEmpty) return;
    _isScanningLocal = true;
    _statusMessage = 'Scanning local projects...';
    _progress = 10;
    notifyListeners();

    try {
      LoggerConfig.log('Started local scan at: $rootPath', level: 'INFO');
      final result = await ScannerService.scanProjects(rootPath);
      
      // Native optimization check via NativeBridge
      nativeAgent.executeHeavyTask('Scanned ${result.length} projects');

      _localProjects = result;
      _statusMessage = 'Found ${result.length} local projects.';
      LoggerConfig.log('Scan completed successfully: ${result.length} projects found.', level: 'SUCCESS');
    } catch (e) {
      _statusMessage = 'Error scanning projects: $e';
      LoggerConfig.log('Scan failed: $e', level: 'ERROR');
    } finally {
      _isScanningLocal = false;
      _progress = 100;
      notifyListeners();
    }
  }

  /// Scans remote cloud repositories
  Future<void> scanCloudProjects(String remoteOwner, String localRoot) async {
    if (remoteOwner.isEmpty) return;
    _isScanningCloud = true;
    _statusMessage = 'Scanning cloud repositories...';
    notifyListeners();

    try {
      LoggerConfig.log('Fetching cloud repos for owner: $remoteOwner', level: 'INFO');
      final repos = await GitService.getRemoteRepos(remoteOwner);
      
      List<CloudProjectInfo> cloudList = [];
      for (var r in repos) {
        final repoName = r['name'] ?? '';
        final htmlUrl = r['url'] ?? '';
        final updatedAt = r['updated_at'] ?? '';
        final isPrivate = r['is_private'] ?? false;
        
        final localPath = "$localRoot/$repoName";
        String syncStatus = "Not Cloned";

        if (GitService.dirExists(localPath)) {
          final isBehind = await GitService.isBehindRemote(localPath);
          final isDirty = !(await GitService.isClean(localPath));
          if (isBehind) {
            syncStatus = "Needs Pull";
          } else if (isDirty) {
            syncStatus = "Local Modified";
          } else {
            syncStatus = "Up to date";
          }
        }

        cloudList.add(CloudProjectInfo(
          name: repoName,
          kind: 'Git',
          url: htmlUrl,
          updatedAt: updatedAt,
          localPath: localPath,
          syncStatus: syncStatus,
          isPrivate: isPrivate,
        ));
      }

      _cloudProjects = cloudList;
      _statusMessage = 'Found ${cloudList.length} cloud repositories.';
      LoggerConfig.log('Cloud scan completed: ${cloudList.length} repos found.', level: 'SUCCESS');
    } catch (e) {
      _statusMessage = 'Error scanning cloud repos: $e';
      LoggerConfig.log('Cloud scan failed: $e', level: 'ERROR');
    } finally {
      _isScanningCloud = false;
      notifyListeners();
    }
  }

  /// Applies standard forms (.gitignore, push.bat, README, LICENSE, ABOUT.txt)
  Future<void> applyStandardForms(List<String> projectPaths, String authorName, String remoteBaseUrl) async {
    _statusMessage = 'Applying standard forms...';
    notifyListeners();

    int updatedCount = 0;
    for (var path in projectPaths) {
      final proj = _localProjects.firstWhere((p) => p.path == path, orElse: () => ProjectInfo(
        name: '', path: path, kind: '', hasGit: false, branch: '', hasRemote: false,
        remoteUrl: '', clean: true, gitignoreOk: false, pushBatOk: false, readmeOk: false,
        licenseOk: false, aboutOk: false, hasGitignore: false, standardOk: false, status: '', version: ''
      ));

      if (proj.name.isNotEmpty) {
        GitFormService.ensureStandardForms(
          path: path,
          projectName: proj.name,
          kind: proj.kind,
          authorName: authorName,
          remoteBaseUrl: remoteBaseUrl,
        );
        updatedCount++;
      }
    }

    _statusMessage = 'Applied standard forms to $updatedCount project(s).';
    LoggerConfig.log(_statusMessage, level: 'SUCCESS');
    notifyListeners();
  }
}
