import '../models/verse.dart';

/// One row of the dual-language reader: a verse number and whichever
/// translations have that verse.
class VersePair {
  final int verse;
  final Verse? primary;
  final Verse? secondary;

  const VersePair(this.verse, this.primary, this.secondary);
}

/// Pairs the two translations of a chapter by verse number.
///
/// They do not always have the same number of verses. Measured against the
/// shipped text, Korean and French disagree in 104 chapters and Korean and KJV
/// in 5 — Exodus 7 is 25 verses in Korean and 29 in French. Walking the two
/// lists by index therefore put a different verse on each side, from the first
/// row of those chapters onward, in the one view whose entire purpose is that
/// the two sides line up.
///
/// A verse missing from one translation leaves that half of its row empty
/// instead of shifting everything below it.
List<VersePair> pairVersesByNumber(
  List<Verse> primary,
  List<Verse> secondary,
) {
  final byNumberPrimary = {for (final v in primary) v.verse: v};
  final byNumberSecondary = {for (final v in secondary) v.verse: v};
  final numbers = <int>{...byNumberPrimary.keys, ...byNumberSecondary.keys}
      .toList()
    ..sort();
  return [
    for (final n in numbers)
      VersePair(n, byNumberPrimary[n], byNumberSecondary[n]),
  ];
}
