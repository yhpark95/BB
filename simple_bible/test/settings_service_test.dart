import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_bible/services/settings_service.dart';

/// These cover the reading preferences that the reader UI depends on. They run
/// without a database, so they stay fast and do not need the 34MB asset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsService> newService([Map<String, Object> initial = const {}]) async {
    SharedPreferences.setMockInitialValues(initial);
    final service = SettingsService();
    await service.initialize();
    return service;
  }

  group('font size', () {
    test('defaults to the large reading size', () async {
      final settings = await newService();
      expect(settings.fontSize, SettingsService.defaultFontSize);
    });

    test('is clamped to the supported range', () async {
      final settings = await newService();

      await settings.setFontSize(999);
      expect(settings.fontSize, SettingsService.maxFontSize);

      await settings.setFontSize(1);
      expect(settings.fontSize, SettingsService.minFontSize);
    });

    test('a stored out-of-range value is pulled back in on load', () async {
      final settings = await newService({'font_size': 4.0});
      expect(settings.fontSize, SettingsService.minFontSize);
    });

    test('stepping moves by the given amount and stops at the bound', () async {
      final settings = await newService();
      final start = settings.fontSize;

      await settings.stepFontSize(2);
      expect(settings.fontSize, start + 2);

      for (var i = 0; i < 50; i++) {
        await settings.stepFontSize(2);
      }
      expect(settings.fontSize, SettingsService.maxFontSize);
    });
  });

  group('translations', () {
    test('defaults to Korean only', () async {
      final settings = await newService();
      expect(settings.selectedTranslationIds, [2]);
      expect(settings.isDualLanguage, isFalse);
    });

    test('migrates the legacy single-translation key', () async {
      final settings = await newService({'translation_id': 1});
      expect(settings.selectedTranslationIds, [1]);
    });

    test('holds at most two, dropping the oldest', () async {
      final settings = await newService();
      await settings.toggleTranslation(1);
      await settings.toggleTranslation(3);
      expect(settings.selectedTranslationIds.length, 2);
    });

    test('never removes the last remaining translation', () async {
      final settings = await newService();
      await settings.toggleTranslation(2);
      expect(settings.selectedTranslationIds, [2]);
    });

    test('sorts to the KR / EN / FR reading order', () async {
      final settings = await newService({'selected_translations': '1'});
      await settings.toggleTranslation(2);
      expect(settings.selectedTranslationIds, [2, 1]);
    });

    test('ensureTranslationVisible adds without displacing the current one',
        () async {
      final settings = await newService();
      await settings.ensureTranslationVisible(1);
      expect(settings.selectedTranslationIds, containsAll(<int>[2, 1]));

      // Already visible — must be a no-op, not a toggle-off.
      await settings.ensureTranslationVisible(1);
      expect(settings.selectedTranslationIds, containsAll(<int>[2, 1]));
    });
  });

  group('reading position', () {
    test('is absent on a first run and set after saving', () async {
      final settings = await newService();
      expect(settings.hasLastPosition, isFalse);

      await settings.saveLastPosition(bookNum: '43', chapter: 3, verseUid: 43003016);
      expect(settings.hasLastPosition, isTrue);
      expect(settings.lastBookNum, '43');
      expect(settings.lastChapter, 3);
    });

    test('survives a restart', () async {
      final settings = await newService();
      await settings.saveLastPosition(bookNum: '19', chapter: 23);

      final restarted = SettingsService();
      await restarted.initialize();
      expect(restarted.lastBookNum, '19');
      expect(restarted.lastChapter, 23);
    });
  });

  group('one-time verse hint', () {
    test('line spacing and verse gap are clamped and persist', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsService();
      await settings.initialize();

      expect(settings.lineHeight, SettingsService.defaultLineHeight);
      expect(settings.verseGap, SettingsService.defaultVerseGap);

      await settings.setLineHeight(99);
      expect(settings.lineHeight, SettingsService.maxLineHeight);
      await settings.stepVerseGap(-999);
      expect(settings.verseGap, SettingsService.minVerseGap);

      await settings.setLineHeight(1.6);
      await settings.setVerseGap(10);

      final restarted = SettingsService();
      await restarted.initialize();
      expect(restarted.lineHeight, 1.6);
      expect(restarted.verseGap, 10);
    });

    test('a stored value outside the range is brought back in', () async {
      SharedPreferences.setMockInitialValues(
          {'line_height': 5.0, 'verse_gap': -3.0});
      final settings = SettingsService();
      await settings.initialize();
      expect(settings.lineHeight, SettingsService.maxLineHeight);
      expect(settings.verseGap, SettingsService.minVerseGap);
    });

  });

  group('text weight', () {
    test('maps the bold switch onto a FontWeight', () async {
      final settings = await newService();
      expect(settings.textWeight, FontWeight.w400);

      await settings.setBoldText(true);
      expect(settings.textWeight, FontWeight.w700);
    });
  });
}
