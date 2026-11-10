import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../services/nav_history.dart';
import '../services/settings_service.dart';
import '../utils/korean_wrap.dart';
import '../screens/settings_screen.dart';

/// Shared chrome for the reader.
///
/// Design rules for this bar, in priority order:
///  1. Every tappable thing is at least 48dp tall and carries a Korean word —
///     icons alone are not readable to everyone.
///  2. The two things people change most (book, chapter) are the biggest
///     buttons on screen.
///  3. Everything else lives behind one "더보기" sheet instead of a row of
///     unlabeled icons.

const double _kMinTap = 48.0;

/// Space between the edge of a text column and the verse text, used on every
/// side of every column in both readers — outer edges and the gutter between
/// two columns alike. Kept on the verse padding itself so the selection
/// highlight extends across it.
const double kReaderTextInset = 4.0;

/// A chrome label that shrinks to fit rather than truncating.
///
/// Ellipsis is the wrong failure for this app: "마가복음" cut to "마가…" or
/// "16장" cut to "1…" tells a reader nothing, and it slips past an overflow
/// test because an ellipsised line does not overflow. FittedBox scales the
/// label down instead, so the whole word is always readable — smaller, but
/// there. Only for fixed chrome (buttons, bars); verse text is never squeezed.
Widget shrinkLabel(
  String text, {
  TextStyle? style,
  TextAlign? textAlign,
  Alignment alignment = Alignment.center,
  TextScaler? textScaler,
  int maxLines = 1,
  double? maxWidth,
}) {
  // Folding onto a second line is a last resort, and only for text that has
  // somewhere to fold. A Korean book name has no spaces, so a break lands
  // inside the word — "마가복음" becomes "마가 / 복음" — which is worse than
  // the same name rendered slightly smaller. So: use one line while it fits,
  // fold only text with a space in it, and shrink whatever is left over.
  final canFold = maxLines > 1 && text.contains(' ');

  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: textScaler ?? MediaQuery.textScalerOf(context),
        )..layout();
        final natural = painter.width;
        painter.dispose();

        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (maxWidth ?? double.infinity);

        // One line unless it genuinely does not fit.
        final fold = canFold && natural > available;
        final wrapWidth = fold
            // Never narrower than the space on offer: folding at
            // natural/maxLines alone would squeeze a name that had room.
            ? (natural / maxLines * 1.15).clamp(available, natural)
            : (maxWidth ?? double.infinity);

        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wrapWidth),
            child: Text(
              text,
              maxLines: fold ? maxLines : 1,
              softWrap: fold,
              textAlign: textAlign,
              textScaler: textScaler,
              style: style,
            ),
          ),
        );
      },
    );
  }

  return Builder(builder: build);
}



