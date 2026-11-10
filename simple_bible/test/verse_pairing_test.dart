import 'package:flutter_test/flutter_test.dart';

import 'package:simple_bible/models/verse.dart';
import 'package:simple_bible/utils/verse_pairing.dart';

/// The dual-language reader used to walk both translations by list position.
/// That only works while the two have the same verses, and measured against
/// the shipped text they do not: Korean and French disagree in 104 chapters,
/// Korean and KJV in 5. Exodus 7 is 25 verses in Korean and 29 in French.

Verse _v(int translationId, int n) => Verse(
      id: translationId * 1000 + n,
      // Shared across translations: 2007025 is Exodus 7:25 in all three.
      verseUid: 2007000 + n,
      translationId: translationId,
      bookNum: '02',
      chapter: 7,
      verse: n,
      text: 't$translationId v$n',
    );

void main() {
  group('pairVersesByNumber', () {
    test('lines up equal chapters one for one', () {
      final pairs = pairVersesByNumber(
        [for (int n = 1; n <= 3; n++) _v(2, n)],
        [for (int n = 1; n <= 3; n++) _v(3, n)],
      );
      expect(pairs.length, 3);
      for (final pair in pairs) {
        expect(pair.primary!.verse, pair.verse);
        expect(pair.secondary!.verse, pair.verse);
      }
    });

    test('keeps verses together when one side has extra ones', () {
      // Exodus 7, as shipped: Korean stops at 25, French runs to 29.
      final pairs = pairVersesByNumber(
        [for (int n = 1; n <= 25; n++) _v(2, n)],
        [for (int n = 1; n <= 29; n++) _v(3, n)],
      );

      expect(pairs.length, 29);
      for (final pair in pairs) {
        expect(pair.primary?.verse ?? pair.verse, pair.verse);
        expect(pair.secondary?.verse ?? pair.verse, pair.verse);
      }
      // The four French-only verses sit alone rather than pushing everything
      // else out of step.
      expect(pairs.where((p) => p.primary == null).map((p) => p.verse),
          [26, 27, 28, 29]);
    });

    test('a gap in the middle does not shift the rest', () {
      // The failure the old code produced: one missing verse and every row
      // below it showed two different verses side by side.
      final pairs = pairVersesByNumber(
        [_v(2, 1), _v(2, 3), _v(2, 4)],
        [_v(3, 1), _v(3, 2), _v(3, 3), _v(3, 4)],
      );

      expect(pairs.map((p) => p.verse), [1, 2, 3, 4]);
      expect(pairs[1].primary, isNull);
      expect(pairs[2].primary!.verse, 3);
      expect(pairs[2].secondary!.verse, 3);
      expect(pairs[3].primary!.verse, 4);
      expect(pairs[3].secondary!.verse, 4);
    });

    test('sorts by verse number, not by the order rows arrived in', () {
      final pairs = pairVersesByNumber([_v(2, 3), _v(2, 1)], [_v(3, 2)]);
      expect(pairs.map((p) => p.verse), [1, 2, 3]);
    });

    test('a single translation still produces one row per verse', () {
      final pairs = pairVersesByNumber([_v(2, 1), _v(2, 2)], const []);
      expect(pairs.length, 2);
      expect(pairs.every((p) => p.secondary == null), isTrue);
    });

    test('two empty chapters produce nothing', () {
      expect(pairVersesByNumber(const [], const []), isEmpty);
    });
  });
}
