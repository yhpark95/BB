import '../screens/search_screen.dart' show SearchState;

/// A place the reader was, kept so they can get back to it.
class NavPoint {
  final String bookNum;
  final int chapter;

  /// The verse arrived at, when the jump came from a search result or a
  /// bookmark. Going back returns to the verse, not just the chapter.
  final int? verse;

  /// The search that led here, if any. Carried so that returning to a place
  /// reached from a search also brings back the 검색결과 button.
  final SearchState? search;

  const NavPoint({
    required this.bookNum,
    required this.chapter,
    this.verse,
    this.search,
  });

  /// Two points are the same place if they are the same chapter of the same
  /// book. The verse and the search that led there do not make it elsewhere.
  bool samePlaceAs(NavPoint other) =>
      bookNum == other.bookNum && chapter == other.chapter;
}

/// Where the reader has jumped, and where they can jump back to.
///
/// Only deliberate jumps are recorded — a book chosen from the picker, a
/// search result, a bookmark. Turning to the next chapter is reading, not
/// travelling: reading thirty chapters of Psalms must not turn into thirty
/// presses of back, while one mistaken jump has to be undone in a single one.
///
/// Memory only. The last reading position is restored on launch as before;
/// nobody expects yesterday's back button to still work.
class NavHistory {
  /// Enough to cover a session's worth of jumping without letting back become
  /// the way out of the app.
  static const int maxBack = 20;
  static const int maxRecent = 10;

  final List<NavPoint> _back = [];
  final List<NavPoint> _forward = [];
  final List<NavPoint> _recent = [];

  bool get canGoBack => _back.isNotEmpty;
  bool get canGoForward => _forward.isNotEmpty;
  int get backLength => _back.length;

  /// Where jumps have landed, newest first.
  List<NavPoint> get recent => List.unmodifiable(_recent);

  /// Records a deliberate jump: [from] is the place being left, [to] the place
  /// being opened.
  void jump({required NavPoint from, required NavPoint to}) {
    // Branching off abandons whatever was ahead, the way a browser does.
    _forward.clear();

    if (_back.isEmpty || !_back.last.samePlaceAs(from)) {
      _back.add(from);
      if (_back.length > maxBack) _back.removeAt(0);
    }

    _recent.removeWhere((p) => p.samePlaceAs(to));
    _recent.insert(0, to);
    if (_recent.length > maxRecent) _recent.removeLast();
  }

  /// The place to return to, or null when there is none. [current] is where
  /// the reader is now, so it can be gone forward to again.
  NavPoint? back({required NavPoint current}) {
    if (_back.isEmpty) return null;
    _forward.add(current);
    return _back.removeLast();
  }

  /// Undoes a [back].
  NavPoint? forward({required NavPoint current}) {
    if (_forward.isEmpty) return null;
    _back.add(current);
    return _forward.removeLast();
  }
}