/// Big labeled button used in the reader AppBar actions.
///
/// The label is capped in width and never wraps: at a large system font scale
/// two of these sit beside the book and chapter pills on a 320dp screen, and a
/// growing label would push the whole bar past the edge.
Widget readerLabeledAction(
  BuildContext context, {
  required IconData icon,
  required String label,
  VoidCallback? onTap,
  bool highlighted = false,
}) {
  final color = highlighted
      ? Theme.of(context).colorScheme.primary
      : Theme.of(context).colorScheme.onSurfaceVariant;
  return Semantics(
    button: true,
    label: label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(
          minWidth: _kMinTap,
          maxWidth: 72,
          minHeight: _kMinTap,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            // The label is a hint beside a clear icon, so it is held at a
            // fixed size rather than scaled — the reading text is where the
            // system font scale needs to land.
            shrinkLabel(
              label,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: 11,
                height: 1.0,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Large pill button for the book / chapter selectors.
Widget readerPillButton(
  BuildContext context, {
  required String label,
  VoidCallback? onTap,
  bool primary = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Semantics(
    button: true,
    child: Material(
      color: primary ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(minHeight: _kMinTap),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: shrinkLabel(
                  label,
                  // Book names run to "Premier livre des Chroniques"; a second
                  // line keeps it full size where one line would shrink it to
                  // 40 per cent.
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primary
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down,
                  size: 22,
                  color: primary ? scheme.onPrimaryContainer : scheme.onSurface),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Header sitting above one column of the dual-language reader.
///
/// Two columns of scripture side by side carry nothing that says which
/// translation is which — obvious with Korean beside English, not obvious at
/// all once two translations share a script. It also puts the second book name
/// back on screen, which the title bar gave up in order to fit.
/// Font size for the column headers, derived from the reading size.
///
/// It has to move with the reading size — a header fixed at 13sp beside 40pt
/// verses is a header the reader cannot see — but it is a label, not text to
/// be read, so it stays well under the verses and is capped: this bar sits
/// outside the scroll view, and every pixel it takes the chapter never gets.
double _headerFontSize(SettingsService settings) =>
    (settings.fontSize * 0.6).clamp(14.0, 17.0);

/// One column header. [lines] is decided for both columns together by
/// [columnHeaderRow] so the two are the same height.
Widget columnHeader(BuildContext context, String label, {int lines = 1}) {
  final scheme = Theme.of(context).colorScheme;
  final settings = Provider.of<SettingsService>(context);
  final fontSize = _headerFontSize(settings);

  return Container(
    height: fontSize * 1.3 * lines + 16,
    padding: const EdgeInsets.fromLTRB(kReaderTextInset, 8, kReaderTextInset, 8),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      border: Border(
        bottom: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    alignment: Alignment.centerLeft,
    child: shrinkLabel(
      label,
      alignment: Alignment.centerLeft,
      maxLines: lines,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
  );
}

/// Both column headers, at one shared height.
///
/// Sized separately they end up ragged: "Cantique des Cantiques 2" folds onto
/// a second line while "아가 2장" does not, and the two coloured blocks then
/// step up and down against each other. The usual answer, IntrinsicHeight,
/// cannot be used — shrinkLabel measures with a LayoutBuilder, which has no
/// intrinsic dimensions to give — so the line count is worked out here, once,
/// and handed to both.
Widget columnHeaderRow(BuildContext context,
    {required String left, required String right}) {
  final settings = Provider.of<SettingsService>(context);
  final style = TextStyle(
      fontSize: _headerFontSize(settings),
      height: 1.3,
      fontWeight: FontWeight.w700);

  return LayoutBuilder(
    builder: (context, constraints) {
      final columnWidth =
          (constraints.maxWidth / 2) - (kReaderTextInset * 2);

      int linesFor(String text) {
        if (columnWidth <= 0) return 1;
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2,
        )..layout(maxWidth: columnWidth);
        final needsTwo = painter.height > painter.preferredLineHeight * 1.5;
        painter.dispose();
        return needsTwo ? 2 : 1;
      }

      final lines = [linesFor(left), linesFor(right)]
          .reduce((a, b) => a > b ? a : b);

      return Row(
        children: [
          Expanded(child: columnHeader(context, left, lines: lines)),
          Expanded(child: columnHeader(context, right, lines: lines)),
        ],
      );
    },
  );
}

/// "마가복음 16장" for Korean, "Mark 16" otherwise.
String chapterTitleFor(Book? book, int chapter, int translationId) {
  final name = book?.nameFor(translationId) ?? '';
  return translationId == 2 ? '$name $chapter장' : '$name $chapter';
}

/// The rule between one verse and the next.
///
/// Drawn on the bottom edge, below the verse gap, so it sits between two
/// verses rather than hugging the text above it. A full pixel and nearly
/// opaque: at 0.5dp and 40% it was sub-pixel, anti-aliased away, and simply
/// not there on a phone.
Border verseRuleBorder(BuildContext context) => Border(
      bottom: BorderSide(
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.9),
      ),
    );

/// Reader AppBar: which book, plus 검색 / 더보기.
///
/// The chapter used to sit up here in a second pill, duplicating the one in
/// the bottom bar and leaving the book roughly 110dp of text. Measured on a
/// 412dp phone that truncated "16장" to "1…" at nothing worse than a 1.1 font
/// scale, and every book name longer than 마가복음 at any scale. Splitting the
/// roles — this bar says which book, the bottom bar says which chapter —
/// hands the whole width to the name.
PreferredSizeWidget readerAppBar(
  BuildContext context, {
  required String bookLabel,
  VoidCallback? onBookTap,
  VoidCallback? onSearchTap,
  VoidCallback? onMoreTap,
  bool searchActive = false,
}) {
  // A fixed 64dp toolbar clips the pill once the system font scale climbs,
  // so the bar grows with it (bounded, so it never eats the page).
  final toolbarHeight =
      MediaQuery.textScalerOf(context).scale(64).clamp(64.0, 104.0);

  return AppBar(
    toolbarHeight: toolbarHeight,
    titleSpacing: 8,
    automaticallyImplyLeading: false,
    title: readerPillButton(context,
        label: bookLabel, onTap: onBookTap, primary: true),
    actions: [
      readerLabeledAction(
        context,
        icon: searchActive ? Icons.manage_search : Icons.search,
        label: searchActive ? '검색결과' : '검색',
        highlighted: searchActive,
        onTap: onSearchTap,
      ),
      readerLabeledAction(
        context,
        icon: Icons.menu,
        label: '더보기',
        onTap: onMoreTap,
      ),
      const SizedBox(width: 4),
    ],
  );
}

/// Bottom navigation: previous chapter / chapter list / next chapter.
/// Deliberately three wide targets rather than small arrows.
Widget readerBottomBar(
  BuildContext context, {
  required int chapter,
  required int chapterCount,
  VoidCallback? onPrev,
  VoidCallback? onNext,
  VoidCallback? onChapterTap,
}) {
  final scheme = Theme.of(context).colorScheme;

  // Rows here use minHeight rather than a fixed height: at a large system font
  // scale a 56dp box cannot hold its own label, and clipping the only
  // navigation in the app is the worst possible failure.
  Widget sideButton({
    required IconData icon,
    required String label,
    required bool leading,
    VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    final color =
        enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.3);
    final iconWidget = Icon(icon, size: 22, color: color);
    final textWidget = shrinkLabel(
      label,
      style:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
    );
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: leading
                ? [
                    iconWidget,
                    const SizedBox(width: 4),
                    Flexible(child: textWidget),
                  ]
                : [
                    Flexible(child: textWidget),
                    const SizedBox(width: 4),
                    iconWidget,
                  ],
          ),
        ),
      ),
    );
  }

  return Material(
    color: scheme.surfaceContainerHighest,
    elevation: 3,
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          sideButton(
            icon: Icons.chevron_left,
            label: '이전 장',
            leading: true,
            onPressed: onPrev,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 130),
            child: InkWell(
              onTap: onChapterTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                alignment: Alignment.center,
                // "2 / 5" rather than a big "2장" over a tiny "전체 5장".
                // The old second line was 11sp — unreadable in an app people
                // use because 11sp is unreadable to them — and it repeated the
                // number above it. One line says both, at a size that can be
                // read, and needs no hiding at large font scales.
                child: shrinkLabel(
                  '$chapter/$chapterCount',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                ),
              ),
            ),
          ),
          sideButton(
            icon: Icons.chevron_right,
            label: '다음 장',
            leading: false,
            onPressed: onNext,
          ),
        ],
      ),
    ),
  );
}

