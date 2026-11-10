import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/utils/korean_wrap.dart';

const String _verse =
    '하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니 이는 그를 믿는 자마다 '
    '멸망하지 않고 영생을 얻게 하려 하심이라';

/// The actual lines a paragraph is broken into at [width].
List<String> _linesOf(String text, double width) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontSize: 20)),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);

  final ranges = <String, ui.TextRange>{};
  for (int i = 0; i <= text.length; i++) {
    final r = painter.getLineBoundary(TextPosition(offset: i));
    ranges['${r.start}:${r.end}'] = r;
  }
  final sorted = ranges.values.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  return [
    for (final r in sorted)
      if (r.end > r.start) text.substring(r.start, r.end),
  ];
}

/// Every break lands on a space if no line begins in the middle of a word.
bool _breaksOnlyAtSpaces(String text, double width) {
  int consumed = 0;
  for (final line in _linesOf(text, width)) {
    if (consumed > 0 && text[consumed - 1] != ' ') return false;
    consumed += line.length;
  }
  return true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('joinKoreanWords', () {
    test('leaves Latin text alone — it already breaks only at spaces', () {
      expect(joinKoreanWords('For God so loved the world'),
          'For God so loved the world');
      expect(joinKoreanWords(''), '');
    });

    test('makes each 어절 unbreakable but keeps the spaces', () {
      expect(joinKoreanWords('사랑 하사'),
          '사⁠랑 하⁠사');
    });

    test('does not change the visible text', () {
      expect(joinKoreanWords(_verse).replaceAll(wordJoiner, ''), _verse);
    });

    test('handles a mixed-script verse without touching the Latin word', () {
      expect(joinKoreanWords('요한 John 복음'),
          '요⁠한 John 복⁠음');
    });
  });

  group('line breaking', () {
    // A dual-language column on a phone is about this narrow — the case where
    // the reader complained about words splitting.
    for (final width in [140.0, 200.0, 320.0]) {
      test('plain text still breaks mid-word at ${width.toInt()}dp', () {
        // Guards the test itself: if Flutter ever stops breaking Korean
        // between syllables, the fix below is no longer needed and this fails.
        expect(_breaksOnlyAtSpaces(_verse, width), isFalse);
      });

      test('joined text breaks only at spaces at ${width.toInt()}dp', () {
        expect(_breaksOnlyAtSpaces(joinKoreanWords(_verse), width), isTrue);
      });
    }
  });

  group('keywordPatternForJoined', () {
    test('finds a keyword inside a joined 어절', () {
      final joined = joinKoreanWords(_verse);
      // A plain search misses it: the joiners sit between the syllables.
      expect(RegExp('사랑').hasMatch(joined), isFalse);
      expect(RegExp(keywordPatternForJoined('사랑')).hasMatch(joined), isTrue);
    });

    test('still matches text that was never joined', () {
      expect(RegExp(keywordPatternForJoined('사랑')).hasMatch(_verse), isTrue);
    });

    test('escapes regex metacharacters in the keyword', () {
      expect(RegExp(keywordPatternForJoined('a.b')).hasMatch('axb'), isFalse);
      expect(RegExp(keywordPatternForJoined('a.b')).hasMatch('a.b'), isTrue);
    });
  });
}
