import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_bible/models/book.dart';
import 'package:simple_bible/models/verse.dart';
import 'package:simple_bible/services/database_service.dart';
import 'package:simple_bible/services/settings_service.dart';
import 'package:simple_bible/utils/korean_wrap.dart';
import 'package:simple_bible/widgets/reader_pane.dart';

/// Renders the phone reader against a stub database, which is the only way to
/// tell whether a widget the code clearly builds actually reaches the screen.

final Book _james = Book(
  bookNum: '59',
  nameKo: '야고보서',
  nameEn: 'James',
  nameFr: 'Jacques',
  testament: 'NT',
  displayOrder: 59,
);

Verse _verse(int translationId, int n, String text) => Verse(
      id: translationId * 1000 + n,
      verseUid: 59000 + n,
      translationId: translationId,
      bookNum: '59',
      chapter: 2,
      verse: n,
      text: text,
    );

class _FakeDb extends DatabaseService {
  /// A real database answers in about a millisecond; the stub answers in none
  /// at all, which hides the first-load state entirely.
  final Duration delay;
  _FakeDb({this.delay = Duration.zero});

  @override
  Future<List<Book>> getAllBooks() async => [_james];

  @override
  Future<int> getChapterCount(String bookNum, {int translationId = 1}) async =>
      5;

