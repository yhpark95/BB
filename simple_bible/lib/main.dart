import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/reader_screen.dart';
import 'services/database_service.dart';
import 'services/settings_service.dart';

/// Opened on a first run, before any reading position exists: John 3.
const String kDefaultBookNum = '43';
const int kDefaultChapter = 3;

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('[SimpleBible] FlutterError: ${details.exceptionAsString()}');
      debugPrint('[SimpleBible] ${details.stack}');
    };

    final settingsService = SettingsService();
    await settingsService.initialize();
    runApp(SimpleBibleApp(settingsService: settingsService));
  }, (error, stack) {
    debugPrint('[SimpleBible] UncaughtError: $error');
    debugPrint('[SimpleBible] $stack');
  });
}

class SimpleBibleApp extends StatelessWidget {
  final SettingsService settingsService;

  const SimpleBibleApp({super.key, required this.settingsService});

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Comfortable hit targets everywhere — the app is used one-handed by
      // readers who are not precise tappers.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: EdgeInsets.fromLTRB(12, 0, 12, 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>(
          create: (_) => DatabaseService(),
          dispose: (_, db) => db.close(),
        ),
        ChangeNotifierProvider<SettingsService>.value(
          value: settingsService,
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: '성경',
            debugShowCheckedModeBanner: false,
            theme: _theme(Brightness.light),
            darkTheme: _theme(Brightness.dark),
            themeMode: settings.themeMode,
            // The reader IS the app. There is no separate home screen to
            // navigate through — opening the app resumes where you stopped.
            home: ReaderScreen(
              bookNum: settings.lastBookNum ?? kDefaultBookNum,
              chapter: settings.lastChapter ?? kDefaultChapter,
              restoreVerse: settings.lastVerseInLastChapter,
              isRoot: true,
            ),
          );
        },
      ),
    );
  }
}
