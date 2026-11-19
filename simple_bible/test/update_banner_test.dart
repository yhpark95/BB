import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/update_check.dart';
import 'package:simple_bible/widgets/update_banner.dart';

void main() {
  group('isOutdated', () {
    test('differs from latest', () => expect(isOutdated('a', 'b'), isTrue));
    test('same', () => expect(isOutdated('a', 'a'), isFalse));
    test('dev never', () => expect(isOutdated('dev', 'b'), isFalse));
    test('failed check never', () {
      expect(isOutdated('a', null), isFalse);
      expect(isOutdated('a', ''), isFalse);
    });
  });

  Future<void> pump(WidgetTester t,
      {String running = 'v1',
      required Future<String?> Function() fetch,
      Future<void> Function()? onUpdate}) {
    return t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          UpdateBanner(
              running: running,
              fetch: fetch,
              onUpdate: onUpdate ?? () async {},
              interval: const Duration(minutes: 10)),
          const Expanded(child: SizedBox()),
        ]),
      ),
    ));
  }

  testWidgets('shows when a newer build exists, and the button updates',
      (t) async {
    var updated = false;
    await pump(t, fetch: () async => 'v2', onUpdate: () async => updated = true);
    await t.pump();
    expect(find.text('새 버전이 있어요'), findsOneWidget);
    await t.tap(find.text('업데이트'));
    expect(updated, isTrue);
  });

  testWidgets('hidden when current', (t) async {
    await pump(t, fetch: () async => 'v1');
    await t.pump();
    expect(find.text('새 버전이 있어요'), findsNothing);
  });

  testWidgets('a dev build never checks', (t) async {
    var calls = 0;
    await pump(t, running: 'dev', fetch: () async {
      calls++;
      return 'v2';
    });
    await t.pump(const Duration(minutes: 11));
    expect(calls, 0);
    expect(find.text('새 버전이 있어요'), findsNothing);
  });

  testWidgets('re-checks on the interval and shows once a release lands',
      (t) async {
    var latest = 'v1';
    await pump(t, fetch: () async => latest);
    await t.pump();
    expect(find.text('새 버전이 있어요'), findsNothing);
    latest = 'v2';
    await t.pump(const Duration(minutes: 10, seconds: 1));
    expect(find.text('새 버전이 있어요'), findsOneWidget);
  });

  testWidgets('a failing server leaves the bar hidden', (t) async {
    await pump(t, fetch: () async => null);
    await t.pump();
    expect(find.text('새 버전이 있어요'), findsNothing);
  });
}
