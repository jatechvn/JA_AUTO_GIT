import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'system_service.dart';
import '../utils/constants.dart';
import '../modules/logger_config.dart';


class GitService {
  static String findGitExecutable() {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final currentDir = Directory.current.path;

      final candidates = [
        p.join(exeDir, 'bin', 'git', 'cmd', 'git.exe'),
        p.join(exeDir, 'git', 'cmd', 'git.exe'),
        p.join(currentDir, 'bin', 'git', 'cmd', 'git.exe'),
        p.join(currentDir, 'git', 'cmd', 'git.exe'),
        p.join(currentDir, 'bin', 'git', 'bin', 'git.exe'),
      ];

      for (var cand in candidates) {
        if (File(cand).existsSync()) {
          return cand;
        }
      }

      final res = Process.runSync('where', ['git']);
      if (res.exitCode == 0) {
        final paths = res.stdout.toString().split('\r\n');
        if (paths.isNotEmpty && paths[0].trim().isNotEmpty) {
          return paths[0].trim();
        }
      }
    } catch (_) {}

    final programFiles = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';

    final standardPaths = [
      p.join(programFiles, 'Git', 'cmd', 'git.exe'),
      p.join(programFilesX86, 'Git', 'cmd', 'git.exe'),
      p.join(localAppData, 'Programs', 'Git', 'cmd', 'git.exe'),
    ];

    for (var cand in standardPaths) {
      if (File(cand).existsSync()) {
        return cand;
      }
    }

