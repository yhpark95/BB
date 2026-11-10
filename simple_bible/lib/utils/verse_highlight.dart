import 'package:flutter/painting.dart';
import 'korean_wrap.dart';

/// Splits [text] into spans with every match of [keywords] in bold.
///
/// [text] must already have been through [joinKoreanWords]; the pattern
/// tolerates the joiner between each pair of characters. Without keywords the
/// whole text comes back as one plain span.
List<InlineSpan> highlightSpans(String text, List<String>? keywords) {
  if (keywords == null || keywords.isEmpty) return [TextSpan(text: text)];
  final pattern = RegExp(
    keywords.map(keywordPatternForJoined).join('|'),
    caseSensitive: false,
  );
  final spans = <InlineSpan>[];
  var lastEnd = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    spans.add(TextSpan(
      text: text.substring(match.start, match.end),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }
  return spans;
}
