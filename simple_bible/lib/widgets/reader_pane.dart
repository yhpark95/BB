import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import 'verse_selection.dart';
import '../utils/korean_wrap.dart';
import '../utils/verse_pairing.dart';
import '../models/verse.dart';
import '../models/book.dart';
import 'reader_gesture_layer.dart';
import 'chapter_picker.dart';
import 'reader_bar.dart';

/// Reusable reader content — no Scaffold, no AppBar.
class ReaderPane extends StatefulWidget {
  final String bookNum;
  final int chapter;

  /// Bumped by the parent on a deliberate jump. The pane reloads on a change
  /// to this only — [chapter] is also echoed back by the pane as the reader
  /// turns pages, and reloading on that would fight the user.
  final int navSeq;

  final int? highlightVerse;
  final List<String>? searchKeywords;

  /// Verse to scroll to on the first load, without marking it. Used to resume
  /// where the reader stopped when the app is reopened.
  final int? restoreVerse;

  /// Where going forward would lead, e.g. "마태복음 5장". Null when there is
  /// nowhere ahead, or once the reader has resumed reading and no longer
  /// needs the offer.
  final String? forwardLabel;
  final VoidCallback? onForward;

  final void Function(Book? book, int chapter, int chapterCount)?
      onStateChanged;

  const ReaderPane({
    super.key,
    required this.bookNum,
    required this.chapter,
    this.navSeq = 0,
    this.highlightVerse,
    this.searchKeywords,
    this.restoreVerse,
    this.forwardLabel,
    this.onForward,
    this.onStateChanged,
  });

  @override
  State<ReaderPane> createState() => ReaderPaneState();
}

class ReaderPaneState extends State<ReaderPane> with VerseSelectionMixin {
  List<Verse> _verses = [];
  List<Verse> _secondaryVerses = [];
  Book? _book;
  Book? _prevBook;
  Book? _nextBook;
  int _chapterCount = 1;
  bool _loading = true;

  /// Whether the wait has gone on long enough to be worth admitting to.
  ///
  /// Reading a chapter takes about a millisecond, so a spinner shown the
  /// instant loading starts is a flash and nothing more. It is still needed
  /// once: on the very first launch the 34MB Bible is unpacked from the app
  /// bundle and written to disk, which takes seconds, and a blank screen there
  /// looks like a crash. So the spinner waits before appearing, and an
  /// ordinary load finishes long before it does.
  bool _slowLoad = false;
  Timer? _slowLoadTimer;

