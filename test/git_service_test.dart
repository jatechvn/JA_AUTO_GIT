import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ja_auto_git/services/git_service.dart';

/// Runs a git command synchronously against [dir] and fails the test loudly if it errors,
/// so a broken test-environment setup doesn't silently produce a false pass/fail below.
ProcessResult _git(String dir, List<String> args) {
  final git = GitService.findGitExecutable();
  final result = Process.runSync(git, args, workingDirectory: dir);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed in $dir:\n${result.stderr}');
  }
  return result;
}

void main() {
  group('GitService.getLocalAheadBehind — local-only, no fetch', () {
    late Directory root;
    late Directory originDir;
    late Directory workDir;

    setUp(() {
      root = Directory.systemTemp.createTempSync('ja_git_test_');
      originDir = Directory(p.join(root.path, 'origin.git'))..createSync();
      workDir = Directory(p.join(root.path, 'work'))..createSync();

      _git(root.path, ['init', '--bare', originDir.path]);
      _git(root.path, ['init', workDir.path]);
      _git(workDir.path, ['checkout', '-b', 'main']);
      _git(workDir.path, ['config', 'user.email', 'test@example.com']);
      _git(workDir.path, ['config', 'user.name', 'Test']);

      File(p.join(workDir.path, 'a.txt')).writeAsStringSync('hello');
      _git(workDir.path, ['add', '.']);
      _git(workDir.path, ['commit', '-m', 'initial commit']);
      _git(workDir.path, ['remote', 'add', 'origin', originDir.path]);
      _git(workDir.path, ['push', '-u', 'origin', 'main']);
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    test('reports 0/0 right after a push (fully in sync)', () async {
      final result = await GitService.getLocalAheadBehind(workDir.path);
      expect(result.ahead, equals(0));
      expect(result.behind, equals(0));
    });

    test('reports ahead=1 after a local commit that has not been pushed', () async {
      File(p.join(workDir.path, 'b.txt')).writeAsStringSync('world');
      _git(workDir.path, ['add', '.']);
      _git(workDir.path, ['commit', '-m', 'second commit']);

      final result = await GitService.getLocalAheadBehind(workDir.path);
      expect(result.ahead, equals(1));
      expect(result.behind, equals(0));
    });

    test('reports behind=1 only after an explicit fetch picks up a remote-side commit', () async {
      // A second clone pushes a commit that `workDir` doesn't have yet.
      final otherClone = Directory(p.join(root.path, 'other'))..createSync();
      _git(root.path, ['clone', originDir.path, otherClone.path]);
      // The bare repo's default HEAD may not point at 'main' (depends on git's global
      // init.defaultBranch), so explicitly check out the branch we actually pushed.
      _git(otherClone.path, ['checkout', 'main']);
      _git(otherClone.path, ['config', 'user.email', 'test2@example.com']);
      _git(otherClone.path, ['config', 'user.name', 'Test2']);
      File(p.join(otherClone.path, 'c.txt')).writeAsStringSync('from other clone');
      _git(otherClone.path, ['add', '.']);
      _git(otherClone.path, ['commit', '-m', 'commit from other clone']);
      _git(otherClone.path, ['push', 'origin', 'main']);

      // Local-only: workDir hasn't fetched yet, so it must NOT see the new remote commit.
      final beforeFetch = await GitService.getLocalAheadBehind(workDir.path);
      expect(beforeFetch.behind, equals(0), reason: 'must not call `git fetch` internally');

      _git(workDir.path, ['fetch', 'origin']);
      final afterFetch = await GitService.getLocalAheadBehind(workDir.path);
      expect(afterFetch.behind, equals(1));
      expect(afterFetch.ahead, equals(0));
    });
  });
}