/// The way back forward, offered just after a back.
///
/// Not a snack bar. A snack bar floats over the verses, reappears on every
/// press of back, and dies on a timer while the way forward is still there —
/// the offer outlived its message or the message outlived the offer, and
/// either way it covered the text someone was reading. This is a row: it
/// pushes the page up instead of sitting on it, it says where it leads, and
/// it leaves when the reader turns the page rather than when a clock runs out.
///
/// [Icons.redo] rather than an arrow. The bar directly beneath this one is
/// `‹ 이전 장 / 다음 장 ›`, and a third left/right arrow meaning something
/// else entirely is how two controls become one confusing one.
Widget forwardBar(
  BuildContext context, {
  required String label,
  required VoidCallback onTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  return Material(
    // Not the bottom bar's colour: this row is temporary and has to read as a
    // different thing from the navigation it sits on.
    color: scheme.secondaryContainer,
    child: InkWell(
      onTap: onTap,
      child: Container(
        // Grows with the system font scale like every other bar here, and is
        // never shorter than a comfortable target.
        constraints: const BoxConstraints(minHeight: _kMinTap),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.redo, size: 22, color: scheme.onSecondaryContainer),
            const SizedBox(width: 10),
            Flexible(
              child: shrinkLabel(
                '앞으로 · $label',
                alignment: Alignment.centerLeft,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Bar shown while verses are selected. Labeled buttons, not bare icons —
/// this surface appears rarely, so nothing here can rely on recognition.
Widget verseActionBar(
  BuildContext context, {
  required int selectedCount,
  required VoidCallback onBookmark,
  required VoidCallback onCopy,
  required VoidCallback onClear,
  /// Every selected verse is already bookmarked, so the button removes rather
  /// than adds — pressing bookmark twice used to do nothing visible.
  bool allBookmarked = false,
}) {
  final scheme = Theme.of(context).colorScheme;

  // Same rule as the bottom bar: grow, never clip. Kept close to the 56dp
  // navigation bar this replaces — a taller bar shoves the verses up the
  // moment one is selected, which is exactly when the reader is looking at
  // them.
  Widget action(IconData icon, String label, VoidCallback onPressed) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: scheme.onPrimaryContainer),
              shrinkLabel(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: scheme.onPrimaryContainer)),
            ],
          ),
        ),
      ),
    );
  }

  return Material(
    color: scheme.primaryContainer,
    elevation: 3,
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 0),
            child: shrinkLabel(
                // Short enough to stay full size in a one-line bar on a
                // 320dp phone. The long-press gesture is taught by the coach
                // mark, not squeezed in here.
                '구절 $selectedCount개를 골랐어요',
                style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer)),
          ),
          Row(
            children: [
              action(
                  allBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                  allBookmarked ? '북마크 해제' : '북마크',
                  onBookmark),
              action(Icons.copy, '복사', onCopy),
              action(Icons.close, '선택 해제', onClear),
            ],
          ),
        ],
      ),
    ),
  );
}


