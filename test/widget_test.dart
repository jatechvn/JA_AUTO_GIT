import 'package:flutter_test/flutter_test.dart';
import 'package:ja_auto_git/modules/ui/styles.dart';
import 'package:ja_auto_git/utils/constants.dart';

void main() {
  group('App Configuration & Styles Unit Tests', () {
    test('AppConstants configuration is defined', () {
      expect(AppConstants.appName, equals('JA Auto Git'));
      expect(AppConstants.appId, equals('JA_AUTO_GIT'));
    });

    test('AppThemeModeExt conversions work correctly', () {
      expect(AppThemeModeExt.fromCode('dark'), equals(AppThemeMode.dark));
      expect(AppThemeModeExt.fromCode('light'), equals(AppThemeMode.light));
      expect(AppThemeModeExt.fromCode('auto'), equals(AppThemeMode.auto));

      expect(AppThemeMode.dark.code, equals('dark'));
      expect(AppThemeMode.light.code, equals('light'));
      expect(AppThemeMode.auto.code, equals('auto'));
    });
  });
}




