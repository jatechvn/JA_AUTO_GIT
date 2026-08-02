import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:ja_auto_git/services/scanner_service.dart';
import 'package:ja_auto_git/utils/constants.dart';

void main() {
  group('AppConstants.getRequiredGitignoreLines', () {
    test('always includes the global lines', () {
      final lines = AppConstants.getRequiredGitignoreLines('python');
      expect(lines, containsAll(AppConstants.globalGitignoreLines));
    });

    test('adds python-specific lines only for kind=python', () {
      final pythonLines = AppConstants.getRequiredGitignoreLines('python');
      expect(pythonLines, containsAll(AppConstants.pythonGitignoreLines));

      final nodeLines = AppConstants.getRequiredGitignoreLines('node');
      expect(nodeLines, isNot(containsAll(AppConstants.pythonGitignoreLines)));
      expect(nodeLines, containsAll(AppConstants.nodeGitignoreLines));
    });

    test('unknown kind falls back to just the global lines', () {
      final lines = AppConstants.getRequiredGitignoreLines('some_unknown_kind');
      expect(lines, containsAll(AppConstants.globalGitignoreLines));
      expect(lines, isNot(containsAll(AppConstants.pythonGitignoreLines)));
    });
  });

  group('ScannerService.scanProjects — weak vs strong project classification', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('ja_scanner_test_');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('a strong project (dart) is detected even without standard-form files', () async {
      final projDir = Directory(p.join(tempRoot.path, 'MyDartApp'))..createSync(recursive: true);
      File(p.join(projDir.path, 'pubspec.yaml')).writeAsStringSync('name: my_dart_app\n');

      final result = await ScannerService.scanProjects(tempRoot.path);

      expect(result, hasLength(1));
      expect(result.first.name, equals('MyDartApp'));
      expect(result.first.kind, equals('dart'));
    });

    test('a weak project (bare .bat folder) with no child projects is added as a leaf', () async {
      final projDir = Directory(p.join(tempRoot.path, 'ScriptsOnly'))..createSync(recursive: true);
      File(p.join(projDir.path, 'run.bat')).writeAsStringSync('@echo off\n');

      final result = await ScannerService.scanProjects(tempRoot.path);

      expect(result, hasLength(1));
      expect(result.first.name, equals('ScriptsOnly'));
      expect(result.first.kind, equals('batch'));
    });

    test('a weak-kind workspace root (bare .bat + a real project inside) is NOT listed itself — only its child is', () async {
      final workspaceDir = Directory(p.join(tempRoot.path, 'Workspace'))..createSync(recursive: true);
      // The root folder itself only has a stray .bat file (weak signal)...
      File(p.join(workspaceDir.path, 'setup.bat')).writeAsStringSync('@echo off\n');
      // ...but contains a real strong project as a child.
      final childDir = Directory(p.join(workspaceDir.path, 'RealProject'))..createSync(recursive: true);
      File(p.join(childDir.path, 'pubspec.yaml')).writeAsStringSync('name: real_project\n');

      final result = await ScannerService.scanProjects(tempRoot.path);

      expect(result, hasLength(1));
      expect(result.first.name, equals('RealProject'));
      expect(result.first.kind, equals('dart'));
    });
  });
}