/// One tall row in the 더보기 sheet.
Widget _sheetRow(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? subtitle,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    minVerticalPadding: 12,
    leading: Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
    title: Text(title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600)),
    subtitle: subtitle == null ? null : Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

const Map<int, String> _translationNames = {
  2: '개역한글 (한국어)',
  1: 'KJV (English)',
  3: 'Louis Segond (Français)',
};

/// Same translations, named by language and short enough to sit inside a chip
/// on a narrow phone. Kept beside the long names so the two cannot drift apart.
const Map<int, String> kTranslationShortNames = {
  2: '한국어',
  1: '영어',
  3: '프랑스어',
};

/// Two-row search bar.
///
/// Row 1 is the input alone, so the field gets the full width instead of the
/// ~130dp left over after the language, book-range and search controls were
/// crammed in beside it. Row 2 carries those controls, which keeps the current
/// search scope permanently visible — a book filter left switched on is the
/// usual reason a search "finds nothing".
PreferredSizeWidget searchAppBar(
  BuildContext context, {
  required TextEditingController controller,
  required String translationLabel,
  required String bookLabel,
  required bool bookSelected,
  required VoidCallback onTranslationTap,
  required VoidCallback? onBookTap,
  required VoidCallback onSubmit,
  required VoidCallback onClear,
  required ValueChanged<String> onChanged,
  bool autofocus = true,
  String hintText = '찾을 낱말을 넣으세요',
}) {
  final scheme = Theme.of(context).colorScheme;
  final scaler = MediaQuery.textScalerOf(context);

  // The input row grows with the system font scale; a fixed height here would
  // clip the field exactly when a reader needs it biggest.
  final toolbarHeight = scaler.scale(64).clamp(64.0, 96.0);

  // The filter row is chrome, not reading text: three controls share one line,
  // and at 2x on a 320dp phone a fully scaled label is left ~70dp for a word
  // that needs 120, so it ellipsises to "프랑…". This row alone therefore caps
  // the scale at 1.3 — every label stays whole — while the verses themselves
  // still scale all the way up.
  final rowScale = scaler.scale(1.0).clamp(1.0, 1.3);
  final filterHeight = (56 * rowScale).clamp(56.0, 76.0);

  // Below the cap there is room for a leading icon; above it the label wins.
  final showChipIcons = rowScale <= 1.15;

  Widget chip({
    required IconData icon,
    required String label,
    required bool highlighted,
    required VoidCallback? onPressed,
  }) {
    final color = highlighted ? scheme.primary : scheme.onSurfaceVariant;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 44),
        side: BorderSide(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
          width: highlighted ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showChipIcons) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: shrinkLabel(
              label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  return PreferredSize(
    preferredSize: Size.fromHeight(toolbarHeight + filterHeight),
    child: AppBar(
      toolbarHeight: toolbarHeight,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: TextField(
          controller: controller,
          autofocus: autofocus,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: scheme.surface,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: '지우기',
                    onPressed: onClear,
                  ),
          ),
          onChanged: onChanged,
          onSubmitted: (_) => onSubmit(),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(filterHeight),
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(rowScale)),
          child: Container(
            height: filterHeight,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            alignment: Alignment.center,
            child: Row(
              children: [
                Flexible(
                  child: chip(
                    icon: Icons.translate,
                    label: translationLabel,
                    highlighted: false,
                    onPressed: onTranslationTap,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: chip(
                    icon: Icons.menu_book_outlined,
                    label: bookLabel,
                    highlighted: bookSelected,
                    onPressed: onBookTap,
                  ),
                ),
                const SizedBox(width: 8),
                // Bottom-right, under the thumb, and the only filled button on
                // the screen — the one control a reader must always find.
                FilledButton(
                  onPressed: onSubmit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    minimumSize: const Size(0, 44),
                  ),
                  child: shrinkLabel(
                    '찾기',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// The single overflow surface for the reader: text size, language,
/// bookmarks, settings. Replaces a row of unlabeled AppBar icons.
void showReaderMoreSheet(
  BuildContext context, {
  required VoidCallback onBookmarksTap,
  List<NavPoint> recent = const [],
  String Function(NavPoint point)? recentLabel,
  void Function(NavPoint point)? onRecentTap,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('글자 크기',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: FontSizeStepper(),
            ),
            const Divider(height: 24),
            // Hidden until there is something in it: an empty row that says
            // "최근 본 곳" and does nothing is worse than no row.
            if (recent.isNotEmpty && recentLabel != null && onRecentTap != null)
              _sheetRow(
                sheetContext,
                icon: Icons.history,
                title: '최근 본 곳',
                subtitle: recentLabel(recent.first),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showRecentSheet(context,
                      recent: recent,
                      label: recentLabel,
                      onTap: onRecentTap);
                },
              ),
            _sheetRow(
              sheetContext,
              icon: Icons.translate,
              title: '번역본',
              subtitle: _currentTranslationSummary(sheetContext),
              onTap: () {
                Navigator.pop(sheetContext);
                showTranslationSheet(context);
              },
            ),
            _sheetRow(
              sheetContext,
              icon: Icons.bookmark,
              title: '북마크',
              subtitle: '저장해 둔 구절 보기',
              onTap: () {
                Navigator.pop(sheetContext);
                onBookmarksTap();
              },
            ),
            _sheetRow(
              sheetContext,
              icon: Icons.settings,
              title: '설정',
              subtitle: '화면 밝기 · 글자 · 간격',
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

String _currentTranslationSummary(BuildContext context) {
  final settings = Provider.of<SettingsService>(context, listen: false);
  return settings.selectedTranslationIds
      .map((id) => _translationNames[id] ?? '$id')
      .join(' + ');
}

/// Big − A + stepper. Easier to hit than a slider.
class FontSizeStepper extends StatelessWidget {
  const FontSizeStepper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        final canShrink = settings.fontSize > SettingsService.minFontSize;
        final canGrow = settings.fontSize < SettingsService.maxFontSize;
        Widget stepButton(IconData icon, String label, bool enabled,
            VoidCallback onPressed) {
          return Expanded(
            child: OutlinedButton(
              onPressed: enabled ? onPressed : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(width: 6),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Row(
              children: [
                stepButton(Icons.remove, '작게', canShrink,
                    () => settings.stepFontSize(-2)),
                const SizedBox(width: 12),
                stepButton(Icons.add, '크게', canGrow,
                    () => settings.stepFontSize(2)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '하나님이 세상을 이처럼 사랑하사',
                style: TextStyle(
                  fontSize: settings.fontSize,
                  fontWeight: settings.textWeight,
                  height: 1.6,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Language chooser. One tap = read that translation; the second row lets
/// people add a side-by-side translation without understanding "dual mode".
/// Line spacing and verse spacing, with a preview showing both at once.
///
/// They are tuned together or not at all: loose leading with a big gap wastes
/// a screen, and tight leading with no gap runs the verses together. A preview
/// of one verse cannot show either problem, so this one shows three.
class SpacingSteppers extends StatelessWidget {
  const SpacingSteppers({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        Widget stepper({
          required String title,
          required String value,
          required bool canShrink,
          required bool canGrow,
          required VoidCallback onShrink,
          required VoidCallback onGrow,
        }) {
          Widget button(IconData icon, String label, bool enabled,
              VoidCallback onPressed) {
            return Expanded(
              child: OutlinedButton(
                onPressed: enabled ? onPressed : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22),
                    const SizedBox(width: 4),
                    Flexible(
                      child: shrinkLabel(label,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: shrinkLabel(title,
                        alignment: Alignment.centerLeft,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Text(value,
                      style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  button(Icons.remove, '좁게', canShrink, onShrink),
                  const SizedBox(width: 10),
                  button(Icons.add, '넓게', canGrow, onGrow),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            stepper(
              title: '줄 간격',
              value: settings.lineHeight.toStringAsFixed(1),
              canShrink: settings.lineHeight > SettingsService.minLineHeight,
              canGrow: settings.lineHeight < SettingsService.maxLineHeight,
              onShrink: () => settings.stepLineHeight(-0.1),
              onGrow: () => settings.stepLineHeight(0.1),
            ),
            const SizedBox(height: 16),
            stepper(
              title: '구절 사이',
              value: '${settings.verseGap.round()}',
              canShrink: settings.verseGap > SettingsService.minVerseGap,
              canGrow: settings.verseGap < SettingsService.maxVerseGap,
              onShrink: () => settings.stepVerseGap(-2),
              onGrow: () => settings.stepVerseGap(2),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in const [
                    ('16', '하나님이 세상을 이처럼 사랑하사 독생자를 주셨으니'),
                    ('17', '하나님이 그 아들을 세상에 보내신 것은'),
                    ('18', '그를 믿는 자는 심판을 받지 아니하는 것이요'),
                  ])
                    Padding(
                      padding: EdgeInsets.only(bottom: settings.verseGap),
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontSize: settings.fontSize,
                                fontWeight: settings.textWeight,
                                height: settings.lineHeight,
                              ),
                          children: [
                            TextSpan(
                              text: '${line.$1} ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: settings.fontSize * 0.75,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            TextSpan(text: joinKoreanWords(line.$2)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The places jumped to lately, newest first.
///
/// Deliberate jumps only, which is the same rule the back button follows —
/// otherwise every chapter turned would be listed and the list would say
/// nothing about where the reader has actually been.
void showRecentSheet(
  BuildContext context, {
  required List<NavPoint> recent,
  required String Function(NavPoint point) label,
  required void Function(NavPoint point) onTap,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('최근 본 곳',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          for (final point in recent)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: const Icon(Icons.menu_book_outlined, size: 26),
              title: Text(label(point),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                onTap(point);
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

void showTranslationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Consumer<SettingsService>(
        builder: (context, settings, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('번역본',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            for (final entry in _translationNames.entries)
              CheckboxListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                value: settings.selectedTranslationIds.contains(entry.key),
                onChanged: (_) => settings.toggleTranslation(entry.key),
                title: Text(entry.value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                '두 개까지 고르면 나란히 보여 줘요',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
