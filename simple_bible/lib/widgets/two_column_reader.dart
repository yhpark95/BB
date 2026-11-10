import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../utils/verse_pairing.dart';
import 'verse_selection.dart';
import '../utils/korean_wrap.dart';
import '../models/book.dart';
import '../models/verse.dart';
import 'reader_gesture_layer.dart';
import 'chapter_picker.dart';
import 'reader_bar.dart';

/// Minimum width before a single chapter is split across two text columns.
/// Chosen so each column keeps a comfortable line length.
const double kTwoColumnMinWidth = 840;

class _ChapterRef {
  final String bookNum;
  final int chapter;
  final Book book;
  final int chapterCount;

  const _ChapterRef({
    required this.bookNum,
    required this.chapter,
    required this.book,
    required this.chapterCount,
  });
}

class TwoColumnReader extends StatefulWidget {
  final String bookNum;
  final int chapter;

  /// Bumped by the parent on a deliberate jump. See [ReaderPane.navSeq].
  final int navSeq;

  final int? highlightVerse;
  final List<String>? searchKeywords;

  /// See [ReaderPane.forwardLabel].
  final String? forwardLabel;
  final VoidCallback? onForward;

  final void Function(Book? book, int chapter, int chapterCount)?
      onStateChanged;

  const TwoColumnReader({
    super.key,
    required this.bookNum,
    required this.chapter,
    this.navSeq = 0,
    this.highlightVerse,
    this.searchKeywords,
    this.forwardLabel,
    this.onForward,
    this.onStateChanged,
  });

  @override
  State<TwoColumnReader> createState() => TwoColumnReaderState();
}

