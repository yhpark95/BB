import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_bible/screens/bookmarks_screen.dart';
import 'package:simple_bible/services/database_service.dart';
import 'package:simple_bible/services/settings_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late DatabaseService db;
  late SettingsService settings;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('bb_bm_');
    databaseFactory.setDatabasesPath(tmp.path);
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
    await settings.initialize();
    db = DatabaseService();
    await db.database;
    await db.addBookmark(43003016); // John 3:16
  });

  tearDownAll(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 892));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: db),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
      ],
      child: MaterialApp(
        home: BookmarksScreen(onSelect: (_, __, ___) {}),
      ),
    ));
    await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 600)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('one translation on: only that text is listed', (tester) async {
    await settings.setSingleTranslation(2);
    await pump(tester);
    expect(find.textContaining('요한복음 3장 16절'), findsOneWidget);
    expect(find.textContaining('For God so loved'), findsNothing);
  });

  testWidgets('two translations on: both texts are listed', (tester) async {
    await settings.setSingleTranslation(2);
    await settings.toggleTranslation(1);
    await pump(tester);
    expect(find.textContaining('요한복음 3장 16절'), findsOneWidget);
    expect(find.textContaining('For God so loved'), findsOneWidget);
    await settings.setSingleTranslation(2);
  });

  testWidgets('the transfer button says what it is and opens both actions',
      (tester) async {
    await settings.setSingleTranslation(2);
    await pump(tester);
    expect(find.text('옮기기'), findsOneWidget);
    await tester.tap(find.text('옮기기'));
    await tester.pumpAndSettle();
    expect(find.text('북마크 복사하기'), findsOneWidget);
    expect(find.text('복사한 북마크 가져오기'), findsOneWidget);
  });
}
