import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_bible/screens/settings_screen.dart';
import 'package:simple_bible/services/settings_service.dart';
import 'package:simple_bible/models/book.dart';
import 'package:simple_bible/widgets/reader_bar.dart';

/// Truncation regression tests.
///
/// The overflow suite in layout_test.dart cannot see this failure: an
/// ellipsised line does not overflow, so a bar that renders "마가복음" as
/// "마가…" and "16장" as "1…" passes it. That is exactly what shipped, and what
/// a reader reported from a 412dp phone at a 1.1 font scale.
///
/// So this suite asserts the opposite property — that no chrome label was cut
/// — by walking the render tree for a paragraph that exceeded its line budget.
/// The widths and scales are the ones real phones actually use; Samsung ships
/// a larger default font than 1.0, which is why the small steps matter more
/// than the extremes.
const List<double> _widths = [320, 348, 360, 412, 600, 840];
const List<double> _scales = [1.0, 1.1, 1.3, 1.5, 2.0];

/// The longest names the app can put in a title: the longest Korean book, the
/// longest French one, and a plain short one for contrast.
const List<String> _bookNames = [
  '마가복음',
  '데살로니가전서',
  'Premier livre des Chroniques',
];

/// Fails naming every label that had to be cut to fit.
void expectNothingTruncated(WidgetTester tester) {
  final cut = <String>[];

  void walk(RenderObject node) {
    if (node is RenderParagraph && node.didExceedMaxLines) {
      cut.add('"${node.text.toPlainText()}" (${node.size.width.toInt()}dp)');
    }
    node.visitChildren(walk);
  }

  walk(tester.binding.rootElement!.renderObject!);
  expect(cut, isEmpty, reason: 'labels were cut off: ${cut.join(', ')}');
}

