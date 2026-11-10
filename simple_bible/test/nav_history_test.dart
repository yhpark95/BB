import 'package:flutter_test/flutter_test.dart';

import 'package:simple_bible/screens/search_screen.dart' show SearchState;
import 'package:simple_bible/services/nav_history.dart';

/// The reader's back/forward stack on its own, away from the widgets.
///
/// The widget tests in reader_history_test.dart pin what a reader sees; these
/// pin the rules underneath — what a jump records, what a back hands back, and
/// the two caps that stop either list growing without end.
void main() {
  NavPoint at(String bookNum, int chapter) =>
      NavPoint(bookNum: bookNum, chapter: chapter);

  group('back and forward', () {
    test('a fresh history has nowhere to go', () {
      final history = NavHistory();

      expect(history.canGoBack, isFalse);
      expect(history.canGoForward, isFalse);
      expect(history.back(current: at('43', 3)), isNull);
    });

    test('back returns the place the jump started from', () {
      final history = NavHistory();
      history.jump(from: at('43', 3), to: at('40', 5));

      final previous = history.back(current: at('40', 5));

      expect(previous, isNotNull);
      expect(previous!.samePlaceAs(at('43', 3)), isTrue);
    });

    test('forward undoes a back', () {
      final history = NavHistory();
      history.jump(from: at('43', 3), to: at('40', 5));
      history.back(current: at('40', 5));

      expect(history.canGoForward, isTrue);
      final ahead = history.forward(current: at('43', 3));

      expect(ahead!.samePlaceAs(at('40', 5)), isTrue);
      expect(history.canGoForward, isFalse);
    });

    test('a new jump discards what was ahead', () {
      // Branching off, the way a browser does. Going forward to a place the
      // reader has since navigated away from is a promise nothing can keep.
      final history = NavHistory();
      history.jump(from: at('43', 3), to: at('40', 5));
      history.back(current: at('40', 5));
      expect(history.canGoForward, isTrue);

      history.jump(from: at('43', 3), to: at('19', 23));

      expect(history.canGoForward, isFalse);
    });

    test('jumping again from the same place does not stack a duplicate', () {
      // Two taps on the same book in the picker are one departure, and back
      // should not have to be pressed twice to undo them.
      final history = NavHistory();
      history.jump(from: at('43', 3), to: at('40', 5));
      history.jump(from: at('43', 3), to: at('19', 23));

      expect(history.backLength, 1);
    });

    test('the back stack is capped, dropping the oldest', () {
      final history = NavHistory();
      for (var i = 1; i <= NavHistory.maxBack + 5; i++) {
        history.jump(from: at('01', i), to: at('01', i + 1));
      }

      expect(history.backLength, NavHistory.maxBack);

      NavPoint? last;
      for (var i = 0; i < NavHistory.maxBack; i++) {
        last = history.back(current: at('01', 99));
        expect(last, isNotNull);
      }
      expect(history.back(current: at('01', 99)), isNull);
      expect(last!.chapter, 6,
          reason: 'the oldest departures should have fallen off the bottom');
    });

    test('the search that led somewhere travels back with it', () {
      // Otherwise returning to a verse found by searching loses the 검색결과
      // button, and the results it came from are gone.
      const search = SearchState(
        keywords: ['사랑'],
        operators: [],
        selectedBookNums: {},
        translationId: 2,
        results: [],
      );
      final history = NavHistory();
      history.jump(
        from: const NavPoint(
            bookNum: '43', chapter: 3, verse: 16, search: search),
        to: at('40', 5),
      );

      final previous = history.back(current: at('40', 5));

      expect(previous!.verse, 16);
      expect(previous.search, same(search));
    });
  });

  group('recent places', () {
    test('a jump is listed, newest first', () {
      final history = NavHistory();
      history.jump(from: at('43', 3), to: at('40', 5));
      history.jump(from: at('40', 5), to: at('19', 23));

      expect(history.recent.length, 2);
      expect(history.recent.first.samePlaceAs(at('19', 23)), isTrue);
      expect(history.recent.last.samePlaceAs(at('40', 5)), isTrue);
    });

    test('going somewhere twice moves it up rather than repeating it', () {
      final history = NavHistory();
      history.jump(from: at('43', 3), to: at('40', 5));
      history.jump(from: at('40', 5), to: at('19', 23));
      history.jump(from: at('19', 23), to: at('40', 5));

      expect(history.recent.length, 2);
      expect(history.recent.first.samePlaceAs(at('40', 5)), isTrue);
    });

    test('the recent list is capped, dropping the oldest', () {
      final history = NavHistory();
      for (var i = 1; i <= NavHistory.maxRecent + 3; i++) {
        history.jump(from: at('01', i), to: at('02', i));
      }

      expect(history.recent.length, NavHistory.maxRecent);
      expect(history.recent.first.samePlaceAs(at('02', NavHistory.maxRecent + 3)),
          isTrue);
    });

    test('a place merely passed through on the way back is not listed', () {
      // The list is "최근 본 곳" — somewhere chosen, not somewhere rewound to.
      final history = NavHistory();
      history.jump(from: at('43', 3), to: at('40', 5));
      history.back(current: at('40', 5));

      expect(history.recent.length, 1);
      expect(history.recent.single.samePlaceAs(at('40', 5)), isTrue);
    });
  });
}
