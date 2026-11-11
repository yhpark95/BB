import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/services/donation_service.dart';
import 'package:simple_bible/widgets/donation_sheet.dart';

class _FakeGateway implements DonationGateway {
  bool available;
  List<DonationOption> items;
  bool buyStarts;
  final bought = <String>[];
  final _ctl = StreamController<DonationEvent>.broadcast();
  bool disposed = false;

  _FakeGateway({
    this.available = true,
    this.items = const [
      DonationOption(id: 'tip_small', price: '₩1,000'),
      DonationOption(id: 'tip_medium', price: '₩3,000'),
    ],
    this.buyStarts = true,
  });

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<List<DonationOption>> products(List<String> ids) async => items;
  @override
  Future<bool> buy(String id) async {
    bought.add(id);
    return buyStarts;
  }

  void emit(DonationEvent e) => _ctl.add(e);

  @override
  Stream<DonationEvent> get events => _ctl.stream;
  @override
  void dispose() {
    disposed = true;
    _ctl.close();
  }
}

void main() {
  group('DonationService', () {
    test('ready when the store has products', () async {
      final s = DonationService(_FakeGateway());
      await s.load();
      expect(s.state, DonationState.ready);
      expect(s.options.length, 2);
    });

    test('unavailable when the store is missing, or has no products yet',
        () async {
      final a = DonationService(_FakeGateway(available: false));
      await a.load();
      expect(a.state, DonationState.unavailable);
      final b = DonationService(_FakeGateway(items: const []));
      await b.load();
      expect(b.state, DonationState.unavailable);
    });

    test('a store that throws is unavailable, not a crash', () async {
      final s = DonationService(_ThrowingGateway());
      await s.load();
      expect(s.state, DonationState.unavailable);
    });

    test('a purchase that does not start reports failure and can be retried',
        () async {
      final g = _FakeGateway(buyStarts: false);
      final s = DonationService(g);
      await s.load();
      await s.buy(s.options.first);
      expect(s.lastEvent, DonationEvent.failed);
      expect(s.buying, isFalse);
      await s.buy(s.options.first);
      expect(g.bought.length, 2);
    });

    test('a second tap while buying is ignored', () async {
      final g = _FakeGateway();
      final s = DonationService(g);
      await s.load();
      await s.buy(s.options.first);
      await s.buy(s.options.first);
      expect(g.bought.length, 1);
      g.emit(DonationEvent.thanked);
      await Future<void>.delayed(Duration.zero);
      expect(s.buying, isFalse);
      expect(s.lastEvent, DonationEvent.thanked);
    });
  });

  group('DonationSheet', () {
    Future<_FakeGateway> open(WidgetTester tester, _FakeGateway g) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => showDonationSheet(c, gateway: () => g),
              child: const Text('열기'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      return g;
    }

    testWidgets('shows the amounts and says nothing is unlocked',
        (tester) async {
      await open(tester, _FakeGateway());
      expect(find.text('₩1,000'), findsOneWidget);
      expect(find.text('₩3,000'), findsOneWidget);
      expect(find.textContaining('달라지는 건 없어요'), findsOneWidget);
    });

    testWidgets('tapping an amount buys it, thanks, and closes',
        (tester) async {
      final g = await open(tester, _FakeGateway());
      await tester.tap(find.text('₩3,000'));
      await tester.pump();
      expect(g.bought.length, 1);
      g.emit(DonationEvent.thanked);
      await tester.pumpAndSettle();
      expect(find.text('개발자 후원하기'), findsNothing);
      expect(find.text('후원해 주셔서 고맙습니다'), findsOneWidget);
    });

    testWidgets('no store: a calm message and a retry, no amounts',
        (tester) async {
      await open(tester, _FakeGateway(available: false));
      expect(find.textContaining('후원할 수 없어요'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.textContaining('₩'), findsNothing);
    });

    testWidgets('a cancelled purchase leaves the sheet open and usable',
        (tester) async {
      final g = await open(tester, _FakeGateway());
      await tester.tap(find.text('₩1,000'));
      await tester.pump();
      g.emit(DonationEvent.cancelled);
      await tester.pump();
      expect(find.text('₩1,000'), findsOneWidget);
      expect(find.textContaining('결제하지 못했어요'), findsNothing);
    });

    testWidgets('a failed purchase says so', (tester) async {
      final g = await open(tester, _FakeGateway());
      await tester.tap(find.text('₩1,000'));
      await tester.pump();
      g.emit(DonationEvent.failed);
      await tester.pump();
      expect(find.textContaining('결제하지 못했어요'), findsOneWidget);
    });

    testWidgets('closing the sheet releases the store connection',
        (tester) async {
      final g = await open(tester, _FakeGateway());
      await tester.tapAt(const Offset(10, 10)); // the barrier
      await tester.pumpAndSettle();
      expect(g.disposed, isTrue);
    });

    testWidgets('fits a narrow phone at the largest text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await open(tester, _FakeGateway());
      expect(tester.takeException(), isNull);
      expect(find.text('₩1,000'), findsOneWidget);
    });
  });
}

class _ThrowingGateway extends _FakeGateway {
  @override
  Future<bool> isAvailable() async => throw Exception('no play');
}
