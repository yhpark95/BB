import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/services/database_service.dart';

/// Pure-logic checks on the search layer. The routing decision here (FTS index
/// vs LIKE scan) is what keeps Korean search fast without changing which
/// verses come back, so it is worth pinning down without a database.
void main() {
  group('isHangulOnly — decides whether the FTS index may be used', () {
    test('accepts Korean words', () {
      expect(DatabaseService.isHangulOnly('사랑'), isTrue);
      expect(DatabaseService.isHangulOnly('하나님'), isTrue);
      expect(DatabaseService.isHangulOnly('영원한 생명'), isTrue);
    });

    test('rejects Latin script, which needs substring matching', () {
      // "love" as a prefix query misses "beloved", so English must not take
      // the FTS path.
      expect(DatabaseService.isHangulOnly('love'), isFalse);
      expect(DatabaseService.isHangulOnly('amour'), isFalse);
    });

    test('rejects mixed and non-word input', () {
      expect(DatabaseService.isHangulOnly('사랑love'), isFalse);
      expect(DatabaseService.isHangulOnly('요한3서'), isFalse);
      expect(DatabaseService.isHangulOnly(''), isFalse);
      expect(DatabaseService.isHangulOnly('   '), isFalse);
      expect(DatabaseService.isHangulOnly('사랑!'), isFalse);
    });
  });

  group('buildFtsMatch', () {
    test('emits a prefix query for a single term', () {
      expect(DatabaseService.buildFtsMatch(['사랑'], []), '"사랑"*');
    });

    test('keeps the AND / OR shape the LIKE path builds by hand', () {
      // FTS5 binds AND tighter than OR, which is the same grouping as
      // (A AND B) OR C.
      expect(
        DatabaseService.buildFtsMatch(['가', '나', '다'], ['AND', 'OR']),
        '"가"* AND "나"* OR "다"*',
      );
    });

    test('quotes terms so punctuation cannot become FTS syntax', () {
      expect(DatabaseService.buildFtsMatch(['a"b'], []), '"a""b"*');
    });
  });

  group('result cap', () {
    test('the threshold clears an ordinary search but catches a runaway one',
        () {
      // Counts measured against the shipped Korean text: 사랑 518, 하나님
      // 3,584, 그 15,088. An ordinary word must never trigger the advice, and
      // a word matching half the Bible always must. Nothing is truncated
      // either way — the list renders lazily.
      expect(DatabaseService.searchAdviseNarrowing, greaterThan(518));
      expect(DatabaseService.searchAdviseNarrowing, lessThan(15088));
    });
  });

  group('searchVersesAdvanced argument checks', () {
    final db = DatabaseService();

    test('an empty keyword list yields no results rather than throwing',
        () async {
      expect(await db.searchVersesAdvanced(keywords: [], operators: []),
          isEmpty);
    });

    test('a mismatched operator count is rejected in release builds too',
        () async {
      // This used to be an assert(), which is stripped from release builds —
      // the app would then index past the end of the list instead.
      expect(
        () => db.searchVersesAdvanced(
            keywords: ['가', '나'], operators: const []),
        throwsArgumentError,
      );
    });
  });
}
