/// Korean line breaking.
///
/// Flutter follows the Unicode default, which allows a line to end between any
/// two Hangul syllables — so `하나님이 세상을 이처럼 사랑하사` can wrap as
/// `…이처럼 사랑` / `하사`, splitting a word in half. Korean is meant to wrap at
/// 어절 boundaries, i.e. at spaces.
///
/// Joining the syllables inside each 어절 with U+2060 WORD JOINER removes those
/// interior break opportunities and leaves the spaces as the only ones. A word
/// still longer than the line force-breaks as before, so nothing overflows —
/// which matters in the narrow half-width columns of the dual-language view.
library;

const String wordJoiner = '\u2060';

bool _isHangul(int rune) =>
    (rune >= 0xAC00 && rune <= 0xD7A3) || // 가-힣
    (rune >= 0x1100 && rune <= 0x11FF) || // Jamo
    (rune >= 0x3130 && rune <= 0x318F); // compatibility Jamo

bool containsHangul(String text) => text.runes.any(_isHangul);

/// Returns [text] with each Hangul 어절 made unbreakable.
///
/// Latin text is returned untouched: it already breaks only at spaces, and the
/// joiners would just make the string longer.
String joinKoreanWords(String text) {
  if (!containsHangul(text)) return text;
  return text
      .split(' ')
      .map((chunk) => containsHangul(chunk)
          ? chunk.runes.map(String.fromCharCode).join(wordJoiner)
          : chunk)
      .join(' ');
}

/// A pattern matching [keyword] inside text that has been through
/// [joinKoreanWords] — the joiners sit between the characters, so each gap has
/// to be allowed for.
String keywordPatternForJoined(String keyword) => keyword.runes
    .map((r) => RegExp.escape(String.fromCharCode(r)))
    .join('$wordJoiner?');