    return 'git'; // Fallback
  }

  static String findGhExecutable() {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final currentDir = Directory.current.path;

      final bundledCandidates = [
        p.join(exeDir, 'bin', 'gh', 'bin', 'gh.exe'),
        p.join(exeDir, 'bin', 'gh.exe'),
        p.join(exeDir, 'gh', 'gh.exe'),
        p.join(currentDir, 'bin', 'gh', 'bin', 'gh.exe'),
        p.join(currentDir, 'bin', 'gh.exe'),
        p.join(currentDir, 'gh', 'gh.exe'),
      ];

      for (var cand in bundledCandidates) {
        if (File(cand).existsSync()) {
          return cand;
        }
      }

      final res = Process.runSync('where', ['gh']);
      if (res.exitCode == 0) {
        final paths = res.stdout.toString().split('\r\n');
        if (paths.isNotEmpty && paths[0].trim().isNotEmpty) {
          return paths[0].trim();
        }
      }
    } catch (_) {}

    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final programFiles = Platform.environment['ProgramFiles'] ?? '';
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? '';

    final candidates = [
      p.join(localAppData, 'GitHub CLI', 'gh.exe'),
      p.join(programFiles, 'GitHub CLI', 'gh.exe'),
      p.join(programFilesX86, 'GitHub CLI', 'gh.exe'),
    ];

    for (var cand in candidates) {
      if (File(cand).existsSync()) {
        return cand;
      }
    }
    return 'gh'; // Fallback
  }

  static Future<bool> isGithubLoggedIn() async {
    try {
      final gh = findGhExecutable();
      final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
      final res = await Process.run(gh, ['auth', 'status'], environment: env);
      return res.exitCode == 0;
    } catch (e) {
      LoggerConfig.log("isGithubLoggedIn error: $e", level: 'DEBUG');
    }
    return false;
  }

  static Future<String> getGithubUsername() async {
    try {
      final gh = findGhExecutable();
      final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
      final res = await Process.run(gh, ['api', 'user', '-q', '.login'], environment: env);
      if (res.exitCode == 0) {
        final uname = res.stdout.toString().trim();
        if (uname.isNotEmpty) return uname;
      }
    } catch (e) {
      LoggerConfig.log("getGithubUsername error: $e", level: 'DEBUG');
    }
    return '';
  }

  static Future<Map<String, String>> getGithubAccountInfo() async {
    try {
      final gh = findGhExecutable();
      final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
      final res = await Process.run(gh, ['api', 'user'], environment: env);
      if (res.exitCode == 0) {
        final Map<String, dynamic> data = json.decode(res.stdout.toString());
        return {
          'login': data['login']?.toString() ?? '',
          'name': data['name']?.toString() ?? '',
          'avatar': data['avatar_url']?.toString() ?? '',
          'html_url': data['html_url']?.toString() ?? '',
        };
      }
    } catch (e) {
      LoggerConfig.log("getGithubAccountInfo error: $e", level: 'DEBUG');
    }
    return {};
  }

  static Future<bool> logoutGithub() async {
    try {
      final gh = findGhExecutable();
      final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
      final res = await Process.run(gh, ['auth', 'logout', '--hostname', 'github.com'], environment: env);
      LoggerConfig.log("logoutGithub exitCode: ${res.exitCode}", level: 'INFO');
      return res.exitCode == 0;
    } catch (e) {
      LoggerConfig.log("logoutGithub error: $e", level: 'ERROR');
      return false;
    }
  }

  static Future<void> triggerGithubLogin() async {
    try {
      final gh = findGhExecutable();
      final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
      
      if (Platform.isWindows) {
        // Open a visible console window so the user can see the one-time code
        // We use 'start' directly with the gh executable to avoid CMD quoting issues
        await Process.start(
          'cmd.exe', 
          ['/c', 'start', 'GitHub Login', gh, 'auth', 'login', '-h', 'github.com', '-w'], 
          environment: env
        );
      } else {
        await Process.start(gh, ['auth', 'login', '-h', 'github.com', '-w'], environment: env);
      }
    } catch (_) {
        await SystemService.openUrl("https://github.com/login");
    }
  }

  static Future<bool> triggerGithubLoginGui(Function(String) onCodeReceived) async {
    try {
      LoggerConfig.log("triggerGithubLoginGui: Start", level: 'INFO');
      final gh = findGhExecutable();
      LoggerConfig.log("triggerGithubLoginGui: found gh at $gh", level: 'INFO');
      final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
      
      LoggerConfig.log("triggerGithubLoginGui: calling HTTP POST device/code", level: 'INFO');
      final client = HttpClient();
      final req = await client.postUrl(Uri.parse('https://github.com/login/device/code'));
      req.headers.add('Accept', 'application/json');
      req.write('client_id=178c6fc778ccc68e1d6a&scope=repo%20read:org');
      final res = await req.close();
      LoggerConfig.log("triggerGithubLoginGui: HTTP POST closed, status: ${res.statusCode}", level: 'INFO');
      final body = await res.transform(utf8.decoder).join();
      LoggerConfig.log("triggerGithubLoginGui: HTTP POST body: $body", level: 'INFO');
      final data = json.decode(body);
      
      if (data['user_code'] == null) {
        LoggerConfig.log("GH Auth error: $data", level: 'ERROR');
        return false;
      }
      
      final userCode = data['user_code'];
      final deviceCode = data['device_code'];
      final interval = data['interval'] ?? 5;
      
      LoggerConfig.log("triggerGithubLoginGui: userCode=$userCode, calling onCodeReceived", level: 'INFO');
      onCodeReceived(userCode);
      
      // Poll for access token
      int attempts = 0;
      final maxAttempts = (15 * 60) ~/ interval; // 15 mins timeout
      
      LoggerConfig.log("triggerGithubLoginGui: starting poll loop", level: 'INFO');
      while (attempts < maxAttempts) {
        await Future.delayed(Duration(seconds: interval));
        attempts++;
        
        final pollReq = await client.postUrl(Uri.parse('https://github.com/login/oauth/access_token'));
        pollReq.headers.add('Accept', 'application/json');
        pollReq.write('client_id=178c6fc778ccc68e1d6a&device_code=$deviceCode&grant_type=urn:ietf:params:oauth:grant-type:device_code');
        
        final pollRes = await pollReq.close();
        final pollBody = await pollRes.transform(utf8.decoder).join();
        final pollData = json.decode(pollBody);
        
        if (pollData['access_token'] != null) {
          LoggerConfig.log("triggerGithubLoginGui: Got token!", level: 'INFO');
          // Token received, feed it to gh cli
          final token = pollData['access_token'];
          final process = await Process.start(
            gh, 
            ['auth', 'login', '--with-token'], 
            environment: env,
            runInShell: true
          );
          process.stdin.writeln(token);
          await process.stdin.close();
          final exitCode = await process.exitCode;
          LoggerConfig.log("GH Auth login exit code: $exitCode", level: 'INFO');
          return exitCode == 0;
        } else if (pollData['error'] != 'authorization_pending') {
          LoggerConfig.log("GH Auth poll error: ${pollData['error']}", level: 'ERROR');
          return false;
        }
      }
      return false;
    } catch (e) {
      LoggerConfig.log("GH Auth exception: $e", level: 'ERROR');
      return false;
    }
  }

  static Future<bool> initRepo(String projectDir) async {
    try {
      final git = findGitExecutable();
      final res = await Process.run(git, ['init'], workingDirectory: projectDir);
      if (res.exitCode == 0) {
        await Process.run(git, ['branch', '-M', AppConstants.defaultBranch], workingDirectory: projectDir);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static bool dirExists(String path) => Directory(path).existsSync();

  static Future<bool> isClean(String path) async {
    try {
      final out = await _gitOutput(path, ['status', '--porcelain']);
      return out.trim().isEmpty;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> isBehindRemote(String path) async {
    try {
      final out = await _gitOutput(path, ['status', '-sb']);
      return out.contains('behind');
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRemoteRepos(String owner, {String rootDir = '', void Function(String)? log}) async {
    return fetchCloudRepositories(owner, rootDir, log ?? (_) {});
  }

  static Future<bool> commitAndPushProject(
    String projectDir,
    String remoteBase,
    String commitMessage,
    void Function(String) log, {
    bool autoCreateRepo = false,
    bool isPublic = false,
  }) async {
    final absPath = p.absolute(projectDir);
    final projectName = p.basename(absPath);
    final hasGit = Directory(p.join(absPath, '.git')).existsSync();

    if (!hasGit) {
      log("[ERROR] Git repository is not initialized for $projectName. Please create/edit Git form first.\n");
      return false;
    }

    // 1. Ensure Git author identity is configured
    try {
      String userName = await _gitOutput(absPath, ['config', '--get', 'user.name']);
      String userEmail = await _gitOutput(absPath, ['config', '--get', 'user.email']);

      if (userName.isEmpty || userEmail.isEmpty) {
        log("[INFO] Git author identity is unknown. Auto-configuring Git user.name and user.email using GitHub details...\n");
        final gh = findGhExecutable();
        
        String ghName = '';
        String ghEmail = '';

        final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
        final res = await Process.run(gh, ['api', 'user'], environment: env);
        if (res.exitCode == 0) {
          try {
            final data = json.decode(res.stdout);
            ghName = data['name']?.toString() ?? data['login']?.toString() ?? '';
            ghEmail = data['email']?.toString() ?? '';
            if (ghEmail.isEmpty && data['login'] != null) {
              ghEmail = "${data['login']}@users.noreply.github.com";
            }
          } catch (_) {}
        }

        if (ghName.isEmpty) {
          ghName = _resolveOwner(remoteBase) ?? "JA Auto Git User";
        }
        if (ghEmail.isEmpty) {
          final cleanLogin = ghName.replaceAll(' ', '').toLowerCase();
          ghEmail = "$cleanLogin@users.noreply.github.com";
        }

        if (userName.isEmpty) {
          log("[INFO] Setting Git user.name to '$ghName'...\n");
          var ok = await _runCommand(findGitExecutable(), ['config', '--global', 'user.name', ghName], absPath, log);
          if (!ok) {
            await _runCommand(findGitExecutable(), ['config', 'user.name', ghName], absPath, log);
          }
        }

        if (userEmail.isEmpty) {
          log("[INFO] Setting Git user.email to '$ghEmail'...\n");
          var ok = await _runCommand(findGitExecutable(), ['config', '--global', 'user.email', ghEmail], absPath, log);
          if (!ok) {
            await _runCommand(findGitExecutable(), ['config', 'user.email', ghEmail], absPath, log);
          }
        }
      }
    } catch (e) {
      log("[WARN] Auto-configuration of Git identity failed: $e\n");
    }

    final repoName = p.basename(absPath);
    String owner = _resolveOwner(remoteBase) ?? '';
    final git = findGitExecutable();
    final existingRemote = await _gitOutput(absPath, ['remote', 'get-url', 'origin']);

    if (owner.isNotEmpty) {
      final remoteUrl = "https://github.com/$owner/$repoName.git";
      if (autoCreateRepo) {
        final aboutFile = File(p.join(absPath, 'ABOUT.txt'));
        String description = '';
        if (aboutFile.existsSync()) {
          try {
            final lines = aboutFile.readAsLinesSync();
            for (var line in lines) {
              if (line.contains("Description  :")) {
                description = line.split("Description  :")[1].trim();
                break;
              }
            }
            if (description.isEmpty && lines.isNotEmpty) {
              description = lines.first.trim();
            }
          } catch (_) {}
        }

        if (description.isEmpty) {
          description = "Project $repoName managed automatically by JA Auto Git.";
        }
        const homepage = "https://jatechvn.github.io/";
        await _ensureGithubRepo(owner, repoName, log, description, homepage, isPublic);
      }

      await _runCommand(git, ['remote', 'remove', 'origin'], absPath, log);
      await _runCommand(git, ['remote', 'add', 'origin', remoteUrl], absPath, log);
      log("[OK] Remote origin configured: $remoteUrl\n");
    } else if (existingRemote.isNotEmpty) {
      log("[INFO] Using existing remote origin: $existingRemote\n");
    } else {
      log("[WARN] No GitHub Owner and no existing remote origin. Will commit locally only.\n");
    }

    // Stage all changes
    await _runCommand(git, ['add', '.'], absPath, log);

    // Get Staged files status
    final stagedStatus = await _gitOutput(absPath, ['diff', '--cached', '--name-status']);
    if (stagedStatus.isNotEmpty) {
      final List<String> changelogLines = [];
      final List<String> addedFiles = [];
      final List<String> modifiedFiles = [];
      final List<String> deletedFiles = [];
      final List<String> otherFiles = [];

      for (var line in stagedStatus.split('\n')) {
        line = line.trim();
        if (line.isEmpty) continue;

        final parts = line.split('\t');
        if (parts.length >= 2) {
          final status = parts[0].trim();
          final paths = parts.sublist(1);
          final statusChar = status.isNotEmpty ? status[0] : '';
          
          String statusDesc = "Modified";
          if (statusChar == 'A') {
            statusDesc = "Added";
            for (var p in paths) {
              addedFiles.add(p.trim());
            }
          } else if (statusChar == 'D') {
            statusDesc = "Deleted";
            for (var p in paths) {
              deletedFiles.add(p.trim());
            }
          } else if (statusChar == 'R') {
            statusDesc = "Renamed";
            if (paths.length >= 2) {
              otherFiles.add(paths[1].trim());
            }
          } else if (statusChar == 'C') {
            statusDesc = "Copied";
            if (paths.length >= 2) {
              otherFiles.add(paths[1].trim());
            }
          } else if (statusChar == 'T') {
            statusDesc = "Type changed";
            for (var p in paths) {
              otherFiles.add(p.trim());
            }
          } else {
            for (var p in paths) {
              modifiedFiles.add(p.trim());
            }
          }

          final pathsStr = paths.length >= 2 ? paths.join(' -> ') : paths[0];
          changelogLines.add("- $statusDesc: $pathsStr");
        } else {
          changelogLines.add("- Modified: $line");
          modifiedFiles.add(p.basename(line));
        }
      }

      // Determine subject line
      String subject = commitMessage.trim();
      if (subject.isEmpty || subject == "Update project") {
        final totalChanges = addedFiles.length + modifiedFiles.length + deletedFiles.length + otherFiles.length;
        if (totalChanges == 1) {
          if (addedFiles.isNotEmpty) {
            subject = "Add ${p.basename(addedFiles[0])}";
          } else if (deletedFiles.isNotEmpty) {
            subject = "Delete ${p.basename(deletedFiles[0])}";
          } else if (modifiedFiles.isNotEmpty) {
            subject = "Update ${p.basename(modifiedFiles[0])}";
          } else {
            subject = "Update ${p.basename(otherFiles[0])}";
          }
        } else if (totalChanges > 1) {
          final allNames = [...addedFiles, ...modifiedFiles, ...deletedFiles, ...otherFiles]
              .map((f) => p.basename(f))
              .toList();
          if (allNames.length <= 3) {
            subject = "Update ${allNames.join(', ')}";
          } else {
            subject = "Update ${allNames.sublist(0, 2).join(', ')} and ${allNames.length - 2} other files";
          }
        } else {
          subject = "Update project";
        }
      }

      final changelogBody = "Change Log:\n" + changelogLines.join('\n');
      
      // Perform git commit
      await _runCommand(findGitExecutable(), ['commit', '-m', subject, '-m', changelogBody], absPath, log);
      log("[OK] Commit created.\n");
    } else {
      log("[INFO] Nothing new to commit.\n");
      // Check if there are unpushed commits
      final unpushed = await _gitOutput(absPath, ['log', 'origin/${AppConstants.defaultBranch}..HEAD', '--oneline']);
      if (unpushed.isNotEmpty) {
        log("[INFO] Found unpushed commits. Will attempt push.\n");
      }
    }

    final finalRemote = await _gitOutput(absPath, ['remote', 'get-url', 'origin']);
    if (finalRemote.isNotEmpty) {
      log("[INFO] Pushing changes to GitHub ($finalRemote)...\n");
      final git = findGitExecutable();
      var ok = await _runCommand(git, ['push', '-u', 'origin', AppConstants.defaultBranch], absPath, log);

      if (!ok) {
        log("[WARN] Push failed. Attempting 'git pull --rebase' to integrate remote changes...\n");
        final pullOk = await _runCommand(git, ['pull', '--rebase', 'origin', AppConstants.defaultBranch], absPath, log);
        if (pullOk) {
          log("[INFO] Rebase successful! Retrying push...\n");
          ok = await _runCommand(git, ['push', '-u', 'origin', AppConstants.defaultBranch], absPath, log);
        } else {
          log("[WARN] Rebase failed. Trying 'pull --allow-unrelated-histories'...\n");
          final pullUnrelated = await _runCommand(git, ['pull', 'origin', AppConstants.defaultBranch, '--allow-unrelated-histories', '--no-edit'], absPath, log);
          if (pullUnrelated) {
            log("[INFO] Merge successful! Retrying push...\n");
            ok = await _runCommand(git, ['push', '-u', 'origin', AppConstants.defaultBranch], absPath, log);
          }
        }
      }

      if (ok) {
        log("[OK] Push completed successfully.\n");
        return true;
      } else {
        log("[ERROR] Push failed. Check GitHub login, permissions, or branch status.\n");
        return false;
      }
    } else {
      log("[WARN] No remote origin configured. Push skipped.\n");
    }
    return true;
  }

  static Future<List<Map<String, dynamic>>> fetchCloudRepositories(
    String remoteBase,
    String rootDir,
    void Function(String) log,
  ) async {
    final owner = _resolveOwner(remoteBase);
    if (owner == null || owner.isEmpty) {
      log("[WARN] GitHub owner is empty. Cannot list repositories.\n");
      return [];
    }

    final gh = findGhExecutable();
    log("[INFO] Fetching repository list from GitHub...\n");

    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
    final cmdArgs = ['repo', 'list', owner, '--limit', '1000', '--json', 'name,url,description,updatedAt,primaryLanguage,isPrivate'];
    log("\$ ${gh} ${cmdArgs.join(' ')}\n");

    final process = await Process.run(gh, cmdArgs, environment: env);
    if (process.exitCode != 0) {
      log("[ERROR] Failed to list repositories:\n${process.stderr}\n");
      return [];
    }

    try {
      final List<dynamic> repos = json.decode(process.stdout);
      log("[OK] Fetched ${repos.length} repositories from GitHub.\n");
      log("[INFO] Checking local synchronization status for fetched repositories...\n");

      final List<Map<String, dynamic>> cloudProjects = [];

      for (var repo in repos) {
        final name = repo['name']?.toString() ?? '';
        final url = repo['url']?.toString() ?? '';
        final updatedAt = repo['updatedAt']?.toString() ?? '';
        final primaryLang = repo['primaryLanguage'] != null
            ? (repo['primaryLanguage'] as Map)['name']?.toString() ?? ''
            : '';

        // Search locally
        String? localPath;
        final subfolders = ["", "PROJECT_PY", "PROJECT_C#", "PROJECT_AHK", "PROJECT_JS", "PROJECT_PS1"];
        for (var sf in subfolders) {
          final cand = sf.isEmpty ? p.join(rootDir, name) : p.join(rootDir, sf, name);
          if (Directory(cand).existsSync()) {
            localPath = cand;
            break;
          }
        }

        String kind = 'project';
        if (localPath != null) {
          final parentDirName = p.basename(p.dirname(localPath));
          if (parentDirName == "PROJECT_PY") {
            kind = "python";
          } else if (parentDirName == "PROJECT_C#") {
            kind = "c#";
          } else if (parentDirName == "PROJECT_AHK") {
            kind = "ahk";
          } else if (parentDirName == "PROJECT_JS") {
            kind = "node";
          } else if (parentDirName == "PROJECT_PS1") {
            kind = "powershell";
          }
        } else {
          final nameUpper = name.toUpperCase();
          String subfolder = '';
          if (nameUpper.endsWith('_PY')) {
            subfolder = "PROJECT_PY";
            kind = "python";
          } else if (nameUpper.endsWith('_CS')) {
            subfolder = "PROJECT_C#";
            kind = "c#";
          } else if (nameUpper.endsWith('_AHK')) {
            subfolder = "PROJECT_AHK";
            kind = "ahk";
          } else if (nameUpper.endsWith('_NODE')) {
            subfolder = "PROJECT_JS";
            kind = "node";
          } else if (nameUpper.endsWith('_PS1')) {
            subfolder = "PROJECT_PS1";
            kind = "powershell";
          } else if (primaryLang.isNotEmpty) {
            final langL = primaryLang.toLowerCase();
            if (langL.contains('python')) {
              subfolder = "PROJECT_PY";
              kind = "python";
            } else if (langL.contains('c#')) {
              subfolder = "PROJECT_C#";
              kind = "c#";
            } else if (langL.contains('autohotkey') || langL.contains('ahk')) {
              subfolder = "PROJECT_AHK";
              kind = "ahk";
            } else if (langL.contains('javascript') || langL.contains('typescript') || langL.contains('node')) {
              subfolder = "PROJECT_JS";
              kind = "node";
            } else if (langL.contains('powershell') || langL.contains('batch')) {
              subfolder = "PROJECT_PS1";
              kind = "powershell";
            }
          }
          localPath = subfolder.isNotEmpty ? p.join(rootDir, subfolder, name) : p.join(rootDir, name);
        }

        String syncStatus = "Not Cloned";

        if (Directory(localPath).existsSync()) {
          final isGit = Directory(p.join(localPath, '.git')).existsSync();
          if (!isGit) {
            syncStatus = "Local Modified";
          } else {
            final statusOut = await _gitOutput(localPath, ['status', '--short']);
            if (statusOut.isNotEmpty) {
              syncStatus = "Local Modified";
            } else {
              // Fetch to compare
              await Process.run('git', ['fetch', 'origin'], workingDirectory: localPath);
              final branch = await _gitOutput(localPath, ['branch', '--show-current']);
              final activeBranch = branch.isNotEmpty ? branch : 'main';

              // Check ahead/behind
              final out = await _gitOutput(localPath, ['rev-list', '--left-right', '--count', '$activeBranch...origin/$activeBranch']);
              if (out.isNotEmpty) {
                final parts = out.split(RegExp(r'\s+'));
                if (parts.length >= 2) {
                  final behind = int.tryParse(parts[1]) ?? 0;
                  if (behind > 0) {
                    syncStatus = "Needs Pull";
                  } else {
                    syncStatus = "Up to date";
                  }
                } else {
                  syncStatus = "Up to date";
                }
              } else {
                syncStatus = "Up to date";
              }
            }
          }
        }

        cloudProjects.add({
          "name": name,
          "kind": kind,
          "url": url,
          "updated_at": updatedAt,
          "local_path": localPath,
          "sync_status": syncStatus,
          "is_private": repo['isPrivate'] ?? true,
        });
      }
      return cloudProjects;
    } catch (e) {
      log("[ERROR] Comparing statuses failed: $e\n");
      return [];
    }
  }

  static Future<bool> syncCloudProject(Map<String, dynamic> task, void Function(String) log) async {
    final actionType = task['action_type'];
    final repoUrl = task['repo_url'];
    final localPath = task['local_path'];
    final repoName = task['repo_name'];

    if (actionType == "skip") {
      log("[INFO] Skipped project: $repoName\n");
      return true;
    }

    if (actionType == "clone") {
      final parentDir = p.dirname(localPath);
      final parent = Directory(parentDir);
      if (!parent.existsSync()) {
        try {
          parent.createSync(recursive: true);
          log("[INFO] Created parent directory: $parentDir\n");
        } catch (e) {
          log("[ERROR] Failed to create directory $parentDir: $e\n");
          return false;
        }
      }

      final cmd = ['git', 'clone', repoUrl, p.basename(localPath)];
      log("\$ ${cmd.join(' ')} (in $parentDir)\n");
      final process = await Process.run('git', ['clone', repoUrl, p.basename(localPath)], workingDirectory: parentDir);
      
      if (process.stdout.toString().isNotEmpty) log(process.stdout);
      if (process.stderr.toString().isNotEmpty) log(process.stderr);

      if (process.exitCode != 0) {
        log("[ERROR] Failed to clone $repoName\n");
        return false;
      }

      log("[OK] Successfully cloned $repoName to $localPath\n");
      log("[INFO] Standardizing project layout for $repoName...\n");
      try {
        // Run fix git form
        // Lazy-load git form service to avoid cyclic imports
        final file = File(p.join(localPath, '.gitignore'));
        if (file.existsSync()) {
          // git standardizations
          await Process.run('git', ['branch', '-M', AppConstants.defaultBranch], workingDirectory: localPath);
        }
      } catch (e) {
        log("[WARN] Failed to standardize project layout: $e\n");
      }
      return true;
    } else if (actionType == "pull") {
      log("[INFO] Pulling updates for $repoName...\n");
      return await _runCommand('git', ['pull', 'origin', AppConstants.defaultBranch], localPath, log);
    } else if (actionType == "overwrite") {
      log("[WARN] Overwriting local changes for $repoName...\n");
      await _runCommand('git', ['fetch', 'origin'], localPath, log);
      final ok1 = await _runCommand('git', ['reset', '--hard', 'origin/${AppConstants.defaultBranch}'], localPath, log);
      final ok2 = await _runCommand('git', ['pull', 'origin', AppConstants.defaultBranch], localPath, log);
      return ok1 && ok2;
    } else if (actionType == "stash") {
      log("[INFO] Stashing local changes and pulling for $repoName...\n");
      await _runCommand('git', ['stash'], localPath, log);
      final ok = await _runCommand('git', ['pull', 'origin', AppConstants.defaultBranch], localPath, log);
      await _runCommand('git', ['stash', 'pop'], localPath, log);
      return ok;
    }
    return false;
  }

  static Future<List<Map<String, dynamic>>> getGithubCommits(
    String owner,
    String repoName, {
    int perPage = 30,
    required void Function(String) log,
  }) async {
    final gh = findGhExecutable();
    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');

    // 1. Fetch commits
    final commitsCmd = ['api', 'repos/$owner/$repoName/commits?per_page=$perPage'];
    final proc = await Process.run(gh, commitsCmd, environment: env);
    if (proc.exitCode != 0) {
      log("[ERROR] Failed to fetch commits: ${proc.stderr}\n");
      return [];
    }

    List<dynamic> raw = [];
    try {
      raw = json.decode(proc.stdout);
    } catch (e) {
      log("[ERROR] Parse commits JSON: $e\n");
      return [];
    }

    // 2. Fetch tags for annotations
    final Map<String, String> tagMap = {};
    final tagsCmd = ['api', 'repos/$owner/$repoName/tags?per_page=100'];
    final tproc = await Process.run(gh, tagsCmd, environment: env);
    if (tproc.exitCode == 0) {
      try {
        final List<dynamic> tags = json.decode(tproc.stdout);
        for (var tag in tags) {
          final sha = tag['commit']?['sha']?.toString() ?? '';
          final name = tag['name']?.toString() ?? '';
          if (sha.isNotEmpty) {
            tagMap[sha] = name;
          }
        }
      } catch (_) {}
    }

    final List<Map<String, dynamic>> result = [];
    for (var c in raw) {
      final sha = c['sha']?.toString() ?? '';
      final shortSha = sha.length > 7 ? sha.substring(0, 7) : sha;
      final commit = c['commit'] as Map?;
      final author = commit?['author'] as Map?;
      final messageFull = commit?['message']?.toString() ?? '';
      
      final messageLines = messageFull.trim().split('\n');
      final subject = messageLines.isNotEmpty ? messageLines[0] : '';
      final dateRaw = author?['date']?.toString() ?? '';
      final dateShort = dateRaw.length > 10 ? dateRaw.substring(0, 10) : dateRaw;

      result.add({
        "sha": sha,
        "short_sha": shortShort(shortSha),
        "author": author?['name']?.toString() ?? '',
        "subject": subject,
        "message": messageFull,
        "date": dateShort,
        "tag": tagMap[sha] ?? "",
      });
    }

    return result;
  }

  static String shortShort(String sha) {
    return sha.length > 7 ? sha.substring(0, 7) : sha;
  }

  static Future<List<Map<String, dynamic>>> getGithubReleases(
    String owner,
    String repoName, {
    int perPage = 30,
    required void Function(String) log,
  }) async {
    final gh = findGhExecutable();
    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');

    final cmd = ['api', 'repos/$owner/$repoName/releases?per_page=$perPage'];
    final proc = await Process.run(gh, cmd, environment: env);
    if (proc.exitCode != 0) {
      log("[ERROR] Failed to fetch releases: ${proc.stderr}\n");
      return [];
    }

    try {
      final List<dynamic> raw = json.decode(proc.stdout);
      final List<Map<String, dynamic>> result = [];

      for (var r in raw) {
        final List<Map<String, dynamic>> assetsList = [];
        final assets = r['assets'] as List?;
        if (assets != null) {
          for (var a in assets) {
            assetsList.add({
              "name": a['name']?.toString() ?? '',
              "size": a['size'] is int ? a['size'] : 0,
              "browser_download_url": a['browser_download_url']?.toString() ?? '',
            });
          }
        }

        final pubAt = r['published_at']?.toString() ?? '';
        final publishedShort = pubAt.length > 10 ? pubAt.substring(0, 10) : pubAt;

        result.add({
          "id": r['id']?.toString() ?? '',
          "tag": r['tag_name']?.toString() ?? '',
          "name": (r['name']?.toString() ?? '').isNotEmpty ? r['name'] : r['tag_name'],
          "prerelease": r['prerelease'] == true,
          "draft": r['draft'] == true,
          "published_at": publishedShort,
          "body": r['body']?.toString() ?? '',
          "html_url": r['html_url']?.toString() ?? '',
          "assets": assetsList,
        });
      }
      return result;
    } catch (e) {
      log("[ERROR] Parse releases JSON: $e\n");
      return [];
    }
  }

  static Future<bool> renameCloudRepo(
    String remoteBase,
    String oldName,
    String newName,
    void Function(String) log,
  ) async {
    final gh = findGhExecutable();
    final owner = _resolveOwner(remoteBase);
    if (owner == null || owner.isEmpty) {
      log("[ERROR] Owner empty. Rename aborted.\n");
      return false;
    }

    final fullName = "$owner/$oldName";
    log("[CLOUD RENAME] Renaming repository $fullName -> $newName...\n");
    
    final cmd = [gh, 'repo', 'rename', newName, '-R', fullName, '-y'];
    log("\$ ${cmd.join(' ')}\n");

    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
    final process = await Process.run(gh, ['repo', 'rename', newName, '-R', fullName, '-y'], environment: env);
    
    if (process.exitCode == 0) {
      log("[OK] Renamed cloud repository to $newName.\n");
      return true;
    } else {
      log("[ERROR] Failed to rename: ${process.stderr}\n");
      return false;
    }
  }

  static Future<bool> deleteCloudRepos(
    String remoteBase,
    List<String> repoNames,
    void Function(String) log,
    void Function(int) progress,
  ) async {
    final gh = findGhExecutable();
    final owner = _resolveOwner(remoteBase);
    if (owner == null || owner.isEmpty) {
      log("[ERROR] Owner empty. Delete aborted.\n");
      return false;
    }

    final total = repoNames.length;
    int okCount = 0;
    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');

    for (int i = 0; i < total; i++) {
      final name = repoNames[i];
      final fullName = "$owner/$name";
      log("[CLOUD DELETE] Deleting repository $fullName...\n");

      final cmdArgs = ['repo', 'delete', fullName, '--yes'];
      log("\$ ${gh} ${cmdArgs.join(' ')}\n");

      final process = await Process.run(gh, cmdArgs, environment: env);
      if (process.exitCode == 0) {
        log("[OK] Deleted cloud repository $fullName.\n");
        okCount++;
      } else {
        log("[ERROR] Failed to delete: ${process.stderr}\n");
      }
      progress(((i + 1) * 100 ~/ total));
    }
    return okCount == total;
  }

  static Future<bool> changeCloudReposVisibility(
    String remoteBase,
    List<MapEntry<String, String>> repoItems,
    void Function(String) log,
    void Function(int) progress,
  ) async {
    final gh = findGhExecutable();
    final owner = _resolveOwner(remoteBase);
    if (owner == null || owner.isEmpty) {
      log("[ERROR] Owner empty. Visibility update aborted.\n");
      return false;
    }

    final total = repoItems.length;
    int okCount = 0;
    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');

    for (int i = 0; i < total; i++) {
      final item = repoItems[i];
      final name = item.key;
      final vis = item.value; // public, private
      final fullName = "$owner/$name";
      log("[CLOUD VISIBILITY] Changing $fullName to ${vis.toUpperCase()}...\n");

      final cmdArgs = ['repo', 'edit', fullName, '--visibility', vis, '--accept-visibility-change-consequences'];
      log("\$ ${gh} ${cmdArgs.join(' ')}\n");

      final process = await Process.run(gh, cmdArgs, environment: env);
      if (process.exitCode == 0) {
        log("[OK] Changed visibility of $fullName to $vis.\n");
        okCount++;
      } else {
        log("[ERROR] Failed to change visibility: ${process.stderr}\n");
      }
      progress(((i + 1) * 100 ~/ total));
    }
    return okCount == total;
  }

  static Future<bool> pushRelease(
    String projectPath,
    String tag,
    String title,
    String body,
    bool prerelease,
    String? attachPath,
    void Function(String) log,
  ) async {
    final gh = findGhExecutable();
    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');

    final List<String> cmd = [
      'release',
      'create',
      tag,
      '--title',
      title.isNotEmpty ? title : tag,
      '--notes',
      body.isNotEmpty ? body : "Release $tag",
    ];

    if (prerelease) {
      cmd.add('--prerelease');
    }

    if (attachPath != null && attachPath.isNotEmpty && File(attachPath).existsSync()) {
      cmd.add(attachPath);
    }

    log("[INFO] Publishing release $tag via GitHub CLI...\n");
    log("\$ ${gh} ${cmd.join(' ')}\n");

    final process = await Process.run(gh, cmd, workingDirectory: projectPath, environment: env);
    
    if (process.stdout.toString().isNotEmpty) log(process.stdout);
    if (process.stderr.toString().isNotEmpty) log(process.stderr);

    if (process.exitCode == 0) {
      log("[OK] Published release $tag.\n");
      return true;
    } else {
      log("[ERROR] Publish release failed: ${process.stderr}\n");
      return false;
    }
  }

  static Future<bool> createGithubRelease({
    required String owner,
    required String repoName,
    required String tagName,
    required String releaseTitle,
    required String releaseNotes,
    String targetBranch = 'main',
    bool isDraft = false,
    bool isPrerelease = false,
    bool isLatest = true,
    bool generateNotes = false,
    List<String>? assetFilePaths,
    required void Function(String) log,
  }) async {
    final gh = findGhExecutable();
    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
    final repoSlug = "$owner/$repoName";

    log("[INFO] Publishing Release $tagName for $repoSlug (target: $targetBranch)...\n");

    final cmdArgs = <String>[
      'release',
      'create',
      tagName,
      '--target',
      targetBranch.isNotEmpty ? targetBranch : 'main',
      '--title',
      releaseTitle.isNotEmpty ? releaseTitle : tagName,
      '-R',
      repoSlug,
    ];

    if (generateNotes) {
      cmdArgs.add('--generate-notes');
    } else {
      cmdArgs.addAll(['--notes', releaseNotes]);
    }

    if (isDraft) {
      cmdArgs.add('--draft');
    }
    if (isPrerelease) {
      cmdArgs.add('--prerelease');
    }
    if (isLatest && !isDraft && !isPrerelease) {
      cmdArgs.add('--latest');
    }

    if (assetFilePaths != null && assetFilePaths.isNotEmpty) {
      for (var f in assetFilePaths) {
        if (File(f).existsSync()) {
          cmdArgs.add(f);
          log("[INFO] Attaching release asset file: $f\n");
        }
      }
    }

    log("\$ $gh ${cmdArgs.join(' ')}\n");
    final res = await Process.run(gh, cmdArgs, environment: env);
    if (res.stdout.toString().isNotEmpty) log(res.stdout.toString());
    if (res.stderr.toString().isNotEmpty) log(res.stderr.toString());

    if (res.exitCode == 0) {
      log("[OK] Published Release $tagName for $repoSlug successfully!\n");
      return true;
    } else {
      log("[ERROR] Failed to publish release: ${res.stderr}\n");
      return false;
    }
  }

  static Future<Map<String, String>> fetchGithubRepoDocs(String owner, String repoName) async {
    final gh = findGhExecutable();
    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
    final Map<String, String> docs = {};

    // 1. Fetch README.md from GitHub Cloud
    try {
      final res = await Process.run(gh, ['api', 'repos/$owner/$repoName/readme'], environment: env);
      if (res.exitCode == 0) {
        final data = json.decode(res.stdout);
        final contentB64 = (data['content']?.toString() ?? '').replaceAll('\n', '').replaceAll('\r', '');
        if (contentB64.isNotEmpty) {
          final decoded = utf8.decode(base64.decode(contentB64));
          docs['readme'] = decoded;
        }
      }
    } catch (_) {}

    // 2. Fetch CHANGELOG.md from GitHub Cloud
    try {
      final res = await Process.run(gh, ['api', 'repos/$owner/$repoName/contents/CHANGELOG.md'], environment: env);
      if (res.exitCode == 0) {
        final data = json.decode(res.stdout);
        final contentB64 = (data['content']?.toString() ?? '').replaceAll('\n', '').replaceAll('\r', '');
        if (contentB64.isNotEmpty) {
          final decoded = utf8.decode(base64.decode(contentB64));
          docs['changelog'] = decoded;
        }
      }
    } catch (_) {}

    // 3. Auto-generate Release Notes from GitHub API
    try {
      final res = await Process.run(gh, ['api', 'repos/$owner/$repoName/releases/generate-notes', '-f', 'tag_name=v1.0.0'], environment: env);
      if (res.exitCode == 0) {
        final data = json.decode(res.stdout);
        final body = data['body']?.toString() ?? '';
        if (body.isNotEmpty) {
          docs['generated'] = body;
        }
      }
    } catch (_) {}

    // 4. Fetch recent commits summary
    try {
      final res = await Process.run(gh, ['api', 'repos/$owner/$repoName/commits?per_page=10'], environment: env);
      if (res.exitCode == 0) {
        final List<dynamic> commits = json.decode(res.stdout);
        final lines = <String>[];
        for (var c in commits) {
          final msg = (c['commit']?['message']?.toString() ?? '').split('\n').first;
          final sha = (c['sha']?.toString() ?? '').substring(0, 7);
          if (msg.isNotEmpty) {
            lines.add("- $msg ($sha)");
          }
        }
        if (lines.isNotEmpty) {
          docs['commits'] = "## Recent Changes\n${lines.join('\n')}";
        }
      }
    } catch (_) {}

    return docs;
  }

  static Future<List<String>> pickFilesNative({bool allowMultiple = true}) async {
    if (Platform.isWindows) {
      try {
        final multiselect = allowMultiple ? '\$true' : '\$false';
        final script =
            "Add-Type -AssemblyName System.Windows.Forms; \$f = New-Object System.Windows.Forms.OpenFileDialog; \$f.Multiselect = $multiselect; \$f.Title = 'Select Files'; if (\$f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { \$f.FileNames | ForEach-Object { Write-Output \$_ } }";
        final res = await Process.run('powershell', ['-NoProfile', '-Command', script]);
        if (res.exitCode == 0) {
          final lines = res.stdout.toString().split(RegExp(r'[\r\n]+')).where((s) => s.trim().isNotEmpty).toList();
          return lines;
        }
      } catch (e) {
        debugPrint("Native PowerShell FileDialog error: $e");
      }
    }
    return [];
  }


  static Future<String> downloadAsset(String url, String filename, void Function(String) log) async {
    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE'] ?? ''
        : Platform.environment['HOME'] ?? '';
    final destDir = p.join(home, 'Downloads');
    
    // Ensure Directory exists
    Directory(destDir).createSync(recursive: true);
    
    final destPath = p.join(destDir, filename);
    final file = File(destPath);
    if (file.existsSync()) {
      log("[INFO] File already exists: $destPath\n");
      return destPath;
    }

    log("[INFO] Downloading asset from $url...\n");
    log("[INFO] Destination: $destPath\n");

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode == 200) {
        await response.pipe(file.openWrite());
        log("[OK] Download complete.\n");
        return destPath;
      } else {
        throw Exception("Server returned code ${response.statusCode}");
      }
    } catch (e) {
      log("[ERROR] Download failed: $e\n");
      rethrow;
    } finally {
      client.close();
    }
  }

  // --- Subprocess execution helpers ---

  static Future<bool> _runCommand(
    String command,
    List<String> args,
    String workingDir,
    void Function(String) log,
  ) async {
    log("\$ $command ${args.join(' ')}\n");
    try {
      final res = await Process.run(
        command,
        args,
        workingDirectory: workingDir,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.stdout.toString().isNotEmpty) {
        log(res.stdout.toString());
      }
      if (res.stderr.toString().isNotEmpty) {
        log(res.stderr.toString());
      }
      return res.exitCode == 0;
    } catch (e) {
      log("[ERROR] Execute command failed: $e\n");
      return false;
    }
  }

  static Future<String> _gitOutput(String workingDir, List<String> args) async {
    try {
      final res = await Process.run(
        findGitExecutable(),
        args,
        workingDirectory: workingDir,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        return res.stdout.toString().trim();
      }
    } catch (_) {}
    return '';
  }

  static String? _resolveOwner(String remoteBase) {
    var owner = remoteBase.trim().replaceAll(RegExp(r'^https://github.com/'), '').replaceAll(RegExp(r'/$'), '');
    if (owner.endsWith('.git')) {
      owner = owner.substring(0, owner.length - 4);
    }
    if (owner.contains('/')) {
      owner = owner.split('/')[0];
    }
    if (owner.isEmpty) {
      // Fallback: check gh profile
      try {
        final gh = findGhExecutable();
        final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');
        final res = Process.runSync(gh, ['api', 'user', '--jq', '.login'], environment: env);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          return res.stdout.toString().trim();
        }
      } catch (_) {}

      try {
        final res = Process.runSync(findGitExecutable(), ['config', '--get', 'github.user']);
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          return res.stdout.toString().trim();
        }
      } catch (_) {}
    }
    return owner;
  }

  static Future<bool> _ensureGithubRepo(
    String owner,
    String repoName,
    void Function(String) log,
    String description,
    String homepage,
    bool isPublic,
  ) async {
    final gh = findGhExecutable();
    final fullName = "$owner/$repoName";
    final env = Map<String, String>.from(Platform.environment)..remove('GITHUB_TOKEN');

    // 1. Check if repo exists
    final check = await Process.run(gh, ['repo', 'view', fullName], environment: env);
    final exists = check.exitCode == 0;

    if (exists) {
      log("[OK] GitHub repo already exists: $fullName\n");
      final List<String> editArgs = ['repo', 'edit', fullName];
      if (description.isNotEmpty) editArgs.addAll(['-d', description]);
      if (homepage.isNotEmpty) editArgs.addAll(['-h', homepage]);

      log("\$ ${gh} ${editArgs.join(' ')}\n");
      final editRes = await Process.run(gh, editArgs, environment: env);
      if (editRes.exitCode != 0) {
        log("[WARN] Failed to update GitHub repository description/homepage.\n");
      }
      return true;
    }

    // 2. Create repo if missing
    final visibility = isPublic ? "--public" : "--private";
    final List<String> createArgs = ['repo', 'create', fullName, visibility];
    if (description.isNotEmpty) createArgs.addAll(['-d', description]);
    if (homepage.isNotEmpty) createArgs.addAll(['-h', homepage]);

    log("\$ ${gh} ${createArgs.join(' ')}\n");
    final createRes = await Process.run(gh, createArgs, environment: env);
    if (createRes.exitCode != 0) {
      log("[ERROR] Could not create GitHub repository: $fullName\n");
      throw Exception("Could not create GitHub repository: $fullName");
    }
    log("[OK] Created GitHub repository $fullName successfully.\n");
    return true;
  }
}
