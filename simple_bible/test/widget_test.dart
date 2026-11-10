import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_bible/services/settings_service.dart';
import 'package:simple_bible/widgets/reader_bar.dart';

/// Widget-level checks on the reader chrome. The reader body needs the SQLite
/// asset, so these cover the bars and sheets around it — which is where the
/// accessibility rules (labels, 48dp targets) actually live.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Widget> wrap(Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.initialize();
    return ChangeNotifierProvider<SettingsService>.value(
      value: settings,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('bottom bar labels both directions in words, not just arrows',
      (tester) async {
    await tester.pumpWidget(await wrap(
      Builder(
        builder: (context) => readerBottomBar(
          context,
          chapter: 3,
          chapterCount: 21,
          onPrev: () {},
          onNext: () {},
          onChapterTap: () {},
        ),
      ),
    ));

    expect(find.text('이전 장'), findsOneWidget);
    expect(find.text('다음 장'), findsOneWidget);
    // One line carries both numbers: the old second line was 11sp and simply
    // repeated the chapter above it.
    expect(find.text('3/21'), findsOneWidget);
  });

  testWidgets('bottom bar navigation buttons are at least 48dp tall',
      (tester) async {
    await tester.pumpWidget(await wrap(
      Builder(
        builder: (context) => readerBottomBar(
          context,
          chapter: 1,
          chapterCount: 5,
          onPrev: () {},
          onNext: () {},
          onChapterTap: () {},
        ),
      ),
    ));

    for (final label in ['이전 장', '다음 장']) {
      final target = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(target.first).height, greaterThanOrEqualTo(48.0));
    }
  });

  testWidgets('the selection bar names each action', (tester) async {
    await tester.pumpWidget(await wrap(
      Builder(
        builder: (context) => Align(
          alignment: Alignment.bottomCenter,
          child: verseActionBar(
            context,
            selectedCount: 2,
            onBookmark: () {},
            onCopy: () {},
            onClear: () {},
          ),
        ),
      ),
    ));

    expect(find.text('구절 2개를 골랐어요'), findsOneWidget);
    expect(find.text('북마크'), findsOneWidget);
    expect(find.text('복사'), findsOneWidget);
    expect(find.text('선택 해제'), findsOneWidget);
  });

  testWidgets('the font stepper changes the stored size and the preview',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: settings,
        child: const MaterialApp(
          home: Scaffold(body: FontSizeStepper()),
        ),
      ),
    );

    final before = settings.fontSize;
    await tester.tap(find.text('크게'));
    await tester.pump();
    expect(settings.fontSize, greaterThan(before));

    await tester.tap(find.text('작게'));
    await tester.pump();
    expect(settings.fontSize, before);
  });

  testWidgets('the font stepper stops at the maximum instead of running away',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'font_size': SettingsService.maxFontSize});
    final settings = SettingsService();
    await settings.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: settings,
        child: const MaterialApp(
          home: Scaffold(body: FontSizeStepper()),
        ),
      ),
    );

    final grow = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('크게'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(grow.onPressed, isNull);
  });
}