  @override
  Future<List<Verse>> getChapter({
    required String bookNum,
    required int chapter,
    int translationId = 1,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (translationId == 2) {
      if (chapter == 3) {
        return [_verse(2, 1, '내 형제들아 너희는 선생 된 우리가 더 큰 심판을 받을 줄 알고')];
      }
      if (chapter == 7) {
        return [for (int n = 1; n <= 25; n++) _verse(2, n, '한글 $n절')];
      }
      if (chapter == 5) {
        return [
          for (int n = 1; n <= 40; n++)
            _verse(2, n, '$n절입니다 여기에 본문이 이어집니다'),
        ];
      }
      return [
        _verse(2, 1, '내 형제들아 영광의 주 곧 우리 주 예수 그리스도를 믿는 믿음을 너희가 '
            '가졌으니 사람을 외모로 취하지 말라'),
        _verse(2, 2, '만일 너희 회당에 금가락지를 끼고 아름다운 옷을 입은 사람이 들어오고'),
      ];
    }
    if (chapter == 7) {
      return [for (int n = 1; n <= 29; n++) _verse(3, n, 'francais $n')];
    }
    return [
      _verse(3, 1, 'Mes frères, que votre foi en notre glorieux Seigneur '
          'Jésus-Christ soit exempte de toute acception de personnes.'),
      _verse(3, 2, 'Supposez, en effet, quil entre dans votre assemblée un '
          'homme avec un anneau dor et un habit magnifique'),
    ];
  }

  @override
  Future<Set<int>> bookmarkedAmong(List<int> verseUids) async => {};
}

/// Everything the screen is actually painting.
///
/// Verses are RichText, not Text, and Korean runs through joinKoreanWords, so
/// find.text and find.textContaining both miss them — the syllables have word
/// joiners between them. Reading the paragraphs and stripping the joiners is
/// the only reliable way to ask what is on screen.
List<String> _onScreen(WidgetTester tester) {
  final out = <String>[];
  void walk(RenderObject node) {
    if (node is RenderParagraph) {
      out.add(node.text.toPlainText().replaceAll(wordJoiner, ''));
    }
    node.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  return out;
}

/// Where a verse actually sits on screen.
///
/// Being in the widget tree proves nothing here: a chapter is built as a
/// Column inside a scroll view, so every verse exists whether or not it is
/// visible. Only the painted rectangle says whether the reader can see it.
Rect? _rectOf(WidgetTester tester, String snippet) {
  Rect? found;
  void walk(RenderObject node) {
    if (node is RenderParagraph &&
        node.text.toPlainText().replaceAll(wordJoiner, '').contains(snippet)) {
      found ??= MatrixUtils.transformRect(
          node.getTransformTo(null), Offset.zero & node.size);
    }
    node.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  return found;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  SettingsService? lastSettings;

  Future<void> pumpReader(
    WidgetTester tester, {
    required List<int> translations,
    double width = 412,
    int? highlightVerse,
    int chapter = 2,
    int? verse,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(
        {'selected_translations': translations.join(',')});
    final settings = SettingsService();
    await settings.initialize();
    lastSettings = settings;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DatabaseService>.value(value: _FakeDb()),
          ChangeNotifierProvider<SettingsService>.value(value: settings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ReaderPane(
              bookNum: '59',
              chapter: chapter,
              highlightVerse: highlightVerse ?? verse,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dual language shows a header over each column', (tester) async {
    await pumpReader(tester, translations: [2, 3]);

    final texts = _onScreen(tester);

    // Both columns loaded, so this really is the dual-language layout.
    expect(texts.any((t) => t.contains('금가락지')), isTrue,
        reason: 'the Korean column did not render');
    expect(texts.any((t) => t.contains('Mes frères')), isTrue,
        reason: 'the French column did not render');

    expect(texts, contains('야고보서 2장'),
        reason: 'the Korean column has no header');
    expect(texts, contains('Jacques 2'),
        reason: 'the French column has no header');
  });

  testWidgets('the headers are actually visible on screen', (tester) async {
    await pumpReader(tester, translations: [2, 3]);

    final rect = tester.getRect(find.text('야고보서 2장'));
    expect(rect.height, greaterThan(0), reason: 'header collapsed to nothing');
    expect(rect.top, greaterThanOrEqualTo(0),
        reason: 'header is off the top of the screen');
    expect(rect.bottom, lessThan(900),
        reason: 'header is off the bottom of the screen');
  });


  /// True when the verse is painted with the highlight background.
  bool isHighlighted(WidgetTester tester) {
    final container = tester.widgetList<Container>(find.byType(Container)).where(
      (c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration && decoration.color != null;
      },
    );
    // The highlighted verse is the only decorated Container in the verse list.
    return container.isNotEmpty;
  }




  group('arriving from a bookmark', () {
    testWidgets('scrolls to the verse, not just the chapter', (tester) async {
      // Opening a bookmark navigates: a new chapter and a verse to land on.
      // The pane sees that as a navSeq change, which is the path that stopped
      // marking the verse — and with nothing marked there is no anchor to
      // scroll to, so the reader arrived at verse 1 of the right chapter.
      await pumpReader(tester, translations: [2], chapter: 5, verse: 1);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DatabaseService>.value(value: _FakeDb()),
            ChangeNotifierProvider<SettingsService>.value(value: lastSettings!),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ReaderPane(
                bookNum: '59',
                chapter: 5,
                navSeq: 1,
                highlightVerse: 35,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rect = _rectOf(tester, '35절입니다');
      expect(rect, isNotNull);
      expect(rect!.top, greaterThanOrEqualTo(0.0));
      expect(rect.bottom, lessThanOrEqualTo(900.0),
          reason: 'verse 35 is off screen — the reader landed on the chapter, '
              'not the verse');
    });
  });


  group('columns of different lengths', () {
    testWidgets('put the same verse number on both sides', (tester) async {
      // Exodus 7 is 25 verses in Korean and 29 in French. Pairing the two by
      // list position put a different verse on each side of every row.
      await pumpReader(tester, translations: [2, 3], chapter: 7);

      // Take the left and right halves of one row and check they agree.
      for (final n in [3, 12, 25]) {
        final left = _rectOf(tester, '한글 $n절');
        final right = _rectOf(tester, 'francais $n');
        expect(left, isNotNull, reason: 'Korean verse $n missing');
        expect(right, isNotNull, reason: 'French verse $n missing');
        expect((left!.top - right!.top).abs(), lessThan(4),
            reason: 'verse $n is not level with its translation');
      }

      // The four verses French has and Korean does not are still shown.
      expect(_rectOf(tester, 'francais 29'), isNotNull);
    });
  });

  group('with two translations', () {
    testWidgets('the arrival marks both columns, not just the Korean one',
        (tester) async {
      // It is one verse in two languages. Marking only the primary column made
      // the other side look like a different verse — and selection already
      // highlights both, so the two cues disagreed.
      await pumpReader(tester, translations: [2, 3], verse: 2);

      final marked = <double>[];
      void walk(RenderObject node) {
        if (node is RenderDecoratedBox) {
          final d = node.decoration;
          if (d is BoxDecoration && d.color != null) {
            final r = MatrixUtils.transformRect(
                node.getTransformTo(null), Offset.zero & node.size);
            // Below the column headers, which are coloured blocks of their
            // own and would satisfy this test whatever the verses did.
            if (r.top > 60) marked.add(r.left);
          }
        }
        node.visitChildren(walk);
      }

      walk(tester.binding.rootElement!.renderObject!);

      // One block on the left half, one on the right.
      expect(marked.where((x) => x < 206).length, greaterThan(0),
          reason: 'the Korean column is not marked');
      expect(marked.where((x) => x >= 206).length, greaterThan(0),
          reason: 'the second translation is not marked');
    });
  });

  group('a chapter shorter than the screen', () {
    testWidgets('starts at the top, not floating in the middle',
        (tester) async {
      // Chapter 3 of the stub is a single verse — far shorter than the 900dp
      // test screen. Center used to put it halfway down the page.
      await pumpReader(tester, translations: [2]);
      final state = tester.state<ReaderPaneState>(find.byType(ReaderPane));
      state.navigateToChapter(3);
      await tester.pumpAndSettle();

      final verse = tester.getRect(find.byType(RichText).first);
      expect(verse.top, lessThan(120),
          reason: 'the chapter is floating down the page, not at the top');
    });
  });

  group('turning a page', () {
    testWidgets('never blanks the screen', (tester) async {
      await pumpReader(tester, translations: [2]);
      expect(_onScreen(tester).any((t) => t.contains('금가락지')), isTrue);

      final state = tester.state<ReaderPaneState>(find.byType(ReaderPane));
      state.navigateToChapter(3);

      // The frame right after the turn is the one that used to be empty: the
      // old verses were thrown away before the new ones were fetched, so a
      // spinner flashed for a frame or two on a load that takes about a
      // millisecond.
      await tester.pump();
      final duringTurn = _onScreen(tester);
      expect(duringTurn.any((t) => t.contains('불러오고 있어요')), isFalse,
          reason: 'the loading spinner appeared during a page turn');
      expect(duringTurn.any((t) => t.contains('금가락지')), isTrue,
          reason: 'the screen went blank between chapters');

      await tester.pumpAndSettle();
      expect(_onScreen(tester).any((t) => t.contains('더 큰 심판')), isTrue);
    });

    testWidgets('a fast first load shows no spinner at all', (tester) async {
      // Nothing takes long enough to be worth a spinner except unpacking the
      // 34MB Bible on the first launch ever, so a quick load must show none.
      SharedPreferences.setMockInitialValues({'selected_translations': '2'});
      final settings = SettingsService();
      await settings.initialize();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DatabaseService>.value(
                value: _FakeDb(delay: const Duration(milliseconds: 50))),
            ChangeNotifierProvider<SettingsService>.value(value: settings),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ReaderPane(bookNum: '59', chapter: 2)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(_onScreen(tester).any((t) => t.contains('불러오고 있어요')), isFalse,
          reason: 'a 50ms load should never show a spinner');
      await tester.pumpAndSettle();
      expect(_onScreen(tester).any((t) => t.contains('금가락지')), isTrue);
    });

    testWidgets('a genuinely slow first load does show it', (tester) async {
      // The first launch really does wait on the Bible being unpacked, so the
      // stub is made to wait that long too.
      SharedPreferences.setMockInitialValues({'selected_translations': '2'});
      final settings = SettingsService();
      await settings.initialize();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DatabaseService>.value(
                value: _FakeDb(delay: const Duration(seconds: 2))),
            ChangeNotifierProvider<SettingsService>.value(value: settings),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ReaderPane(bookNum: '59', chapter: 2)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(_onScreen(tester).any((t) => t.contains('불러오고 있어요')), isTrue,
          reason: 'a two-second wait with a blank screen looks like a crash');
      await tester.pumpAndSettle();
    });
  });

  group('the jump highlight', () {
    testWidgets('marks the verse arrived at', (tester) async {
      await pumpReader(tester, translations: [2], highlightVerse: 2);
      expect(isHighlighted(tester), isTrue);
    });

    testWidgets('clears on its own if the reader just reads', (tester) async {
      await pumpReader(tester, translations: [2], highlightVerse: 2);
      expect(isHighlighted(tester), isTrue);

      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(isHighlighted(tester), isFalse,
          reason: 'the arrival cue never timed out');
    });

    testWidgets('clears once the reader touches a verse', (tester) async {
      // Arriving from a bookmark highlights the verse. Un-bookmarking it then
      // leaves the highlight behind, and since it is the same background a
      // selected verse gets, the verse looks stuck in selection mode.
      await pumpReader(tester, translations: [2], highlightVerse: 2);
      expect(isHighlighted(tester), isTrue);

      // Tap the verse to select it, then tap again to deselect.
      final verse = find.byType(GestureDetector).first;
      await tester.tap(verse);
      await tester.pumpAndSettle();
      await tester.tap(verse);
      await tester.pumpAndSettle();

      expect(isHighlighted(tester), isFalse,
          reason: 'the jump highlight outlived the visit');
    });
  });

  testWidgets('a single translation gets no header', (tester) async {
    await pumpReader(tester, translations: [2]);
    final texts = _onScreen(tester);
    expect(texts.any((t) => t.contains('금가락지')), isTrue);
    expect(texts, isNot(contains('야고보서 2장')));
  });
}
