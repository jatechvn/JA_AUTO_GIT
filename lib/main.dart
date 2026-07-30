import 'package:flutter/material.dart';
import 'modules/ui/main_window.dart';
import 'utils/constants.dart';
import 'modules/ui/styles.dart';
import 'services/settings_service.dart';

import 'modules/build_info.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (args.contains('-debug') || args.contains('--debug')) {
    BuildInfo.isCliDebug = true;
  }

  // Load saved theme
  final settings = SettingsService.loadSettings();
  final savedThemeStr = settings['theme'] ?? 'dark';
  final savedThemeMode = AppThemeModeExt.fromCode(savedThemeStr);

  runApp(MyApp(initialThemeMode: savedThemeMode));
}

class MyApp extends StatefulWidget {
  final AppThemeMode initialThemeMode;
  const MyApp({super.key, required this.initialThemeMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeNotifier _themeNotifier;

  @override
  void initState() {
    super.initState();
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _themeNotifier = ThemeNotifier(widget.initialThemeMode, platformBrightness);
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeNotifier,
      builder: (context, _) {
        final c = _themeNotifier.colors;

        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: buildThemeData(c),
          home: ThemeReveal(
            themeNotifier: _themeNotifier,
            child: DefaultTabController(
              length: 2,
              child: MainWindow(
                themeNotifier: _themeNotifier,
              ),
            ),
          ),
        );
      },
    );
  }
}