/// The smallest label on screen, measured against the size it would have had
/// at a 1.0 system font scale.
///
/// The raw shrink factor is the wrong yardstick: it is relative to the already
/// enlarged text, so 0.5 at a 2.0 scale is exactly the original size and
/// perfectly fine. What matters is that no label ends up smaller than the
/// design size a reader would see with the font scale untouched.
///
/// shrinkLabel trades truncation for shrinking, which moves the failure rather
/// than removing it: a label squeezed to a third of its size is as useless as
/// an ellipsised one. getRect reports the painted rectangle, which carries the
/// FittedBox transform, so comparing it with the paragraph's own size gives
/// the factor actually applied.
double worstShrink(WidgetTester tester,
    {required double scale, bool report = false}) {
  double worst = 1.0;
  String worstText = '';
  for (final element in find.byType(Text).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph || render.size.height == 0) continue;
    final painted =
        tester.getRect(find.byElementPredicate((e) => e == element));
    final factor = painted.height / render.size.height * scale;
    if (report) {
      debugPrint('SHRINK ${factor.toStringAsFixed(2)} '
          '"${render.text.toPlainText()}"');
    }
    if (factor < worst) {
      worst = factor;
      worstText = render.text.toPlainText();
    }
  }
  if (report) debugPrint('WORST ${worst.toStringAsFixed(2)} "$worstText"');
  return worst;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the detector itself', () {
    // Without this the suite could pass by being unable to fail: every label
    // now sits in a FittedBox, which lays its paragraph out unbounded, so
    // didExceedMaxLines is false whatever happens. This proves the walk still
    // reports a genuinely truncated label.
    testWidgets('reports a label that really was cut', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 40,
            child:
                Text('데살로니가전서', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      Object? failure;
      try {
        expectNothingTruncated(tester);
      } catch (e) {
        failure = e;
      }
      expect(failure, isNotNull,
          reason: 'the truncation walk missed an ellipsised label');
      expect('$failure', contains('데살로니가전서'));
    });

    testWidgets('a shrunk label is measured, not ignored', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('데살로니가전서', maxLines: 1, softWrap: false),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expectNothingTruncated(tester);
      expect(worstShrink(tester, scale: 1.0), lessThan(1.0));
    });
  });

  Future<SettingsService> makeSettings([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final settings = SettingsService();
    await settings.initialize();
    return settings;
  }

  Future<void> pumpAt(
    WidgetTester tester, {
    required double width,
    required double scale,
    required SettingsService settings,
    Widget Function(BuildContext context)? build,
    PreferredSizeWidget Function(BuildContext context)? appBar,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: settings,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Builder(
              builder: (context) => Scaffold(
                appBar: appBar?.call(context),
                body: build?.call(context) ?? const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('folding', () {
    // A Korean book name has no spaces, so folding it to a second line breaks
    // it mid-word: "마가복음" shown as "마가 / 복음". An earlier version of
    // shrinkLabel folded every long label unconditionally and did exactly
    // that, on every screen size, while there was width to spare.
    for (final width in _widths) {
      for (final name in ['마가복음', '데살로니가전서', '요한계시록']) {
        testWidgets('$name stays on one line at ${width.toInt()}dp',
            (tester) async {
          final settings = await makeSettings();
          await pumpAt(
            tester,
            width: width,
            scale: 1.0,
            settings: settings,
            appBar: (context) => readerAppBar(
              context,
              bookLabel: name,
              onBookTap: () {},
              onSearchTap: () {},
              onMoreTap: () {},
            ),
          );
          final height =
              tester.renderObject<RenderParagraph>(find.text(name)).size.height;

          // Calibrate against a name that cannot possibly need two lines,
          // rendered by the same pill in the same style.
          await pumpAt(
            tester,
            width: width,
            scale: 1.0,
            settings: settings,
            appBar: (context) => readerAppBar(
              context,
              bookLabel: '요일',
              onBookTap: () {},
              onSearchTap: () {},
              onMoreTap: () {},
            ),
          );
          final oneLine =
              tester.renderObject<RenderParagraph>(find.text('요일')).size.height;

          expect(height, lessThan(oneLine * 1.5),
              reason: '$name was folded onto a second line');
          await pumpAt(
            tester,
            width: width,
            scale: 1.0,
            settings: settings,
            appBar: (context) => readerAppBar(
              context,
              bookLabel: name,
              onBookTap: () {},
              onSearchTap: () {},
              onMoreTap: () {},
            ),
          );
          expectNothingTruncated(tester);
          expect(worstShrink(tester, scale: 1.0), 1.0,
              reason: '$name should need no shrinking at all');
        });
      }
    }
  });

  group('reader app bar', () {
    for (final width in _widths) {
      for (final scale in _scales) {
        for (final book in _bookNames) {
          testWidgets('$book at ${width.toInt()}dp @${scale}x', (tester) async {
            final settings = await makeSettings();
            await pumpAt(
              tester,
              width: width,
              scale: scale,
              settings: settings,
              appBar: (context) => readerAppBar(
                context,
                bookLabel: book,
                onBookTap: () {},
                onSearchTap: () {},
                onMoreTap: () {},
              ),
            );
            expectNothingTruncated(tester);
            // Looser than the other bars on purpose. Widget tests render
            // with a test font far wider than any real one — "Premier
            // livre des Chroniques" measures 452dp here against roughly
            // 220 on a device — so a 320dp screen shows that one name at
            // 55%. Korean book names, which is what ships by default,
            // never shrink at all.
            expect(
                worstShrink(tester, scale: scale), greaterThanOrEqualTo(0.5));
          });
        }
      }
    }
  });

  group('dual-language column headers', () {
    // Each header sits over half the screen, so it is the tightest place a
    // book name has to fit — and the longest French name is 22 characters.
    final book = Book(
      bookNum: '22',
      nameEn: 'Song of Solomon',
      nameKo: '예레미야애가',
      nameFr: 'Cantique des Cantiques',
      testament: 'OT',
      displayOrder: 22,
    );

    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('fit at ${width.toInt()}dp @${scale}x', (tester) async {
          final settings = await makeSettings();
          await pumpAt(
            tester,
            width: width,
            scale: scale,
            settings: settings,
            // Through columnHeaderRow, the way the readers build it: it is
            // what decides whether a second line is used.
            build: (context) => columnHeaderRow(
              context,
              left: chapterTitleFor(book, 150, 2),
              right: chapterTitleFor(book, 150, 3),
            ),
          );
          expectNothingTruncated(tester);
          expect(worstShrink(tester, scale: scale), greaterThanOrEqualTo(0.5));
        });
      }
    }

    testWidgets('both columns get the same height', (tester) async {
      // Sized independently the two blocks step against each other: the French
      // name folds onto a second line and the Korean one does not, leaving a
      // ragged coloured edge across the top of the page.
      for (final width in [360.0, 412.0, 840.0]) {
        final settings = await makeSettings();
        await pumpAt(
          tester,
          width: width,
          scale: 1.0,
          settings: settings,
          build: (context) => columnHeaderRow(
            context,
            left: '아가 2장',
            right: 'Cantique des Cantiques 2',
          ),
        );
        final heights = find
            .byType(Container)
            .evaluate()
            .map((e) => (e.renderObject as RenderBox).size.height)
            .toSet();
        expect(heights.length, 1,
            reason: 'headers differ in height at ${width.toInt()}dp: $heights');
      }
    });

    testWidgets('grows with the reading size, within limits', (tester) async {
      double headerHeight(WidgetTester t) =>
          t.getSize(find.byType(Container).first).height;

      final small = await makeSettings(
          {'font_size': SettingsService.minFontSize});
      await pumpAt(
        tester,
        width: 412,
        scale: 1.0,
        settings: small,
        build: (context) => Row(children: [
          Expanded(child: columnHeader(context, '마가복음 16장')),
        ]),
      );
      final atMin = headerHeight(tester);

      final large = await makeSettings(
          {'font_size': SettingsService.maxFontSize});
      await pumpAt(
        tester,
        width: 412,
        scale: 1.0,
        settings: large,
        build: (context) => Row(children: [
          Expanded(child: columnHeader(context, '마가복음 16장')),
        ]),
      );
      final atMax = headerHeight(tester);

      // It has to grow — a 13sp header beside 40pt verses is unreadable.
      expect(atMax, greaterThan(atMin));
      // And it has to stop growing: this bar is outside the scroll view, so
      // its height is taken from the chapter permanently. Uncapped it folded
      // to two lines and stood 91dp tall.
      expect(atMax, lessThan(60));
    });

    testWidgets('name the chapter the way each language does', (tester) async {
      final settings = await makeSettings();
      await pumpAt(
        tester,
        width: 840,
        scale: 1.0,
        settings: settings,
        build: (context) => columnHeaderRow(
          context,
          left: chapterTitleFor(book, 3, 2),
          right: chapterTitleFor(book, 3, 3),
        ),
      );
      expect(find.text('예레미야애가 3장'), findsOneWidget);
      expect(find.text('Cantique des Cantiques 3'), findsOneWidget);
    });
  });

  group('reader bottom bar', () {
    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          final settings = await makeSettings();
          await pumpAt(
            tester,
            width: width,
            scale: scale,
            settings: settings,
            build: (context) => Column(
              children: [
                const Expanded(child: SizedBox.expand()),
                // Psalms: the widest chapter numbers in the book.
                readerBottomBar(
                  context,
                  chapter: 150,
                  chapterCount: 150,
                  onPrev: () {},
                  onNext: () {},
                  onChapterTap: () {},
                ),
              ],
            ),
          );
          expectNothingTruncated(tester);
          // 0.9 of the design size, not 1.0: the bottom bar shaves "이전 장"
          // by six per cent on the narrowest phone, which nobody can see. The
          // failures this guards against were 0.4 — a name shrunk to
          // illegibility, the same defect as an ellipsis wearing a disguise.
          expect(worstShrink(tester, scale: scale), greaterThanOrEqualTo(0.9));
        });
      }
    }
  });

  group('verse action bar', () {
    for (final width in _widths) {
      for (final scale in _scales) {
        for (final allBookmarked in [false, true]) {
          testWidgets(
              'fits at ${width.toInt()}dp @${scale}x'
              '${allBookmarked ? ' (bookmarked)' : ''}', (tester) async {
            final settings = await makeSettings();
            await pumpAt(
              tester,
              width: width,
              scale: scale,
              settings: settings,
              build: (context) => Column(
                children: [
                  const Expanded(child: SizedBox.expand()),
                  verseActionBar(
                    context,
                    // One selected verse shows the longest line this bar has.
                    selectedCount: 1,
                    allBookmarked: allBookmarked,
                    onBookmark: () {},
                    onCopy: () {},
                    onClear: () {},
                  ),
                ],
              ),
            );
            expectNothingTruncated(tester);
            // 0.9 of the design size, not 1.0: the bottom bar shaves "이전 장"
            // by six per cent on the narrowest phone, which nobody can see. The
            // failures this guards against were 0.4 — a name shrunk to
            // illegibility, the same defect as an ellipsis wearing a disguise.
            expect(
                worstShrink(tester, scale: scale), greaterThanOrEqualTo(0.9));
            // 0.9 of the design size, not 1.0: the bottom bar shaves "이전 장"
            // by six per cent on the narrowest phone, which nobody can see. The
            // failures this guards against were 0.4 — a name shrunk to
            // illegibility, the same defect as an ellipsis wearing a disguise.
            expect(
                worstShrink(tester, scale: scale), greaterThanOrEqualTo(0.9));
          });
        }
      }
    }
  });

  group('search app bar', () {
    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          final settings = await makeSettings();
          final controller = TextEditingController(text: '사랑');
          addTearDown(controller.dispose);
          await pumpAt(
            tester,
            width: width,
            scale: scale,
            settings: settings,
            appBar: (context) => searchAppBar(
              context,
              controller: controller,
              translationLabel: '프랑스어',
              bookLabel: '66권',
              bookSelected: true,
              onTranslationTap: () {},
              onBookTap: () {},
              onSubmit: () {},
              onClear: () {},
              onChanged: (_) {},
              autofocus: false,
            ),
          );
          expectNothingTruncated(tester);
          // 0.9 of the design size, not 1.0: the bottom bar shaves "이전 장"
          // by six per cent on the narrowest phone, which nobody can see. The
          // failures this guards against were 0.4 — a name shrunk to
          // illegibility, the same defect as an ellipsis wearing a disguise.
          expect(worstShrink(tester, scale: scale), greaterThanOrEqualTo(0.9));
        });
      }
    }
  });

  group('spacing steppers', () {
    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          final settings = await makeSettings({
            'font_size': SettingsService.maxFontSize,
            'line_height': SettingsService.maxLineHeight,
            'verse_gap': SettingsService.maxVerseGap,
          });
          await pumpAt(
            tester,
            width: width,
            scale: scale,
            settings: settings,
            build: (_) => const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SpacingSteppers(),
              ),
            ),
          );
          expectNothingTruncated(tester);
          // 0.9 of the design size, not 1.0: the bottom bar shaves "이전 장"
          // by six per cent on the narrowest phone, which nobody can see. The
          // failures this guards against were 0.4 — a name shrunk to
          // illegibility, the same defect as an ellipsis wearing a disguise.
          expect(worstShrink(tester, scale: scale), greaterThanOrEqualTo(0.9));
        });
      }
    }
  });

  group('settings screen', () {
    for (final width in _widths) {
      for (final scale in _scales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          final settings = await makeSettings();
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            ChangeNotifierProvider<SettingsService>.value(
              value: settings,
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: const SettingsScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expectNothingTruncated(tester);
          // 0.9 of the design size, not 1.0: the bottom bar shaves "이전 장"
          // by six per cent on the narrowest phone, which nobody can see. The
          // failures this guards against were 0.4 — a name shrunk to
          // illegibility, the same defect as an ellipsis wearing a disguise.
          expect(worstShrink(tester, scale: scale), greaterThanOrEqualTo(0.9));
        });
      }
    }
  });
}