  void _beginLoading() {
    _slowLoadTimer?.cancel();
    _slowLoad = false;
    _slowLoadTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && _loading) setState(() => _slowLoad = true);
    });
  }

  void _endLoading() {
    _slowLoadTimer?.cancel();
    _slowLoadTimer = null;
    _slowLoad = false;
  }

  String? _error;
  late String _currentBookNum;
  late int _currentChapter;
  String? _lastIdsKey;
  final ScrollController _scrollController = ScrollController();
  final _highlightKey = GlobalKey();

  @override
  List<Verse> get selectionPrimary => _verses;
  @override
  List<Verse> get selectionSecondary => _secondaryVerses;
  @override
  Book? get selectionBook => _book;
  @override
  int get selectionChapter => _currentChapter;

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

  Book? get book => _book;
  int get currentChapter => _currentChapter;
  int get chapterCount => _chapterCount;

  @override
  void initState() {
    super.initState();
    _startArrival(widget.highlightVerse);
    _pendingRestore = widget.highlightVerse == null ? widget.restoreVerse : null;
    _beginLoading();
    _currentBookNum = widget.bookNum;
    _currentChapter = widget.chapter;
    _loadData();
    _saveReadingPosition();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsService>(context);
    final idsKey = settings.selectedTranslationIds.join(',');
    if (_lastIdsKey != null && _lastIdsKey != idsKey) {
      setState(() {
        _loading = true;
        resetSelectionState();
      });
      _beginLoading();
      _loadData();
    }
    _lastIdsKey = idsKey;
  }

  @override
  void didUpdateWidget(ReaderPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navSeq != widget.navSeq) {
      setState(() {
        _currentBookNum = widget.bookNum;
        _currentChapter = widget.chapter;
        _loading = true;
        resetSelectionState();
      });
      // Opening a bookmark or a search result arrives here, not in the branch
      // below. Without this the verse is never marked, and since the anchor
      // that _loadData scrolls to only exists on the marked verse, the reader
      // was left at the top of the right chapter.
      _startArrival(widget.highlightVerse);
      _beginLoading();
      _loadData();
      _saveReadingPosition();
    } else if (oldWidget.highlightVerse != widget.highlightVerse &&
        widget.highlightVerse != null) {
      _startArrival(widget.highlightVerse);
      // Same chapter, just scroll to the newly highlighted verse.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _highlightKey.currentContext != null) {
          Scrollable.ensureVisible(
            _highlightKey.currentContext!,
            alignment: 0.3,
            duration: const Duration(milliseconds: 300),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _arrivalTimer?.cancel();
    _slowLoadTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// One-shot: consumed by the first load that finishes.
  int? _pendingRestore;

  /// Scroll anchors for the primary column's verses, for knowing which verse
  /// is at the top of the screen. Keyed per chapter: while a page turn fades,
  /// the old and new chapter are both mounted, and sharing GlobalKeys between
  /// them would be a duplicate-key error.
  final Map<int, GlobalKey> _verseKeys = {};
  String _verseKeysFor = '';

  GlobalKey _verseKey(int verse) {
    final id = '$_currentBookNum-$_currentChapter';
    if (id != _verseKeysFor) {
      _verseKeys.clear();
      _verseKeysFor = id;
    }
    return _verseKeys.putIfAbsent(verse, () => GlobalKey());
  }

  /// The first verse still visible at the top of the pane.
  int? _topVisibleVerse() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    // The side-by-side layout keeps a header row above the scroll view.
    final top = box.localToGlobal(Offset.zero).dy +
        (Provider.of<SettingsService>(context, listen: false).isDualLanguage
            ? 56
            : 0);
    for (final v in _verses) {
      final rb = _verseKeys[v.verse]?.currentContext?.findRenderObject();
      if (rb is! RenderBox || !rb.attached) continue;
      if (rb.localToGlobal(Offset.zero).dy + rb.size.height > top) {
        return v.verse;
      }
    }
    return null;
  }

  void _saveTopVerse() {
    final verse = _topVisibleVerse();
    if (verse == null) return;
    Provider.of<SettingsService>(context, listen: false).saveLastPosition(
      bookNum: _currentBookNum,
      chapter: _currentChapter,
      verseUid: SettingsService.verseUidOf(_currentBookNum, _currentChapter, verse),
    );
  }

  /// Identifies the newest load. A load that finishes after a newer one was
  /// started (translation switched mid-load, a jump during a turn) must not
  /// overwrite the newer text.
  int _loadSeq = 0;

  /// Book list never changes while the app runs; fetched once, not per chapter.
  List<Book>? _booksCache;

  Future<void> _loadData() async {
    final seq = ++_loadSeq;
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final settings = Provider.of<SettingsService>(context, listen: false);

      final verses = await dbService.getChapter(
        bookNum: _currentBookNum,
        chapter: _currentChapter,
        translationId: settings.primaryTranslationId,
      );

      List<Verse> secondary = [];
      if (settings.isDualLanguage && settings.secondaryTranslationId != null) {
        secondary = await dbService.getChapter(
          bookNum: _currentBookNum,
          chapter: _currentChapter,
          translationId: settings.secondaryTranslationId!,
        );
      }

      final books = _booksCache ??= await dbService.getAllBooks();
      final chapterCount = await dbService.getChapterCount(_currentBookNum);
      final bookIndex = books.indexWhere((b) => b.bookNum == _currentBookNum);
      final book = bookIndex >= 0 ? books[bookIndex] : books.first;
      final prevBook = bookIndex > 0 ? books[bookIndex - 1] : null;
      final nextBook =
          bookIndex < books.length - 1 ? books[bookIndex + 1] : null;

      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = null;
        _verses = verses;
        _secondaryVerses = secondary;
        _book = book;
        _prevBook = prevBook;
        _nextBook = nextBook;
        _chapterCount = chapterCount;
        _loading = false;
        _endLoading();
      });
      widget.onStateChanged?.call(book, _currentChapter, chapterCount);
      refreshBookmarks(dbService);

      // A new chapter starts at the top. Guarded and deferred: the scroll view
      // for the chapter just loaded may not be attached yet, and an unguarded
      // jumpTo here used to work only because the previous chapter's scroll
      // view happened to still be alive.
      final restore = _pendingRestore;
      _pendingRestore = null;
      if (_arrivedAt == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = restore == null ? null : _verseKeys[restore]?.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx, alignment: 0, duration: Duration.zero);
          } else if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
      }

      // Scroll to the marked verse, if one is still marked.
      if (_arrivedAt != null) {
        debugPrint(
            '[RP] highlightVerse=${widget.highlightVerse}, verseCount=${_verses.length}');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = _highlightKey.currentContext;
          debugPrint(
              '[RP] _highlightKey.currentContext=${ctx != null ? "found" : "null"}');
          if (ctx != null) {
            debugPrint('[RP] calling Scrollable.ensureVisible');
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
      debugPrint('[RP] _loadData error: $e\n$stack');
      if (!mounted || seq != _loadSeq) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _endLoading();
      });
    }
  }

  void _saveReadingPosition() {
    final settings = Provider.of<SettingsService>(context, listen: false);
    settings.saveLastPosition(
        bookNum: _currentBookNum, chapter: _currentChapter);
  }

  void navigateToChapter(int newChapter) {
    if (_loading) return;
    if (newChapter < 1) {
      if (_prevBook != null) _navigateToBook(_prevBook!, jumpToEnd: true);
      return;
    }
    if (newChapter > _chapterCount) {
      if (_nextBook != null) _navigateToBook(_nextBook!);
      return;
    }
    setState(() {
      _currentChapter = newChapter;
      _loading = true;
      resetSelectionState();
    });
    // The arrival cue belonged to the chapter being left. Kept, it marked the
    // same verse number in the next chapter and scrolled there.
    _clearArrival();
    _beginLoading();
    // The scroll goes back to the top once the new chapter is in place, not
    // now — jumping the chapter still on screen would be its own flicker.
    _loadData();
    _saveReadingPosition();
  }

  void _navigateToBook(Book target, {bool jumpToEnd = false}) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    try {
      final chapterCount = await dbService.getChapterCount(target.bookNum);
      if (!mounted) return;
      setState(() {
        _currentBookNum = target.bookNum;
        _currentChapter = jumpToEnd ? chapterCount : 1;
        _loading = true;
        resetSelectionState();
      });
      _clearArrival();
      _beginLoading();
      _loadData();
      _saveReadingPosition();
    } catch (e, stack) {
      debugPrint('[RP] _navigateToBook error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void showChapterPicker() {
    final book = _book;
    if (book == null) return;
    final settings = Provider.of<SettingsService>(context, listen: false);
    showPickerDialog(
      context,
      ChapterPicker(
        bookLabel: book.nameFor(settings.primaryTranslationId),
        chapterCount: _chapterCount,
        currentChapter: _currentChapter,
        onSelected: (chapter) {
          Navigator.pop(context);
          if (chapter != _currentChapter) {
            navigateToChapter(chapter);
          }
        },
      ),
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

  // Returns keyword-bolded spans for the given text. Only applied for the
  // search-highlighted verse (isPrimary prevents duplicate keys in dual-column).
  List<InlineSpan> _buildVerseTextSpans(String text,
      {required bool applyKeywords}) {
    if (!applyKeywords ||
        widget.searchKeywords == null ||
        widget.searchKeywords!.isEmpty) {
      return [TextSpan(text: text)];
    }
    // The text has already been through joinKoreanWords, so the pattern has
    // to tolerate a joiner between every pair of characters.
    final pattern = RegExp(
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
    // Two different questions. The verse arrived at is the same verse in both
    // translations, so both columns are marked — selection already behaves
    // that way, and marking only one made the other look like a different
    // verse. The scroll anchor is a GlobalKey and can exist once, so that one
    // stays on the primary column.
    final isArrival = _arrivedAt != null && verse.verse == _arrivedAt;
    final holdsScrollAnchor = isArrival && isPrimary;
    final isHighlighted = isArrival || isSelected(verse.verse);

    return Container(
      key: holdsScrollAnchor
          ? _highlightKey
          : (isPrimary ? _verseKey(verse.verse) : null),
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
          // A tap selects; a long-press extends to a range. Both retire the
          // arrival cue first, so a verse reached from a bookmark or a search
          // result stops looking selected the moment it is touched.
          onLongPress: () {
            _clearArrival();
            longPressVerse(verse.verse);
          },
          onTap: () {
            _clearArrival();
            tapVerse(verse.verse);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                // RichText ignores the system font-size setting unless told
                // otherwise. Honour it, capped so the in-app size on top of a
                // large system size cannot push a verse off the screen.
                textScaler: MediaQuery.textScalerOf(context)
                    .clamp(maxScaleFactor: 1.5),
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        // Leading is loose enough to separate lines but not so
                        // loose that a page fits only one verse.
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
                    // Without this a bookmarked verse looks like any other,
                    // and the only way to check was to leave for the bookmark
                    // list. It rides in the text so it reflows with it.
                    if (isBookmarkedVerse(verse))
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
                        applyKeywords: holdsScrollAnchor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleColumn(SettingsService settings) {
    // Align, not Center: Center centres on both axes, so a chapter shorter
    // than the screen floated in the middle of it. Only the horizontal
    // centring is wanted — the reading column is capped in width.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          controller: _scrollController,
          // Horizontal spacing comes from the verse padding alone.
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _verses.map((v) => _buildVerseItem(settings, v)).toList(),
          ),
        ),
      ),
    );
  }

  /// Dual language, side by side.
  ///
  /// The two translations sit in their own columns so the same verse can be
  /// read across, which is the point of turning a second one on. Each row is
  /// as tall as the longer of the two.
  Widget _buildDualColumns(SettingsService settings) {
    final pairs = pairVersesByNumber(_verses, _secondaryVerses);
    final ids = settings.selectedTranslationIds;
    // Align, not Center: see _buildSingleColumn.
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            // Outside the scroll view: which column is which has to stay
            // answerable at verse 40, not only at verse 1.
            //
            columnHeaderRow(
              context,
              left: chapterTitleFor(_book, _currentChapter, ids.first),
              right: chapterTitleFor(
                  _book, _currentChapter, ids.length > 1 ? ids[1] : ids.first),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    for (final pair in pairs)
                      // One rule per verse pair, across the whole row: the
                      // two columns end at different heights, so a rule drawn
                      // inside each cell lands somewhere different on each side.
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
                                    ? _buildVerseItem(settings, pair.primary!,
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
                                    ? _buildVerseItem(settings, pair.secondary!,
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only when there is nothing on screen yet and the wait has actually been
    // noticeable — a chapter turn keeps the previous text until the next one
    // arrives, and finishes far too fast to need telling anyone about.
    if (_loading && _verses.isEmpty && _slowLoad) {
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

    if (_error != null) {
      // The exception text goes to the log. A reader of this app is not going
      // to act on "DatabaseException(no such table: verses) sql=..." — it just
      // reads as the phone being broken.
      debugPrint('[RP] showing load failure: $_error');
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
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도', style: TextStyle(fontSize: 16)),
                onPressed: () {
                  setState(() {
                    _error = null;
                    _loading = true;
                  });
                  _beginLoading();
                  _loadData();
                },
              ),
            ],
          ),
        ),
      );
    }

    // Only once the load is done: mid-load this branch used to run for a
    // frame or two and tell the reader the chapter was empty.
    if (_verses.isEmpty) {
      if (_loading) return const SizedBox.shrink();
      return const Center(
        child: Text('이 장에는 구절이 없어요', style: TextStyle(fontSize: 17)),
      );
    }

    return Consumer<SettingsService>(
      builder: (context, settings, _) => Column(
        children: [
          Expanded(
            child: ReaderGestureLayer(
              onSwipeLeft: () => navigateToChapter(_currentChapter + 1),
              onSwipeRight: () => navigateToChapter(_currentChapter - 1),
              // Without this the text simply blinks into different text. A
              // short fade says "the page changed" instead.
              child: NotificationListener<ScrollEndNotification>(
                // Remember the verse at the top once a scroll settles, so
                // reopening the app resumes mid-chapter.
                onNotification: (_) {
                  _saveTopVerse();
                  return false;
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  child: KeyedSubtree(
                    key: ValueKey('$_currentBookNum-$_currentChapter'),
                    child: settings.isDualLanguage &&
                            _secondaryVerses.isNotEmpty
                        ? _buildDualColumns(settings)
                        : _buildSingleColumn(settings),
                  ),
                ),
              ),
            ),
          ),
          // Above the navigation, below the text. Hidden while verses are
          // selected: that bar is the reader's whole attention, and stacking
          // three rows under the page is one too many.
          if (widget.forwardLabel != null && selectedVerses.isEmpty)
            forwardBar(
              context,
              label: widget.forwardLabel!,
              onTap: widget.onForward ?? () {},
            ),
          selectedVerses.isNotEmpty
              ? _buildVerseActionBar()
              : readerBottomBar(
                  context,
                  chapter: _currentChapter,
                  chapterCount: _chapterCount,
                  onPrev: (_currentChapter > 1 || _prevBook != null)
                      ? () => navigateToChapter(_currentChapter - 1)
                      : null,
                  onNext: (_currentChapter < _chapterCount || _nextBook != null)
                      ? () => navigateToChapter(_currentChapter + 1)
                      : null,
                  onChapterTap: showChapterPicker,
                ),
        ],
      ),
    );
  }
}
