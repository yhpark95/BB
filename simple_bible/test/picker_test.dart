import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_bible/models/book.dart';
import 'package:simple_bible/services/database_service.dart';
import 'package:simple_bible/services/settings_service.dart';
import 'package:simple_bible/widgets/book_chapter_picker.dart';
import 'package:simple_bible/widgets/chapter_picker.dart';

/// The book picker was a three-column grid, which left 61dp of text per cell on
/// a 320dp screen and cut every long name. These tests pin the list that
/// replaced it: one book per row, no name cut anywhere, and the book being read
/// marked and scrolled to.

const List<double> _widths = [320, 360, 412, 840];
const List<double> _scales = [1.0, 1.3, 2.0];

Book _book(String num, String ko, String en, String fr, String testament) =>
    Book(
      bookNum: num,
      nameKo: ko,
      nameEn: en,
      nameFr: fr,
      testament: testament,
      displayOrder: int.parse(num),
    );

/// The longest names in each language, plus ordinary ones.
final List<Book> _books = [
  _book('1', '창세기', 'Genesis', 'Genèse', 'OT'),
  _book('22', '예레미야애가', 'Song of Solomon', 'Cantique des Cantiques', 'OT'),
  _book('41', '마가복음', 'Mark', 'Marc', 'NT'),
  _book('52', '데살로니가전서', '1 Thessalonians', '1 Thessaloniciens', 'NT'),
  _book('66', '요한계시록', 'Revelation', 'Apocalypse', 'NT'),
];

class _FakeDb extends DatabaseService {
  @override
  Future<List<Book>> getBooksByTestament(String testament) async =>
      [for (final b in _books) if (b.testament == testament) b];

  @override
  Future<Map<String, int>> getChapterCounts({int translationId = 1}) async =>
      {'1': 50, '22': 8, '41': 16, '52': 5, '66': 22};
}

void expectNothingTruncated(WidgetTester tester) {
  final cut = <String>[];
  void walk(RenderObject node) {
    if (node is RenderParagraph && node.didExceedMaxLines) {
      cut.add('"${node.text.toPlainText()}"');
    }
    node.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  expect(cut, isEmpty, reason: 'labels were cut off: ${cut.join(', ')}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double width = 412,
    double scale = 1.0,
    int translationId = 2,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'selected_translations': '$translationId'});
    final settings = SettingsService();
    await settings.initialize();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: _FakeDb()),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('book list', () {
    for (final width in _widths) {
      for (final scale in _scales) {
        for (final translationId in [2, 1, 3]) {
          testWidgets(
              'no name is cut at ${width.toInt()}dp @${scale}x '
              '(translation $translationId)', (tester) async {
            await pump(
              tester,
              BookChapterPicker(onSelected: (_, __) {}),
              width: width,
              scale: scale,
              translationId: translationId,
            );
            expectNothingTruncated(tester);
          });
        }
      }
    }

    testWidgets('shows each book with how many chapters it has',
        (tester) async {
      await pump(tester, BookChapterPicker(onSelected: (_, __) {}));
      expect(find.text('창세기'), findsOneWidget);
      expect(find.text('50장'), findsOneWidget);
      expect(find.text('예레미야애가'), findsOneWidget);
      expect(find.text('8장'), findsOneWidget);
    });

    testWidgets('opens on the testament of the book being read',
        (tester) async {
      // Reading Revelation should not open on Genesis.
      await pump(
        tester,
        BookChapterPicker(
          initialBook: _books.last,
          currentChapter: 22,
          onSelected: (_, __) {},
        ),
      );
      expect(find.text('마가복음'), findsOneWidget);
      expect(find.text('창세기'), findsNothing);
    });

    testWidgets('marks the book being read', (tester) async {
      await pump(
        tester,
        BookChapterPicker(
          initialBook: _books[2],
          currentChapter: 16,
          onSelected: (_, __) {},
        ),
      );
      // The marker is an arrow beside the name; nothing else in the list has
      // one.
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('choosing a book asks for the chapter next', (tester) async {
      await pump(tester, BookChapterPicker(onSelected: (_, __) {}));
      await tester.tap(find.text('창세기'));
      await tester.pumpAndSettle();
      expect(find.text('창세기'), findsOneWidget);
      // 50 chapters, and a way back.
      expect(find.text('50'), findsOneWidget);
      expect(find.text('책 목록'), findsOneWidget);
    });

    testWidgets('reports both the book and the chapter', (tester) async {
      String? gotBook;
      int? gotChapter;
      await pump(
        tester,
        BookChapterPicker(onSelected: (b, c) {
          gotBook = b;
          gotChapter = c;
        }),
      );
      // The list opens on the Old Testament, so pick from there.
      await tester.tap(find.text('예레미야애가'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      expect(gotBook, '22');
      expect(gotChapter, 7);
    });
  });

  group('chapter grid', () {
    testWidgets('marks the chapter being read', (tester) async {
      await pump(
        tester,
        ChapterPicker(
          bookLabel: '마가복음',
          chapterCount: 16,
          currentChapter: 9,
          onSelected: (_) {},
        ),
      );
      final marked = tester.widget<Material>(
        find.ancestor(
          of: find.text('9'),
          matching: find.byType(Material),
        ).first,
      );
      final plain = tester.widget<Material>(
        find.ancestor(
          of: find.text('8'),
          matching: find.byType(Material),
        ).first,
      );
      expect(marked.color, isNot(plain.color));
    });

    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          await pump(
            tester,
            // Psalms: the most chapters and the widest numbers.
            ChapterPicker(
              bookLabel: '시편',
              chapterCount: 150,
              currentChapter: 119,
              onSelected: (_) {},
            ),
            width: width,
            scale: scale,
          );
          expectNothingTruncated(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('opens near the chapter being read, not at chapter 1',
        (tester) async {
      await pump(
        tester,
        ChapterPicker(
          bookLabel: '시편',
          chapterCount: 150,
          currentChapter: 119,
          onSelected: (_) {},
        ),
      );
      // Chapter 1 is 23 rows above 119; if the grid still started at the top,
      // 119 would not be built at all.
      expect(find.text('119'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });
  });
}
