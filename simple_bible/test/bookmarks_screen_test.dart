import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_bible/models/book.dart';
import 'package:simple_bible/models/verse.dart';
import 'package:simple_bible/screens/bookmarks_screen.dart';
import 'package:simple_bible/services/database_service.dart';
import 'package:simple_bible/services/settings_service.dart';

Verse _verse(int n) => Verse(
      id: n,
      verseUid: 1000 + n,
      translationId: 2,
      bookNum: '43',
      chapter: 3,
      verse: n,
      text: '$n절 본문',
    );

class _FakeDb extends DatabaseService {
  final Set<int> stored;
  _FakeDb(this.stored);

  @override
  Future<List<Book>> getAllBooks() async => [
        Book(
          bookNum: '43',
          nameEn: 'John',
          nameKo: '요한복음',
          testament: 'NT',
          displayOrder: 43,
        ),
      ];

  @override
  Future<List<Verse>> getBookmarks({int translationId = 1}) async => [
        for (int n = 1; n <= 3; n++)
          if (stored.contains(1000 + n)) _verse(n),
      ];

  @override
  Future<void> addBookmark(int verseUid) async {
    stored.add(verseUid);
  }

  @override
  Future<void> removeBookmark(int verseUid) async {
    stored.remove(verseUid);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_FakeDb> pumpScreen(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.initialize();
    final db = _FakeDb({1001, 1002, 1003});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: db),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
        ],
        child: MaterialApp(
          home: BookmarksScreen(onSelect: (_, __, ___) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return db;
  }

  testWidgets('undo puts the bookmark back and dismisses the bar',
      (tester) async {
    final db = await pumpScreen(tester);

    await tester.tap(find.byTooltip('북마크 지우기').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();

    expect(db.stored, contains(1001));
    expect(find.text('되돌리기'), findsNothing);
    expect(find.text('요한복음 3장 1절'), findsOneWidget);
  });

  testWidgets('deleting several in a row leaves only one bar behind',
      (tester) async {
    await pumpScreen(tester);

    for (int i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('북마크 지우기').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
    }
    expect(find.text('되돌리기'), findsOneWidget);
  });

  // The undo bar used to stay on screen until the sheet was closed. A
  // ScaffoldMessenger only arms its dismiss timer while its own route is the
  // current one (ScaffoldMessengerState.build), and bookmarks are shown in a
  // modal bottom sheet sitting on top of the app-level messenger's route. The
  // fix is to give the sheet a messenger of its own.
  //
  // The timer itself cannot be observed here — a plain Flutter SnackBar does
  // not auto-dismiss under tester.pump either — so what is pinned is the
  // arrangement that makes the timer possible.
  testWidgets('a sheet gets a messenger of its own, not the app-level one',
      (tester) async {
    late ScaffoldMessengerState rootMessenger;
    late ScaffoldMessengerState sheetMessenger;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (rootContext) {
            rootMessenger = ScaffoldMessenger.of(rootContext);
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: rootContext,
                    builder: (_) => ScaffoldMessenger(
                      child: Builder(
                        builder: (sheetContext) {
                          sheetMessenger =
                              ScaffoldMessenger.of(sheetContext);
                          return const SizedBox(height: 200);
                        },
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(identical(sheetMessenger, rootMessenger), isFalse,
        reason: 'the sheet must not borrow the messenger under it');
  });
}