class TwoColumnReaderState extends State<TwoColumnReader>
    with VerseSelectionMixin {
  List<_ChapterRef> _index = [];
  bool _indexLoading = true;
  String? _indexError;
  PageController? _pageController;
  int _currentPage = 0;
  double _dragStartOffset = 0;

  /// Verses of the page currently on screen, reported by _ChapterPage.
  List<Verse> _pageVerses = [];
  List<Verse> _pageSecondary = [];

  @override
  List<Verse> get selectionPrimary => _pageVerses;
  @override
  List<Verse> get selectionSecondary => _pageSecondary;
  @override
  Book? get selectionBook => _index.isEmpty ? null : _index[_currentPage].book;
  @override
  int get selectionChapter => _index.isEmpty ? 1 : _index[_currentPage].chapter;

  @override
  void initState() {
    super.initState();
    _buildIndex();
  }

  @override
  void didUpdateWidget(TwoColumnReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navSeq != widget.navSeq) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToRef(widget.bookNum, widget.chapter);
      });
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _buildIndex() async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final books = await dbService.getAllBooks();
      final counts = await Future.wait(
        books.map((b) => dbService.getChapterCount(b.bookNum)),
      );

      final List<_ChapterRef> index = [];
      for (int bi = 0; bi < books.length; bi++) {
        final book = books[bi];
        final count = counts[bi];
        for (int ch = 1; ch <= count; ch++) {
          index.add(_ChapterRef(
            bookNum: book.bookNum,
            chapter: ch,
            book: book,
            chapterCount: count,
          ));
        }
      }

      if (!mounted) return;

      final initialPage = index.indexWhere(
        (r) => r.bookNum == widget.bookNum && r.chapter == widget.chapter,
      );
      final startPage = initialPage >= 0 ? initialPage : 0;

      setState(() {
        _index = index;
        _pageController = PageController(initialPage: startPage);
        _currentPage = startPage;
        _indexLoading = false;
      });

      if (index.isNotEmpty) {
        final ref = index[startPage];
        widget.onStateChanged?.call(ref.book, ref.chapter, ref.chapterCount);
      }
    } catch (e, stack) {
      debugPrint('[TCR] _buildIndex error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _indexError = e.toString();
        _indexLoading = false;
      });
    }
  }

  void _jumpToRef(String bookNum, int chapter) {
    if (_index.isEmpty || _pageController == null) return;
    final targetPage = _index.indexWhere(
      (r) => r.bookNum == bookNum && r.chapter == chapter,
    );
    if (targetPage < 0) return;
    final distance = (targetPage - _currentPage).abs();
    if (distance <= 10) {
      _pageController!.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController!.jumpToPage(targetPage);
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      _pageVerses = [];
      _pageSecondary = [];
      resetSelectionState();
    });
    if (_index.isEmpty) return;
    final ref = _index[page];
    final settings = Provider.of<SettingsService>(context, listen: false);
    settings.saveLastPosition(bookNum: ref.bookNum, chapter: ref.chapter);
    widget.onStateChanged?.call(ref.book, ref.chapter, ref.chapterCount);
  }

  void showChapterPicker() {
    if (_index.isEmpty) return;
    final ref = _index[_currentPage];
    final settings = Provider.of<SettingsService>(context, listen: false);
    showPickerDialog(
      context,
      ChapterPicker(
        bookLabel: ref.book.nameFor(settings.primaryTranslationId),
        chapterCount: ref.chapterCount,
        currentChapter: ref.chapter,
        onSelected: (chapter) {
          Navigator.pop(context);
          if (chapter != ref.chapter) {
            _jumpToRef(ref.bookNum, chapter);
          }
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    if (_index.isEmpty) return const SizedBox.shrink();
    final ref = _index[_currentPage];

    return readerBottomBar(
      context,
      chapter: ref.chapter,
      chapterCount: ref.chapterCount,
      onPrev: _currentPage > 0
          ? () => _pageController!.animateToPage(
                _currentPage - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              )
          : null,
      onNext: _currentPage < _index.length - 1
          ? () => _pageController!.animateToPage(
                _currentPage + 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              )
          : null,
      onChapterTap: showChapterPicker,
    );
  }

  Widget _buildVerseActionBar() {
    return verseActionBar(
      context,
      selectedCount: selectedVerses.length,
      allBookmarked: allSelectedBookmarked,
      onBookmark: () => toggleBookmarkSelected(
          Provider.of<DatabaseService>(context, listen: false)),
      onCopy: () =>
          copySelected(Provider.of<SettingsService>(context, listen: false)),
      onClear: clearSelection,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_indexLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('성경을 불러오고 있어요...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    if (_indexError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('오류: $_indexError'),
            ],
          ),
        ),
      );
    }

    if (_index.isEmpty) {
      return const Center(
        child: Text('성경 데이터를 찾을 수 없어요', style: TextStyle(fontSize: 17)),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Consumer<SettingsService>(
            builder: (context, settings, _) => ReaderGestureLayer(
              onDragStart: () {
                _dragStartOffset = _pageController?.hasClients == true
                    ? _pageController!.offset
                    : 0;
              },
              onDragUpdate: (dx) {
                if (_pageController?.hasClients != true) return;
                _pageController!.jumpTo(
                  (_dragStartOffset - dx).clamp(
                    _pageController!.position.minScrollExtent,
                    _pageController!.position.maxScrollExtent,
                  ),
                );
              },
              onSwipeLeft: () {
                if (_pageController?.hasClients != true) return;
                final page = _pageController!.page ?? _currentPage.toDouble();
                _pageController!.animateToPage(
                  (page.floor() + 1).clamp(0, _index.length - 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              onSwipeRight: () {
                if (_pageController?.hasClients != true) return;
                final page = _pageController!.page ?? _currentPage.toDouble();
                _pageController!.animateToPage(
                  (page.ceil() - 1).clamp(0, _index.length - 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              onDragCancel: () {
                if (_pageController?.hasClients != true) return;
                final page = _pageController!.page ?? _currentPage.toDouble();
                _pageController!.animateToPage(
                  page.round().clamp(0, _index.length - 1),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              },
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: _onPageChanged,
                itemCount: _index.length,
                itemBuilder: (context, index) {
                  final ref = _index[index];
                  final isInitial = ref.bookNum == widget.bookNum &&
                      ref.chapter == widget.chapter;
                  return _ChapterPage(
                    key: ValueKey(
                        '${ref.bookNum}-${ref.chapter}-${settings.selectedTranslationIds.join(",")}'),
                    ref: ref,
                    // A PageView keeps its neighbours alive, and the
                    // selection belongs to the chapter on screen.
                    selectedNums:
                        index == _currentPage ? selectedVerses : const {},
                    bookmarkedUids:
                        index == _currentPage ? bookmarkedUids : const {},
                    onVerseLongPress: longPressVerse,
                    onVerseTap: tapVerse,
                    onVersesLoaded: (primary, secondary) {
                      if (index != _currentPage) return;
                      _pageVerses = primary;
                      _pageSecondary = secondary;
                      refreshBookmarks(
                          Provider.of<DatabaseService>(context, listen: false));
                    },
                    highlightVerse: isInitial ? widget.highlightVerse : null,
                    searchKeywords: isInitial ? widget.searchKeywords : null,
                  );
                },
              ),
            ),
          ),
        ),
        // See ReaderPane: above the navigation, gone while a selection is up.
        if (widget.forwardLabel != null && selectedVerses.isEmpty)
          forwardBar(
            context,
            label: widget.forwardLabel!,
            onTap: widget.onForward ?? () {},
          ),
        selectedVerses.isNotEmpty ? _buildVerseActionBar() : _buildBottomBar(),
      ],
    );
  }
}

// ── Private chapter page ──────────────────────────────────────────────────────

class _ChapterPage extends StatefulWidget {
  final _ChapterRef ref;
  final Set<int> selectedNums;

  /// verse_uid of the bookmarked verses, so they can be marked in the text.
  final Set<int> bookmarkedUids;

  /// A long-press starts or extends the selection; a plain tap only toggles
  /// once a selection is under way.
  final void Function(int verseNum) onVerseLongPress;
  final void Function(int verseNum) onVerseTap;

  /// Hands the loaded chapter to the parent, which owns the selection and so
  /// needs the verses to bookmark and copy them.
  final void Function(List<Verse> primary, List<Verse> secondary)
      onVersesLoaded;
  final int? highlightVerse;
  final List<String>? searchKeywords;

  const _ChapterPage({
    super.key,
    required this.ref,
    required this.selectedNums,
    required this.bookmarkedUids,
    required this.onVerseLongPress,
    required this.onVerseTap,
    required this.onVersesLoaded,
    this.highlightVerse,
    this.searchKeywords,
  });

  @override
  State<_ChapterPage> createState() => _ChapterPageState();
}

class _ChapterPageState extends State<_ChapterPage> {
  /// The verse the reader was sent to, while the cue is still wanted.
  ///
  /// It is drawn with the same background a selected verse gets, so leaving it
  /// on turns "here is the verse you asked for" into "this verse is selected".
  /// Arriving from a bookmark and then un-bookmarking left exactly that: a
  /// verse that looked selected with no way to deselect it. The cue retires as
  /// soon as the reader touches a verse, or shortly by itself.
  int? _arrivedAt;
  Timer? _arrivalTimer;

  void _startArrival(int? verse) {
    _arrivalTimer?.cancel();
    _arrivedAt = verse;
    if (verse == null) return;
    _arrivalTimer = Timer(const Duration(seconds: 6), _clearArrival);
  }

  void _clearArrival() {
    _arrivalTimer?.cancel();
    _arrivalTimer = null;
    if (_arrivedAt == null || !mounted) return;
    setState(() => _arrivedAt = null);
  }

  List<Verse> _primaryVerses = [];
  List<Verse> _secondaryVerses = [];
  bool _loading = true;
  String? _error;
  final _highlightKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _startArrival(widget.highlightVerse);
    _loadVerses();
  }

  @override
  void didUpdateWidget(_ChapterPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightVerse != widget.highlightVerse &&
        widget.highlightVerse != null) {
      _startArrival(widget.highlightVerse);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _highlightKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              alignment: 0.3, duration: const Duration(milliseconds: 300));
        }
      });
    }
  }

  Future<void> _loadVerses() async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final settings = Provider.of<SettingsService>(context, listen: false);

      final primary = await dbService.getChapter(
        bookNum: widget.ref.bookNum,
        chapter: widget.ref.chapter,
        translationId: settings.primaryTranslationId,
      );

      List<Verse> secondary = [];
      if (settings.isDualLanguage && settings.secondaryTranslationId != null) {
        secondary = await dbService.getChapter(
          bookNum: widget.ref.bookNum,
          chapter: widget.ref.chapter,
          translationId: settings.secondaryTranslationId!,
        );
      }

      if (!mounted) return;
      setState(() {
        _error = null;
        _primaryVerses = primary;
        _secondaryVerses = secondary;
        _loading = false;
      });
      widget.onVersesLoaded(primary, secondary);

      // Scroll to the marked verse, if one is still marked.
      if (_arrivedAt != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = _highlightKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              alignment: 0.3,
            );
          }
        });
      }
    } catch (e, stack) {
      debugPrint('[TCR] _loadVerses error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  (List<Verse>, List<Verse>) _splitVerses(List<Verse> verses) {
    if (verses.length <= 2) return (verses, const []);
    final total = verses.fold(0, (sum, v) => sum + v.text.length);
    if (total == 0) return (verses, const []);
    var running = 0;
    final mid = total ~/ 2;
    for (int i = 0; i < verses.length; i++) {
      running += verses[i].text.length;
      if (running >= mid) {
        final splitAt = (i + 1).clamp(1, verses.length - 1);
        return (verses.sublist(0, splitAt), verses.sublist(splitAt));
      }
    }
    final half = verses.length ~/ 2;
    return (verses.sublist(0, half), verses.sublist(half));
  }

  List<InlineSpan> _buildVerseTextSpans(String text,
      {required bool applyKeywords}) {
    if (!applyKeywords ||
        widget.searchKeywords == null ||
        widget.searchKeywords!.isEmpty) {
      return [TextSpan(text: text)];
    }
    final pattern = RegExp(
      // The text has already been through joinKoreanWords, so the pattern
      // has to tolerate a joiner between every pair of characters.
      widget.searchKeywords!.map(keywordPatternForJoined).join('|'),
      caseSensitive: false,
    );
    final spans = <InlineSpan>[];
    int lastEnd = 0;
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

  /// [separated] draws the gap and the rule under this verse. Off for a
  /// side-by-side column, where the row does it instead.
  Widget _buildVerseItem(SettingsService settings, Verse verse,
      {bool isPrimary = true, bool separated = true}) {
    // See reader_pane.dart: the arrival marks both columns, while the scroll
    // anchor — a GlobalKey — can only live on one of them.
    final isArrival = _arrivedAt != null && verse.verse == _arrivedAt;
    final isSearchVerse = isArrival && isPrimary;
    final isHighlighted =
        widget.selectedNums.contains(verse.verse) || isArrival;
    return Container(
      key: isSearchVerse ? _highlightKey : null,
      // In a single column the verse owns its gap and its rule. Side by side
      // it must not: the two columns are as tall as their own text, so a rule
      // drawn per cell lands at a different height in each and the page fills
      // with stray fragments. There the row draws one rule across both.
      padding: separated
          ? EdgeInsets.only(bottom: settings.verseGap)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: isHighlighted
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.4)
            : null,
        borderRadius: isHighlighted ? BorderRadius.circular(8) : null,
        border: separated ? verseRuleBorder(context) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: kReaderTextInset, vertical: 2),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            _clearArrival();
            widget.onVerseLongPress(verse.verse);
          },
          onTap: () {
            _clearArrival();
            widget.onVerseTap(verse.verse);
          },
          child: RichText(
            textScaler:
                MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.5),
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: settings.lineHeight,
                    fontSize: settings.fontSize,
                    fontWeight: settings.textWeight,
                  ),
              children: [
                TextSpan(
                  text: '${verse.verse} ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: settings.fontSize * 0.75,
                  ),
                ),
                if (widget.bookmarkedUids.contains(verse.verseUid))
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.bookmark,
                        size: settings.fontSize * 0.8,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ..._buildVerseTextSpans(joinKoreanWords(verse.text),
                    applyKeywords: isSearchVerse),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColumnContent(SettingsService settings, List<Verse> verses) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: verses.map((v) => _buildVerseItem(settings, v)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 56, color: Colors.red),
              const SizedBox(height: 16),
              const Text('성경을 불러오지 못했어요',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('$_error', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_primaryVerses.isEmpty) {
      return const Center(
        child: Text('이 장에는 구절이 없어요', style: TextStyle(fontSize: 17)),
      );
    }

    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        if (settings.isDualLanguage && _secondaryVerses.isNotEmpty) {
          final pairs = pairVersesByNumber(_primaryVerses, _secondaryVerses);
          final ids = settings.selectedTranslationIds;
          return Column(
            children: [
              // Outside the scroll view, so which column is which stays
              // answerable at verse 40 and not only at verse 1.
              columnHeaderRow(
                context,
                left: chapterTitleFor(
                    widget.ref.book, widget.ref.chapter, ids.first),
                right: chapterTitleFor(widget.ref.book, widget.ref.chapter,
                    ids.length > 1 ? ids[1] : ids.first),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        for (final pair in pairs)
                          // One rule per verse pair; see reader_pane.dart.
                          Container(
                            padding: EdgeInsets.only(bottom: settings.verseGap),
                            decoration: BoxDecoration(
                              border: verseRuleBorder(context),
                            ),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: pair.primary != null
                                        ? _buildVerseItem(
                                            settings, pair.primary!,
                                            separated: false)
                                        : const SizedBox(),
                                  ),
                                  VerticalDivider(
                                    width: 1,
                                    thickness: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                  Expanded(
                                    child: pair.secondary != null
                                        ? _buildVerseItem(
                                            settings, pair.secondary!,
                                            isPrimary: false, separated: false)
                                        : const SizedBox(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // Splitting one chapter into two text columns only helps when each
            // column is still wide enough to read. On a half-open foldable or a
            // small tablet it produces two cramped ribbons instead, so below
            // this width a single centred column is used.
            final canSplit = constraints.maxWidth >= kTwoColumnMinWidth;
            if (!canSplit) {
              return SingleChildScrollView(
                // Align, not Center: a short chapter used to float in the
                // middle of the screen.
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: _buildColumnContent(settings, _primaryVerses),
                  ),
                ),
              );
            }

            final (leftVerses, rightVerses) = _splitVerses(_primaryVerses);
            if (rightVerses.isEmpty) {
              return SingleChildScrollView(
                child: _buildColumnContent(settings, leftVerses),
              );
            }
            return SingleChildScrollView(
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildColumnContent(settings, leftVerses)),
                    // Sits on the fold's hinge when the device is opened flat,
                    // which is where a gap belongs anyway. The verses carry
                    // their own inset on both sides, so the line needs none.
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    Expanded(child: _buildColumnContent(settings, rightVerses)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
