import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/nav_history.dart';
import '../services/settings_service.dart';
import '../models/book.dart';
import '../widgets/book_chapter_picker.dart';
import '../widgets/chapter_picker.dart';
import '../widgets/reader_pane.dart';
import '../widgets/two_column_reader.dart';
import '../widgets/reader_bar.dart';
import 'search_screen.dart';
import 'bookmarks_screen.dart';

/// Width at which the reader switches to the wide, page-turning layout.
/// A folded Galaxy Fold cover screen sits well under this; unfolded is above.
const double kWideBreakpoint = 600;

class ReaderScreen extends StatefulWidget {
  final String bookNum;
  final int chapter;
  final int? highlightVerse;
  final List<String>? searchKeywords;

  /// Verse to scroll to on open, unmarked. Set only when resuming.
  final int? restoreVerse;

  /// True when this reader is the app's root route. The root reader has no
  /// screen to pop back to, so Back asks before leaving the app.
  final bool isRoot;

  const ReaderScreen({
    super.key,
    required this.bookNum,
    required this.chapter,
    this.highlightVerse,
    this.searchKeywords,
    this.restoreVerse,
    this.isRoot = false,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _paneKey = GlobalKey<ReaderPaneState>();
  final _wideKey = GlobalKey<TwoColumnReaderState>();
  Book? _book;
  int _currentChapter = 1;
  int _chapterCount = 1;

  late String _bookNum;
  late int _chapter;
  int? _highlightVerse;

  final NavHistory _history = NavHistory();

  /// Where the reader is right now, for the history to hold on to.
  NavPoint get _here => NavPoint(
        bookNum: _bookNum,
        chapter: _currentChapter,
        verse: _highlightVerse,
        search: _searchSession,
      );

  /// Where 앞으로 leads, and the place it was offered from.
  ///
  /// The offer stands only while the reader is still standing where back put
  /// them. Going forward is how you undo a back you did not mean; once the
  /// reader turns a page they are reading again, and the row goes. Nothing
  /// here is on a timer — a clock is what made the old snack bar both nag and
  /// vanish too early.
  NavPoint? _forwardTarget;
  NavPoint? _forwardFrom;

  String? get _forwardLabel =>
      _forwardTarget == null ? null : _pointLabel(_forwardTarget!);

  void _retireForward() {
    if (_forwardTarget == null && _forwardFrom == null) return;
    _forwardTarget = null;
    _forwardFrom = null;
  }

  /// Records a deliberate jump. Turning a page never comes through here.
  void _recordJump(NavPoint destination) {
    _history.jump(from: _here, to: destination);
    // Branching off throws away what was ahead, so the offer of it has to go
    // with it.
    _retireForward();
  }

  /// Moves the reader to [point] without recording it — used by back and
  /// forward, which are undoing travel rather than doing more of it.
  void _restore(NavPoint point) {
    setState(() {
      if (point.bookNum != _bookNum) _book = null;
      _bookNum = point.bookNum;
      _chapter = point.chapter;
      _currentChapter = point.chapter;
      _highlightVerse = point.verse;
      _searchSession = point.search;
      _searchKeywords = point.search?.keywords;
      _navSeq++;
    });
  }

  /// Returns to where the last jump started. False when there is nowhere to
  /// go, which is what lets back fall through to leaving the app.
  bool _goBack() {
    // Where the reader is now becomes the way forward, so capture it before
    // the restore moves them.
    final leaving = _here;
    final previous = _history.back(current: leaving);
    if (previous == null) return false;
    _restore(previous);
    setState(() {
      _forwardTarget = leaving;
      _forwardFrom = previous;
    });
    return true;
  }

  /// Undoes a back. Nothing announces the move — the title pill and the
  /// chapter number have already changed, and saying it again in a bar over
  /// the verses was telling the reader what they can see.
  void _goForward() {
    final ahead = _history.forward(current: _here);
    if (ahead == null) return;
    _restore(ahead);
    setState(_retireForward);
  }
  List<String>? _searchKeywords;

  /// Incremented only on a deliberate navigation. The child readers reload on
  /// a change to this, never on [_chapter] alone — [_chapter] is also written
  /// back by the child as the user turns pages, and reacting to that would
  /// reload the chapter the reader is already on.
  int _navSeq = 0;

  /// Non-null while user came from a search result.
  SearchState? _searchSession;

  Map<String, Book> _booksByNum = {};

  Future<void> _loadBookNames() async {
    try {
      final books =
          await Provider.of<DatabaseService>(context, listen: false)
              .getAllBooks();
      if (!mounted) return;
      setState(() {
        _booksByNum = {for (final b in books) b.bookNum: b};
      });
    } catch (e) {
      // Only used for labels; a failure here must not stop the reader.
      debugPrint('[Reader] book names unavailable: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBookNames());
    _bookNum = widget.bookNum;
    _chapter = widget.chapter;
    _currentChapter = widget.chapter;
    _highlightVerse = widget.highlightVerse;
    _searchKeywords = widget.searchKeywords;
  }

  // Navigation from a search result — stores the full session.
  void _navigateFromSearch(
      String bookNum, int chapter, int? highlightVerse, SearchState state) {
    _recordJump(NavPoint(
        bookNum: bookNum,
        chapter: chapter,
        verse: highlightVerse,
        search: state));
    // Show the language the result was found in, otherwise the verse the user
    // just read in the result list is not on screen after the jump.
    Provider.of<SettingsService>(context, listen: false)
        .ensureTranslationVisible(state.translationId);
    setState(() {
      if (bookNum != _bookNum) _book = null;
      _bookNum = bookNum;
      _chapter = chapter;
      _currentChapter = chapter;
      _highlightVerse = highlightVerse;
      _searchKeywords = state.keywords;
      _searchSession = state;
      _navSeq++;
    });
  }

  // All other navigation — clears the search session.
  void _navigateTo(String bookNum, int chapter, {int? highlightVerse}) {
    _recordJump(NavPoint(
        bookNum: bookNum, chapter: chapter, verse: highlightVerse));
    setState(() {
      if (bookNum != _bookNum) _book = null;
      _bookNum = bookNum;
      _chapter = chapter;
      _currentChapter = chapter;
      _highlightVerse = highlightVerse;
      _searchKeywords = null;
      _searchSession = null;
      _navSeq++;
    });
  }

  void _openFreshSearch(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ScaffoldMessenger(
        child: SearchScreen(
          onSelect: (bookNum, chapter, highlightVerse, state) {
            Navigator.pop(context);
            _navigateFromSearch(bookNum, chapter, highlightVerse, state);
          },
        ),
      ),
    );
  }

  void _reopenSearch(BuildContext context, [SearchState? session]) {
    session ??= _searchSession;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ScaffoldMessenger(
        child: SearchScreen(
          initialState: session,
          onSelect: (bookNum, chapter, highlightVerse, state) {
            Navigator.pop(context);
            _navigateFromSearch(bookNum, chapter, highlightVerse, state);
          },
        ),
      ),
    );
  }

  /// Search button: when a result session is open it offers both going back to
  /// those results and starting over. Previously the button was disabled here,
  /// which left no way to run a new search.
  void _onSearchTap(BuildContext context) {
    if (_searchSession == null) {
      _openFreshSearch(context);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: const Icon(Icons.manage_search, size: 28),
              title: const Text('찾은 결과 다시 보기',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              subtitle: Text('"${_searchSession!.keywords.join(', ')}"'),
              onTap: () {
                Navigator.pop(sheetContext);
                _reopenSearch(context);
              },
            ),
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: const Icon(Icons.search, size: 28),
              title: const Text('새로 검색하기',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() {
                  _searchSession = null;
                  _searchKeywords = null;
                });
                _openFreshSearch(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openBookmarks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // The sheet owns a messenger of its own. Without one, the undo bar that
      // bookmarks shows would sit on screen until the sheet is closed:
      // ScaffoldMessenger only arms its dismiss timer while its own route is
      // the current one, and the app-level messenger's route is underneath
      // this sheet.
      builder: (_) => ScaffoldMessenger(
        child: BookmarksScreen(
          onSelect: (bookNum, chapter, highlightVerse) {
            Navigator.pop(context);
            _navigateTo(bookNum, chapter, highlightVerse: highlightVerse);
          },
        ),
      ),
    );
  }

  void _openBookPicker(BuildContext context) {
    showPickerDialog(
      context,
      BookChapterPicker(
        // The picker opens on the book being read, marks it, and scrolls to it.
        initialBook: _book,
        currentChapter: _currentChapter,
        onSelected: (bookNum, chapter) => _navigateTo(bookNum, chapter),
      ),
    );
  }

  /// One name, never "마가복음 / Mark". The second translation is already
  /// beside the first in the text itself, and joining them here was the only
  /// case that still could not fit the title.
  String _bookLabel(Book? book, SettingsService settings) =>
      book?.nameFor(settings.primaryTranslationId) ?? '성경 선택';

  /// "요한복음 3장" for the recent list and the back snack bar.
  String _pointLabel(NavPoint point) {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final name = _booksByNum[point.bookNum]?.nameFor(settings.primaryTranslationId);
    return name == null
        ? '${point.chapter}장'
        : '$name ${point.chapter}장';
  }

  /// Asked only once back has nowhere left to go.
  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('성경에서 나갈까요?'),
        content: const Text('읽던 곳은 그대로 저장돼요'),
        actions: [
          // "닫기" under "성경을 닫을까요?" read as closing the dialog, and it
          // sat on the right where a thumb lands first — so dismissing the
          // question quit the app. The leaving button now says leaving, and
          // the right-hand, filled position goes to staying.
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('나가기', style: TextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 읽기', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
    if (leave == true) {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final hasSession = _searchSession != null;

    void onStateChanged(Book? book, int chapter, int chapterCount) {
      if (_book == book && _currentChapter == chapter &&
          _chapterCount == chapterCount) {
        return;
      }
      setState(() {
        _book = book;
        _currentChapter = chapter;
        _chapterCount = chapterCount;
        // Mirror the child's position without bumping _navSeq, so that a
        // fold/unfold rebuild starts the new layout on the chapter actually
        // being read rather than the one the screen was opened at.
        _chapter = chapter;
        if (book != null) _bookNum = book.bookNum;

        // The reader has left the place back put them, so they are reading
        // again rather than correcting a mis-tap. The offer of the way
        // forward retires here — this is the only thing that retires it, and
        // it is an event, not a timer.
        final from = _forwardFrom;
        if (from != null &&
            !from.samePlaceAs(
                NavPoint(bookNum: _bookNum, chapter: chapter))) {
          _retireForward();
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kWideBreakpoint;

        // Back undoes travel. Reopening the search list is not travel, and
        // the 검색결과 button in the app bar already does it — so back no
        // longer has a search branch, and the two jobs stop overlapping.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_goBack()) return;
            if (widget.isRoot) {
              _confirmExit(context);
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            appBar: readerAppBar(
              context,
              bookLabel: _bookLabel(_book, settings),
              onBookTap: () => _openBookPicker(context),
              onSearchTap: () => _onSearchTap(context),
              onMoreTap: () => showReaderMoreSheet(
                context,
                onBookmarksTap: () => _openBookmarks(context),
                recent: _history.recent,
                recentLabel: _pointLabel,
                onRecentTap: (point) =>
                    _navigateTo(point.bookNum, point.chapter,
                        highlightVerse: point.verse),
              ),
              searchActive: hasSession,
            ),
            body: isWide
                ? TwoColumnReader(
                    key: _wideKey,
                    bookNum: _bookNum,
                    chapter: _chapter,
                    navSeq: _navSeq,
                    highlightVerse: _highlightVerse,
                    searchKeywords: _searchKeywords,
                    forwardLabel: _forwardLabel,
                    onForward: _goForward,
                    onStateChanged: onStateChanged,
                  )
                : ReaderPane(
                    key: _paneKey,
                    bookNum: _bookNum,
                    chapter: _chapter,
                    navSeq: _navSeq,
                    highlightVerse: _highlightVerse,
                    searchKeywords: _searchKeywords,
                    restoreVerse: widget.restoreVerse,
                    forwardLabel: _forwardLabel,
                    onForward: _goForward,
                    onStateChanged: onStateChanged,
                  ),
          ),
        );
      },
    );
  }
}
