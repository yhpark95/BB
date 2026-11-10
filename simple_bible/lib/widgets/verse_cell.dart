import 'package:flutter/material.dart';
import '../models/verse.dart';
import '../services/settings_service.dart';
import 'reader_bar.dart';

/// One verse as the reader draws it: number, optional bookmark mark, body.
///
/// Shared by the phone reader and the wide-screen reader, which used to carry
/// a copy each — and had to be fixed twice whenever the look changed.
///
/// [bodySpans] is the verse text already split for highlighting; the caller
/// decides whether a search term is marked, since only one of two side-by-side
/// columns should show it.
///
/// [separated] draws the gap and the rule under the verse. Off for a
/// side-by-side column, where the row draws one rule across both columns: each
/// column is as tall as its own text, so a rule per cell would land at a
/// different height on each side.
Widget buildVerseCell(
  BuildContext context,
  SettingsService settings,
  Verse verse, {
  Key? key,
  required bool highlighted,
  required bool bookmarked,
  required List<InlineSpan> bodySpans,
  required VoidCallback onTap,
  required VoidCallback onLongPress,
  bool separated = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    key: key,
    padding: separated
        ? EdgeInsets.only(bottom: settings.verseGap)
        : EdgeInsets.zero,
    decoration: BoxDecoration(
      color: highlighted ? scheme.primaryContainer.withValues(alpha: 0.4) : null,
      borderRadius: highlighted ? BorderRadius.circular(8) : null,
      border: separated ? verseRuleBorder(context) : null,
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: kReaderTextInset, vertical: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A tap selects; a long-press extends to a range.
        onLongPress: onLongPress,
        onTap: onTap,
        child: RichText(
          // RichText ignores the system font-size setting unless told
          // otherwise. Honour it, capped so the in-app size on top of a large
          // system size cannot push a verse off the screen.
          textScaler:
              MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  // Loose enough to separate lines, not so loose that a page
                  // fits only one verse.
                  height: settings.lineHeight,
                  fontSize: settings.fontSize,
                  fontWeight: settings.textWeight,
                ),
            children: [
              TextSpan(
                text: '${verse.verse} ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                  fontSize: settings.fontSize * 0.75,
                ),
              ),
              // Without this a bookmarked verse looks like any other. It rides
              // in the text so it reflows with it.
              if (bookmarked)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.bookmark,
                      size: settings.fontSize * 0.8,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ...bodySpans,
            ],
          ),
        ),
      ),
    ),
  );
}
