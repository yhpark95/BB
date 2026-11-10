import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simple_bible/screens/search_screen.dart';
import 'package:simple_bible/services/database_service.dart';
import 'package:simple_bible/services/settings_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The search screen driven end to end on the PC, against the real Bible.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late DatabaseService db;
  late SettingsService settings;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('bb_ui_');
    databaseFactory.setDatabasesPath(tmp.path);
    SharedPreferences.setMockInitialValues({});
    settings = SettingsService();
    await settings.initialize();
    db = DatabaseService();
    await db.database; // copy the asset once, outside any widget pump
  });

  tearDownAll(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> pumpSearch(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 892));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: db),
        ChangeNotifierProvider<SettingsService>.value(value: settings),
      ],
      child: MaterialApp(
        home: SearchScreen(onSelect: (_, __, ___, ____) {}),
      ),
    ));
    await tester.pump();
  }

  /// Real database I/O does not complete under the test clock; let it run.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> search(WidgetTester tester, String word) async {
    await tester.enterText(find.byType(TextField), word);
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await settle(tester);
  }

  testWidgets('Korean word lists results with the count', (tester) async {
    await pumpSearch(tester);
    await search(tester, '사랑');
    expect(find.textContaining('개 찾았어요'), findsOneWidget);
    expect(find.byType(InputChip), findsOneWidget);
  });

  testWidgets('result text has a real colour, not an inherited-nothing one',
      (tester) async {
    await pumpSearch(tester);
    await search(tester, '사랑');
    // Every result body must be a Text (which inherits the theme colour), not
    // a bare RichText, which painted near-white on the light card.
    final inCards = find.descendant(
        of: find.byType(Card), matching: find.byType(RichText));
    expect(inCards, findsWidgets);
    final bare = tester.widgetList<RichText>(inCards).where((r) =>
        find.ancestor(of: find.byWidget(r), matching: find.byType(Text))
            .evaluate()
            .isEmpty);
    expect(bare, isEmpty);
  });

  testWidgets('keyword bar spans the full width', (tester) async {
    await pumpSearch(tester);
    await search(tester, '사랑');
    final bar = find.ancestor(
        of: find.byType(InputChip), matching: find.byType(Container)).first;
    expect(tester.getSize(bar).width, 412);
  });

  testWidgets('a Latin word searched in Korean offers to switch to English',
      (tester) async {
    await pumpSearch(tester);
    await search(tester, 'love');
    expect(find.text('찾지 못했어요'), findsOneWidget);
    expect(find.text('영어로 찾아보기'), findsOneWidget);

    await tester.tap(find.text('영어로 찾아보기'));
    await tester.pump();
    await settle(tester);
    expect(find.textContaining('개 찾았어요'), findsOneWidget);
    expect(find.text('찾지 못했어요'), findsNothing);
  });

  testWidgets('a nonsense word gives the empty state, no language offer for '
      'a matching language', (tester) async {
    await settings.setSingleTranslation(2);
    await pumpSearch(tester);
    await search(tester, '쀍쀍쀍');
    expect(find.text('찾지 못했어요'), findsOneWidget);
    expect(find.textContaining('로 찾아보기'), findsNothing);
  });

  testWidgets('the field hint changes once a word has moved into a chip',
      (tester) async {
    await settings.setSingleTranslation(2);
    await pumpSearch(tester);
    expect(find.text('찾을 낱말을 넣으세요'), findsOneWidget);
    await search(tester, '사랑');
    expect(find.text('낱말을 더 넣어 좁혀 보세요'), findsOneWidget);
    expect(find.text('찾을 낱말을 넣으세요'), findsNothing);
  });

  testWidgets('two words explain how they are joined, and the pill switches it',
      (tester) async {
    await settings.setSingleTranslation(2);
    await pumpSearch(tester);
    await search(tester, '사랑');
    expect(find.textContaining('그리고'), findsNothing); // one word: no pill
    await search(tester, '믿음');
    expect(find.text('그리고'), findsOneWidget);
    expect(find.textContaining('둘 다 있는 구절만 찾아요'), findsOneWidget);
    final both = find.textContaining('개 찾았어요');
    final bothText = tester.widget<Text>(both).data!;

    await tester.tap(find.text('그리고'));
    await tester.pump();
    await settle(tester);
    expect(find.text('또는'), findsOneWidget);
    expect(find.textContaining('하나라도 있는 구절을 찾아요'), findsOneWidget);
    // OR returns more verses than AND.
    int n(String s) => int.parse(RegExp(r'\d+').firstMatch(s)!.group(0)!);
    expect(n(tester.widget<Text>(both).data!), greaterThan(n(bothText)));
  });

  testWidgets('removing the only keyword returns to the start screen',
      (tester) async {
    await settings.setSingleTranslation(2);
    await pumpSearch(tester);
    await search(tester, '사랑');
    await tester.tap(find.descendant(
        of: find.byType(InputChip), matching: find.byType(Icon)));
    await tester.pump();
    expect(find.byType(InputChip), findsNothing);
    expect(find.textContaining('예:'), findsOneWidget);
  });

  testWidgets('chosen search language survives the keyboard opening',
      (tester) async {
    await settings.setSingleTranslation(1); // reading in English
    await pumpSearch(tester);
    await tester.tap(find.text('영어'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('한국어').last);
    await tester.pumpAndSettle();
    // Simulate what opening the keyboard does: a dependency change.
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump();
    expect(find.widgetWithText(OutlinedButton, '한국어'), findsOneWidget);
    await settings.setSingleTranslation(2);
  });
}
