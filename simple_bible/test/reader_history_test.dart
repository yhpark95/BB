import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_bible/models/book.dart';
import 'package:simple_bible/models/verse.dart';
import 'package:simple_bible/screens/reader_screen.dart';
import 'package:simple_bible/services/database_service.dart';
import 'package:simple_bible/services/settings_service.dart';
import 'package:simple_bible/utils/korean_wrap.dart';

/// Back used to end at an exit dialog that called
/// SystemNavigator.pop() — it quit the app rather than going back, and it did
/// so even after the reader had jumped in from a bookmark or a search result.
/// These tests pin the history that replaced it.

final _books = [
  Book(bookNum: '40', nameKo: '마태복음', nameEn: 'Matthew', testament: 'NT',
      displayOrder: 40),
  Book(bookNum: '43', nameKo: '요한복음', nameEn: 'John', testament: 'NT',
      displayOrder: 43),
];

class _Db extends DatabaseService {
  @override
  Future<List<Book>> getAllBooks() async => _books;

  @override
  Future<int> getChapterCount(String bookNum, {int translationId = 1}) async =>
      28;

  @override
  Future<Set<int>> bookmarkedAmong(List<int> verseUids) async => {};

  @override
  Future<Map<String, int>> getChapterCounts({int translationId = 1}) async =>
      {'40': 28, '43': 21};

  @override
  Future<List<Book>> getBooksByTestament(String testament) async => _books;

  @override
  Future<List<Verse>> getChapter({
    required String bookNum,
    required int chapter,
    int translationId = 1,
  }) async {
    final name =
        _books.firstWhere((b) => b.bookNum == bookNum).nameKo;
    return [
      Verse(
          id: 1,
          verseUid: int.parse(bookNum) * 100000 + chapter,
          translationId: translationId,
          bookNum: bookNum,
          chapter: chapter,
          verse: 1,
          text: '$name $chapter장 본문입니다'),
    ];
  }
}

/// The title pill. Finding it by its text alone would also match the verse on
/// screen, which carries the same book name.
Finder _titlePill() => find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(InkWell),
    );

