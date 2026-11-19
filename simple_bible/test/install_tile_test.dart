import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/install_source.dart';
import 'package:simple_bible/widgets/install_tile.dart';

class _Fake implements InstallSource {
  @override
  InstallPlatform platform;
  @override
  bool installed;
  @override
  bool canPrompt;
  int prompts = 0;

  _Fake(this.platform, {this.installed = false, this.canPrompt = false});

  @override
  Future<bool> prompt() async {
    prompts++;
    return true;
  }

  @override
  Stream<void> get changes => const Stream.empty();
}

void main() {
  Future<void> pump(WidgetTester t, _Fake s) => t.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(children: [InstallTile(source: s)]))));

  testWidgets('iPhone: opens the steps in a dialog', (t) async {
    await pump(t, _Fake(InstallPlatform.ios));
    expect(find.text('앱으로 설치하기'), findsOneWidget);
    await t.tap(find.text('앱으로 설치하기'));
    await t.pumpAndSettle();
    expect(find.textContaining("'홈 화면에 추가'를 고르세요"), findsOneWidget);
    await t.tap(find.text('확인'));
    await t.pumpAndSettle();
    expect(find.text('홈 화면에 추가하기'), findsNothing);
  });

  testWidgets('Android with Chrome prompt: installs straight away', (t) async {
    final s = _Fake(InstallPlatform.android, canPrompt: true);
    await pump(t, s);
    await t.tap(find.text('앱으로 설치하기'));
    await t.pump();
    expect(s.prompts, 1);
  });

  testWidgets('nothing to install: not shown', (t) async {
    for (final s in [
      _Fake(InstallPlatform.ios, installed: true),
      _Fake(InstallPlatform.android), // Chrome has not offered
      _Fake(InstallPlatform.android, installed: true, canPrompt: true),
      _Fake(InstallPlatform.other),
    ]) {
      await pump(t, s);
      expect(find.text('앱으로 설치하기'), findsNothing);
    }
  });
}
