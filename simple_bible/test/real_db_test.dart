import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Runs the real bundled Bible database on the PC, through SQLite's FFI
/// binding, so search and bookmark behaviour is checked without a phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late DatabaseService db;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('bb_test_');
    databaseFactory.setDatabasesPath(tmp.path);
    db = DatabaseService();
  });

  tearDownAll(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('initialization', () {
    test('concurrent first calls share one initialization', () async {
      final results = await Future.wait([db.database, db.database, db.database]);
      expect(identical(results[0], results[1]), isTrue);
      expect(identical(results[1], results[2]), isTrue);
    });

    test('has 66 books', () async {
      expect((await db.getAllBooks()).length, 66);
    });
  });

  group('reading', () {
    test('John 3 has 36 verses in Korean', () async {
      final v = await db.getChapter(bookNum: '43', chapter: 3, translationId: 2);
      expect(v.length, 36);
      expect(v.first.verse, 1);
    });

    test('chapter counts match the canon at the edges', () async {
      final counts = await db.getChapterCounts(translationId: 2);
      expect(counts['01'], 50); // Genesis
      expect(counts['19'], 150); // Psalms
      expect(counts['66'], 22); // Revelation
    });
  });

  group('search', () {
    test('사랑 finds what a substring scan finds', () async {
      final fts = await db.searchVerses('사랑', translationId: 2);
      expect(fts.length, greaterThan(400));
      expect(fts.every((v) => v.text.replaceAll(' ', '').contains('사랑')),
          isTrue);
    });

    test('English substring search finds "beloved" for "love"', () async {
      final rows = await db.searchVerses('love', translationId: 1);
      expect(rows.any((v) => v.text.toLowerCase().contains('beloved')), isTrue);
    });

    test('AND narrows, OR widens', () async {
      final a = await db.searchVersesAdvanced(
          keywords: ['사랑'], operators: const [], translationId: 2);
      final both = await db.searchVersesAdvanced(
          keywords: ['사랑', '믿음'], operators: ['AND'], translationId: 2);
      final either = await db.searchVersesAdvanced(
          keywords: ['사랑', '믿음'], operators: ['OR'], translationId: 2);
      expect(both.length, lessThan(a.length));
      expect(either.length, greaterThan(a.length));
      expect(both.length, greaterThan(0));
    });

    test('book filter restricts results', () async {
      final rows = await db.searchVersesAdvanced(
          keywords: ['사랑'],
          operators: const [],
          bookNums: ['43'],
          translationId: 2);
      expect(rows, isNotEmpty);
      expect(rows.every((v) => v.bookNum == '43'), isTrue);
    });

    test('a word that is not in the Bible returns nothing, no error', () async {
      final rows = await db.searchVerses('qzxqzx', translationId: 1);
      expect(rows, isEmpty);
    });

    test('quotes and FTS syntax characters in a query do not break it',
        () async {
      for (final q in ['"', '사랑"', '*', 'NEAR(', '사랑 OR', "it's"]) {
        await db.searchVerses(q, translationId: 2); // must not throw
      }
    });

    test('results come back in Bible order', () async {
      final rows = await db.searchVerses('사랑', translationId: 2);
      for (var i = 1; i < rows.length; i++) {
        final a = rows[i - 1], b = rows[i];
        final ka = [a.bookNum, a.chapter, a.verse];
        final kb = [b.bookNum, b.chapter, b.verse];
        final cmp = (ka[0] as String).compareTo(kb[0] as String) != 0
            ? (ka[0] as String).compareTo(kb[0] as String)
            : (ka[1] as int) != (kb[1] as int)
                ? (ka[1] as int).compareTo(kb[1] as int)
                : (ka[2] as int).compareTo(kb[2] as int);
        expect(cmp, lessThanOrEqualTo(0));
      }
    });
  });

  group('bookmarks', () {
    test('add, query, remove', () async {
      await db.addBookmark(43003016);
      expect(await db.isBookmarked(43003016), isTrue);
      expect(await db.bookmarkedAmong([43003016, 1001001]), {43003016});
      final list = await db.getBookmarks(translationId: 2);
      expect(list.map((v) => v.verseUid), contains(43003016));
      await db.removeBookmark(43003016);
      expect(await db.isBookmarked(43003016), isFalse);
    });

    test('import adds new verses, skips duplicates and nonexistent uids',
        () async {
      await db.addBookmark(1001001);
      // 1001001 exists already, 43003016 is new, 66099099 is not a verse.
      final added = await db.importBookmarks([1001001, 43003016, 66099099]);
      expect(added, 1);
      expect(await db.isBookmarked(43003016), isTrue);
      expect(await db.isBookmarked(66099099), isFalse);
      expect(await db.importBookmarks([1001001, 43003016]), 0);
      await db.removeBookmark(1001001);
      await db.removeBookmark(43003016);
    });

    test('adding twice keeps one row', () async {
      await db.addBookmark(1001001);
      await db.addBookmark(1001001);
      final list = await db.getBookmarks(translationId: 2);
      expect(list.where((v) => v.verseUid == 1001001).length, 1);
      await db.removeBookmark(1001001);
    });
  });
}
