import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/utils/verse_highlight.dart';

String plain(List<InlineSpan> spans) =>
    spans.map((s) => (s as TextSpan).text).join();

void main() {
  test('no keywords gives one plain span', () {
    expect(highlightSpans('In the beginning', null).length, 1);
    expect(highlightSpans('In the beginning', []).length, 1);
  });

  test('matches are bold and the text is unchanged', () {
    final spans = highlightSpans('And he loved her', ['love']);
    expect(plain(spans), 'And he loved her');
    final bold = spans
        .cast<TextSpan>()
        .where((s) => s.style?.fontWeight == FontWeight.bold)
        .map((s) => s.text);
    expect(bold, ['love']);
  });

  test('is case-insensitive and marks every match', () {
    final spans = highlightSpans('God made God', ['god']);
    final bold = spans
        .cast<TextSpan>()
        .where((s) => s.style?.fontWeight == FontWeight.bold)
        .length;
    expect(bold, 2);
  });

  test('several keywords are all marked', () {
    final spans = highlightSpans('love the LORD thy God', ['love', 'god']);
    final bold = spans
        .cast<TextSpan>()
        .where((s) => s.style?.fontWeight == FontWeight.bold)
        .map((s) => s.text);
    expect(bold, ['love', 'God']);
  });
}