/// What the reader is showing, read off the rendered text.
String _showing(WidgetTester tester) {
  final out = <String>[];
  void walk(RenderObject node) {
    if (node is RenderParagraph) {
      out.add(node.text.toPlainText().replaceAll(wordJoiner, ''));
    }
    node.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  return out.firstWhere((t) => t.contains('본문입니다'), orElse: () => '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpReader(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'selected_translations': '2'});
    final settings = SettingsService();
    await settings.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: _Db()),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
        ],
        child: const MaterialApp(
          home: ReaderScreen(bookNum: '43', chapter: 3, isRoot: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Presses the system back button.
  Future<bool> pressBack(WidgetTester tester) =>
      tester.binding.handlePopRoute().then((_) => true).catchError((_) => false);

  /// Goes to a book and chapter the way a reader does: the title pill, the
  /// book list, then the chapter grid.
  Future<void> jumpTo(WidgetTester tester, String book, int chapter) async {
    await tester.tap(_titlePill().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(book).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('$chapter').first);
    await tester.pumpAndSettle();
  }

  testWidgets('nothing covers the bottom bar on a first launch',
      (tester) async {
    // A coach SnackBar used to float there for eight seconds, up to three
    // launches, and it swallowed every tap meant for 다음 장 — the first thing
    // anyone does. Selection is a plain tap now and announces itself, so the
    // hint was paying for nothing.
    await pumpReader(tester);

    expect(find.byType(SnackBar), findsNothing);

    final next = find
        .ancestor(of: find.text('다음 장'), matching: find.byType(InkWell))
        .first;
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(_showing(tester), contains('요한복음 4장'),
        reason: 'the chapter button was not reachable on a first launch');
  });

  testWidgets('a jump can be undone with back', (tester) async {
    await pumpReader(tester);
    expect(_showing(tester), contains('요한복음 3장'));

    await jumpTo(tester, '마태복음', 5);
    expect(_showing(tester), contains('마태복음 5장'));

    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(_showing(tester), contains('요한복음 3장'),
        reason: 'back did not return to where the jump started');
  });

  testWidgets('turning pages is reading, not travelling', (tester) async {
    // Otherwise back walks the reader one chapter at a time back through
    // everything they just read.
    await pumpReader(tester);
    await jumpTo(tester, '마태복음', 5);

    // The label sits inside a FittedBox; tap the button around it.
    final next = find
        .ancestor(of: find.text('다음 장'), matching: find.byType(InkWell))
        .first;
    await tester.tap(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(_showing(tester), contains('마태복음 7장'));

    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(_showing(tester), contains('요한복음 3장'),
        reason: 'back stepped through chapters that were merely read');
  });

  testWidgets('several jumps unwind one at a time', (tester) async {
    await pumpReader(tester);
    await jumpTo(tester, '마태복음', 5);
    await jumpTo(tester, '요한복음', 11);
    expect(_showing(tester), contains('요한복음 11장'));

    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(_showing(tester), contains('마태복음 5장'));

    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(_showing(tester), contains('요한복음 3장'));
  });

  testWidgets('with nothing to go back to, leaving is confirmed first',
      (tester) async {
    await pumpReader(tester);
    await pressBack(tester);
    await tester.pumpAndSettle();

    expect(find.text('성경에서 나갈까요?'), findsOneWidget);

    // Leaving must not be the word that also means "dismiss this dialog",
    // and it must not sit where a thumb lands first.
    expect(find.text('닫기'), findsNothing);
    final buttons = tester.widgetList<Widget>(find.byWidgetPredicate(
        (w) => w is TextButton || w is FilledButton));
    expect(buttons.last, isA<FilledButton>(),
        reason: 'the rightmost button should be the one that keeps you here');

    await tester.tap(find.text('계속 읽기'));
    await tester.pumpAndSettle();
    expect(find.text('성경에서 나갈까요?'), findsNothing);
    expect(_showing(tester), contains('요한복음 3장'));
  });

  testWidgets('a jump is undone before leaving is ever offered',
      (tester) async {
    // Back means "go back" while there is anywhere to go; the question only
    // comes up once there is not.
    await pumpReader(tester);
    await jumpTo(tester, '마태복음', 5);

    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('성경에서 나갈까요?'), findsNothing);
    expect(_showing(tester), contains('요한복음 3장'));
  });

  /// The way forward, named by where it leads.
  Finder forwardTo(String label) => find
      .ancestor(of: find.text('앞으로 · $label'), matching: find.byType(InkWell));

  testWidgets('going back offers the way forward again', (tester) async {
    await pumpReader(tester);
    await jumpTo(tester, '마태복음', 5);

    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(_showing(tester), contains('요한복음 3장'));

    // No sentence announcing the move. The title pill and the chapter number
    // already say where the reader is; a snack bar saying it again covered the
    // verses and reappeared on every press of back.
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(forwardTo('마태복음 5장').first);
    await tester.pumpAndSettle();
    expect(_showing(tester), contains('마태복음 5장'),
        reason: 'the way forward did not lead back to the jump');
  });

  testWidgets('the way forward names where it leads', (tester) async {
    // A bare "앞으로" makes the reader press it to find out. The destination
    // is the whole point of the control.
    await pumpReader(tester);
    await jumpTo(tester, '마태복음', 5);

    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('앞으로 · 마태복음 5장'), findsOneWidget);
  });

  testWidgets('the way forward retires once reading resumes', (tester) async {
    // Otherwise it becomes permanent chrome: it would sit above the bottom bar
    // for the rest of the session, which is what was wrong with the snack bar
    // in a slower form.
    await pumpReader(tester);
    await jumpTo(tester, '마태복음', 5);
    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(forwardTo('마태복음 5장'), findsWidgets);

    final next = find
        .ancestor(of: find.text('다음 장'), matching: find.byType(InkWell))
        .first;
    await tester.tap(next);
    await tester.pumpAndSettle();

    expect(forwardTo('마태복음 5장'), findsNothing,
        reason: 'the way forward outstayed the moment it was for');
  });

  testWidgets('a new jump retires the way forward', (tester) async {
    await pumpReader(tester);
    await jumpTo(tester, '마태복음', 5);
    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(forwardTo('마태복음 5장'), findsWidgets);

    await jumpTo(tester, '요한복음', 11);
    expect(forwardTo('마태복음 5장'), findsNothing,
        reason: 'branching off left a way forward that no longer exists');
  });

  testWidgets('the recent list holds jumps, not pages turned', (tester) async {
    await pumpReader(tester);
    await jumpTo(tester, '마태복음', 5);

    final next = find
        .ancestor(of: find.text('다음 장'), matching: find.byType(InkWell))
        .first;
    await tester.tap(next);
    await tester.pumpAndSettle();

    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    expect(find.text('최근 본 곳'), findsOneWidget);

    await tester.tap(find.text('최근 본 곳'));
    await tester.pumpAndSettle();
    expect(find.text('마태복음 5장'), findsOneWidget,
        reason: 'the jump is missing from the recent list');
    expect(find.text('마태복음 6장'), findsNothing,
        reason: 'a chapter merely turned to was listed as somewhere visited');
  });

  testWidgets('the recent list is hidden until something is in it',
      (tester) async {
    await pumpReader(tester);
    await tester.tap(find.text('더보기'));
    await tester.pumpAndSettle();
    expect(find.text('최근 본 곳'), findsNothing);
  });

  testWidgets('back inside the picker returns to the book list',
      (tester) async {
    await pumpReader(tester);
    await tester.tap(_titlePill().first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('마태복음').last);
    await tester.pumpAndSettle();
    expect(find.text('책 목록'), findsOneWidget);

    await pressBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('책 목록'), findsNothing,
        reason: 'back closed the picker instead of stepping back a page');
    expect(find.text('구약'), findsOneWidget);
  });
}
