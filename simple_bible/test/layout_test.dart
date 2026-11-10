import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_bible/screens/settings_screen.dart';
import 'package:simple_bible/services/settings_service.dart';
import 'package:simple_bible/widgets/reader_bar.dart';

/// Overflow regression tests.
///
/// `flutter analyze` cannot see a RenderFlex overflow — it only shows up when
/// something is actually laid out. A widget test does lay things out, and an
/// overflow reports a FlutterError, which fails the test. So every piece of
/// chrome is pumped at the widths this app really meets:
///
///   320  — smallest phone still sold
///   348  — Galaxy Z Fold cover screen (the tightest case, and the one the
///          app-bar pills plus two labeled actions have to survive)
///   411  — ordinary phone
///   600  — the wide-layout breakpoint itself
///   840  — Fold opened flat / small tablet
///  1280  — tablet landscape
///
/// Each width is also run at a 2.0 text scale, because a reader who needs
/// 40pt verses has very likely turned the system font size up too, and that is
/// exactly when fixed-height bars start to burst.
const List<double> _widths = [320, 348, 411, 600, 840, 1280];
const List<double> _textScales = [1.0, 2.0];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> makeSettings([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
    final settings = SettingsService();
    await settings.initialize();
    return settings;
  }

  /// Pumps [child] at a fixed surface size and text scale. Any overflow during
  /// layout or paint surfaces as a test failure.
  Future<void> pumpAt(
    WidgetTester tester, {
    required double width,
    required double textScale,
    required SettingsService settings,
    required Widget Function(BuildContext context) build,
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
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Builder(
              builder: (context) => Scaffold(
                appBar: appBar?.call(context),
                body: build(context),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('reader app bar', () {
    for (final width in _widths) {
      for (final scale in _textScales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          final settings = await makeSettings();
          await pumpAt(
            tester,
            width: width,
            textScale: scale,
            settings: settings,
            appBar: (context) => readerAppBar(
              context,
              // The longest book name in any of the three translations.
              bookLabel: 'Premier livre des Chroniques',
              onBookTap: () {},
              onSearchTap: () {},
              onMoreTap: () {},
            ),
            build: (_) => const SizedBox.expand(),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('search app bar', () {
    for (final width in _widths) {
      for (final scale in _textScales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          final settings = await makeSettings();
          final controller = TextEditingController(text: '사랑');
          addTearDown(controller.dispose);
          await pumpAt(
            tester,
            width: width,
            textScale: scale,
            settings: settings,
            appBar: (context) => searchAppBar(
              context,
              controller: controller,
              // Longest of the three language names, and the book chip in
              // its filtered state — the widest this row ever gets.
              translationLabel: '프랑스어',
              bookLabel: '66권',
              bookSelected: true,
              onTranslationTap: () {},
              onBookTap: () {},
              onSubmit: () {},
              onClear: () {},
              onChanged: (_) {},
              // A focused field in a test steals nothing, but autofocus also
              // brings up layout the bar does not own.
              autofocus: false,
            ),
            build: (_) => const SizedBox.expand(),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('reader bottom bar', () {
    for (final width in _widths) {
      for (final scale in _textScales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          final settings = await makeSettings();
          await pumpAt(
            tester,
            width: width,
            textScale: scale,
            settings: settings,
            build: (context) => Column(
              children: [
                const Expanded(child: SizedBox.expand()),
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
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('verse action bar', () {
    for (final width in _widths) {
      for (final scale in _textScales) {
        // allBookmarked swaps in the longest labels the bar ever carries
        // ("북마크 해제"), so both states are pumped.
        for (final allBookmarked in [false, true]) {
          testWidgets(
              'fits at ${width.toInt()}dp @${scale}x'
              '${allBookmarked ? ' (bookmarked)' : ''}', (tester) async {
            final settings = await makeSettings();
            await pumpAt(
              tester,
              width: width,
              textScale: scale,
              settings: settings,
              build: (context) => Column(
                children: [
                  const Expanded(child: SizedBox.expand()),
                  verseActionBar(
                    context,
                    selectedCount: 12,
                    allBookmarked: allBookmarked,
                    onBookmark: () {},
                    onCopy: () {},
                    onClear: () {},
                  ),
                ],
              ),
            );
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('verse action bar with one verse', () {
    // A single selection shows a longer line that teaches the range gesture.
    for (final width in _widths) {
      for (final scale in _textScales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          final settings = await makeSettings();
          await pumpAt(
            tester,
            width: width,
            textScale: scale,
            settings: settings,
            build: (context) => Column(
              children: [
                const Expanded(child: SizedBox.expand()),
                verseActionBar(
                  context,
                  selectedCount: 1,
                  onBookmark: () {},
                  onCopy: () {},
                  onClear: () {},
                ),
              ],
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('font size stepper', () {
    for (final width in _widths) {
      for (final scale in _textScales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          // Largest reading size — the preview box is at its tallest here.
          final settings =
              await makeSettings({'font_size': SettingsService.maxFontSize});
          await pumpAt(
            tester,
            width: width,
            textScale: scale,
            settings: settings,
            build: (_) => const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: FontSizeStepper(),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('spacing steppers', () {
    for (final width in _widths) {
      for (final scale in _textScales) {
        testWidgets('fits at ${width.toInt()}dp @${scale}x', (tester) async {
          // Loosest possible spacing and largest text: the preview is at its
          // tallest and the two buttons at their widest.
          final settings = await makeSettings({
            'font_size': SettingsService.maxFontSize,
            'line_height': SettingsService.maxLineHeight,
            'verse_gap': SettingsService.maxVerseGap,
          });
          await pumpAt(
            tester,
            width: width,
            textScale: scale,
            settings: settings,
            build: (_) => const SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SpacingSteppers(),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('settings screen', () {
    for (final width in _widths) {
      for (final scale in _textScales) {
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
                  data: MediaQueryData(
                      textScaler: TextScaler.linear(scale)),
                  child: const SettingsScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('more sheet', () {
    for (final width in _widths) {
      testWidgets('opens without overflow at ${width.toInt()}dp',
          (tester) async {
        final settings = await makeSettings();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ChangeNotifierProvider<SettingsService>.value(
            value: settings,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showReaderMoreSheet(
                        context,
                        onBookmarksTap: () {},
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('글자 크기'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('translation sheet', () {
    for (final width in _widths) {
      testWidgets('opens without overflow at ${width.toInt()}dp',
          (tester) async {
        final settings = await makeSettings();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ChangeNotifierProvider<SettingsService>.value(
            value: settings,
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => showTranslationSheet(context),
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('번역본'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
