import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/install_source.dart';
import 'package:simple_bible/widgets/install_banner.dart';

class _Fake implements InstallSource {
  @override
  InstallPlatform platform;
  @override
  bool installed;
  @override
  bool canPrompt;
  int prompts = 0;
  final _c = StreamController<void>.broadcast();

  _Fake(this.platform,
      {this.installed = false, this.canPrompt = false});

  @override
  Future<bool> prompt() async {
    prompts++;
    canPrompt = false;
    return true;
  }

  @override
  Stream<void> get changes => _c.stream;
  void change() => _c.add(null);
}

void main() {
  group('shouldOfferInstall', () {
    test('iPhone, not installed', () {
      expect(shouldOfferInstall(_Fake(InstallPlatform.ios), dismissed: false),
          isTrue);
    });
    test('already installed: never', () {
      expect(
          shouldOfferInstall(_Fake(InstallPlatform.ios, installed: true),
              dismissed: false),
          isFalse);
      expect(
          shouldOfferInstall(
              _Fake(InstallPlatform.android, installed: true, canPrompt: true),
              dismissed: false),
          isFalse);
    });
    test('Android only once Chrome gave its prompt', () {
      expect(
          shouldOfferInstall(_Fake(InstallPlatform.android), dismissed: false),
          isFalse);
      expect(
          shouldOfferInstall(_Fake(InstallPlatform.android, canPrompt: true),
              dismissed: false),
          isTrue);
    });
    test('desktop and the Android app: never', () {
      expect(shouldOfferInstall(_Fake(InstallPlatform.other), dismissed: false),
          isFalse);
    });
    test('closed by the reader: never again', () {
      expect(shouldOfferInstall(_Fake(InstallPlatform.ios), dismissed: true),
          isFalse);
    });
  });

  Future<void> pump(WidgetTester t, _Fake s,
      {bool dismissed = false, void Function()? onSave}) {
    return t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          InstallBanner(
            source: s,
            loadDismissed: () async => dismissed,
            saveDismissed: () async => onSave?.call(),
          ),
          const Expanded(child: SizedBox()),
        ]),
      ),
    ));
  }

  testWidgets('iPhone: shows how, with the steps', (t) async {
    await pump(t, _Fake(InstallPlatform.ios));
    await t.pump();
    expect(find.textContaining('홈 화면에 추가하면'), findsOneWidget);
    await t.tap(find.text('방법'));
    await t.pump();
    expect(find.textContaining("'홈 화면에 추가'를 고르세요"), findsOneWidget);
    expect(find.textContaining('Safari'), findsOneWidget);
    await t.tap(find.text('접기'));
    await t.pump();
    expect(find.textContaining("'홈 화면에 추가'를 고르세요"), findsNothing);
  });

  testWidgets("Android: the button opens Chrome's install, then hides",
      (t) async {
    final s = _Fake(InstallPlatform.android, canPrompt: true);
    await pump(t, s);
    await t.pump();
    expect(find.text('앱으로 설치할 수 있어요'), findsOneWidget);
    await t.tap(find.text('설치'));
    await t.pump();
    expect(s.prompts, 1);
    expect(find.text('앱으로 설치할 수 있어요'), findsNothing);
  });

  testWidgets("Android: appears when Chrome's prompt arrives late",
      (t) async {
    final s = _Fake(InstallPlatform.android);
    await pump(t, s);
    await t.pump();
    expect(find.text('앱으로 설치할 수 있어요'), findsNothing);
    s.canPrompt = true;
    s.change();
    await t.pump(); // the event is delivered after this frame is built
    await t.pump();
    expect(find.text('앱으로 설치할 수 있어요'), findsOneWidget);
  });

  testWidgets('closing it remembers, and a saved close keeps it hidden',
      (t) async {
    var saved = 0;
    await pump(t, _Fake(InstallPlatform.ios), onSave: () => saved++);
    await t.pump();
    await t.tap(find.byTooltip('닫기'));
    await t.pump();
    expect(find.textContaining('홈 화면에 추가하면'), findsNothing);
    expect(saved, 1);

    await pump(t, _Fake(InstallPlatform.ios), dismissed: true);
    await t.pump();
    expect(find.textContaining('홈 화면에 추가하면'), findsNothing);
  });

  testWidgets('installed: nothing shown', (t) async {
    await pump(t, _Fake(InstallPlatform.ios, installed: true));
    await t.pump();
    expect(find.textContaining('홈 화면에'), findsNothing);
  });

  testWidgets('fits a narrow phone at the largest text', (t) async {
    await t.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => t.binding.setSurfaceSize(null));
    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(t, _Fake(InstallPlatform.ios));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('방법'), findsOneWidget);
  });
}
