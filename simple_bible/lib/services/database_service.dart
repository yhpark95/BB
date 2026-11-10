import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/verse.dart';
import '../models/book.dart';

/// Bible text and user data.
///
/// These live in two separate SQLite files on purpose:
///
///  * `bible.db` is shipped in assets and is **replaced wholesale** whenever the
///    bundled copy differs from the installed one. It is disposable.
///  * `user_data.db` is created on the device and never overwritten. Bookmarks
///    live here, so shipping a new Bible build cannot erase them.
///
/// Bookmarks used to live inside `bible.db`, which meant any update to the
/// Bible text deleted every bookmark the user had. Existing bookmarks are
/// migrated across once, on first run after this change.
class DatabaseService {
  /// Maximum rows any search returns. The UI tells the user when a result set
  /// hits this so a truncated list is never mistaken for the whole answer.
  /// Searches are not capped. The result list renders lazily, so a long
  /// result costs a bigger query and more memory, not a slower screen — and
  /// measured on the real database the biggest realistic query, 하나님, is
  /// 3,584 rows in 9ms and 600KB. A cap of 200 silently threw away most of a
  /// perfectly ordinary search for 사랑 (518 rows) while doing nothing about
  /// the queries that are actually pathological.
  ///
  /// Past this many results the screen stops pretending the list is useful and
  /// tells the reader to narrow the search instead. It still shows every row.
  static const int searchAdviseNarrowing = 2000;

  static Database? _database;
  static Database? _userDatabase;
  static Future<Database>? _databaseFuture;
  static Future<Database>? _userDatabaseFuture;

  /// Whether this device's SQLite has a usable FTS5 index. Probed once.
  /// Null until probed; false makes every search fall back to LIKE.
  static bool? _ftsAvailable;

  /// Bible text database (from assets).
  ///
  /// The in-flight Future is cached, not the finished Database: two callers
  /// arriving before the first open completes must share one initialization,
  /// otherwise the 34MB asset copy can run twice at once.
  Future<Database> get database {
    return _databaseFuture ??= _initDatabase().catchError((Object e) {
      _databaseFuture = null; // let a later call retry
      throw e;
    }).then((db) => _database = db);
  }

  /// User data database (bookmarks). Never shipped, never overwritten.
  Future<Database> get userDatabase {
    return _userDatabaseFuture ??= _initUserDatabase().catchError((Object e) {
      _userDatabaseFuture = null;
      throw e;
    }).then((db) => _userDatabase = db);
  }

  /// Initialize database from assets
  Future<Database> _initDatabase() async {
    try {
      debugPrint('[DB] Initializing database...');
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'bible.db');

      final assetData = await rootBundle.load('assets/bible.db');
      final assetSize = assetData.lengthInBytes;

      final file = File(path);
      final existingSize = await file.exists() ? await file.length() : 0;

      // Size alone misses an edit that keeps the byte count. The SQLite header
      // carries `PRAGMA user_version` (4 bytes, big-endian, offset 60), which
      // the build script stamps; comparing it needs no database open.
      final assetVersion = _headerUserVersion(
          assetData.buffer.asUint8List(assetData.offsetInBytes, assetSize));
      var installedVersion = 0;
      if (existingSize > 0) {
        final raf = await file.open();
        try {
          installedVersion = _headerUserVersion(await raf.read(100));
        } finally {
          await raf.close();
        }
      }

      if (existingSize != assetSize || installedVersion != assetVersion) {
        // Order matters: the installed copy is about to be replaced, and on an
        // install predating the split it is the only place old bookmarks
        // exist. Rescue them before the file is gone, not after.
        if (existingSize > 0) {
          await _rescueLegacyBookmarks(path);
        }
        debugPrint('[DB] Copying DB from assets (existing=$existingSize, asset=$assetSize)');
        try {
          await Directory(dirname(path)).create(recursive: true);
        } catch (_) {}
        final bytes = assetData.buffer.asUint8List(assetData.offsetInBytes, assetSize);
        await file.writeAsBytes(bytes, flush: true);
      }

      final db = await openDatabase(path, readOnly: false);
      debugPrint('[DB] Database opened at $path');
      // Covers the ordinary case where the file was not replaced and the old
      // table is still sitting there.
      await _importLegacyBookmarks(db);
      return db;
    } catch (e, stack) {
      debugPrint('[DB] Failed to initialize database: $e\n$stack');
      rethrow;
    }
  }

  static int _headerUserVersion(Uint8List bytes) {
    if (bytes.length < 64) return 0;
    return ByteData.sublistView(bytes).getUint32(60, Endian.big);
  }

  /// Reads the pre-split bookmarks out of the installed Bible file that is
  /// about to be overwritten.
  Future<void> _rescueLegacyBookmarks(String biblePath) async {
    Database? old;
    try {
      old = await openDatabase(biblePath, readOnly: true);
      await _importLegacyBookmarks(old);
    } catch (e) {
      debugPrint('[DB] Could not rescue legacy bookmarks: $e');
    } finally {
      await old?.close();
    }
  }

  Future<Database> _initUserDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'user_data.db');
    try {
      await Directory(dirname(path)).create(recursive: true);
    } catch (_) {}

    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bookmarks (
            verse_uid INTEGER PRIMARY KEY,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    debugPrint('[DB] User database opened at $path');
    return db;
  }

  /// Copies bookmarks out of the old in-Bible table into user_data.db, once.
  ///
  /// The marker in `meta` stops a later run from resurrecting bookmarks the
  /// user has since deleted — the shipped Bible file still carries the old
  /// table, so without the marker every launch would restore them.
  Future<void> _importLegacyBookmarks(Database bibleDb) async {
    final userDb = await userDatabase;
    final done = await userDb.query('meta',
        where: 'key = ?', whereArgs: ['bookmarks_imported'], limit: 1);
    if (done.isNotEmpty) return;

    try {
      final cols = await bibleDb.rawQuery('PRAGMA table_info(bookmarks)');
      if (cols.isNotEmpty) {
        final legacy = await bibleDb.rawQuery(
            'SELECT verse_uid, MIN(created_at) AS created_at '
            'FROM bookmarks GROUP BY verse_uid');
        if (legacy.isNotEmpty) {
          final batch = userDb.batch();
          for (final row in legacy) {
            batch.insert(
              'bookmarks',
              {
                'verse_uid': row['verse_uid'],
                'created_at': row['created_at'] ??
                    DateTime.now().toUtc().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          await batch.commit(noResult: true);
          debugPrint('[DB] Imported ${legacy.length} legacy bookmark(s)');
        }
      }
    } catch (e) {
      // A missing or malformed legacy table must never block startup.
      debugPrint('[DB] Legacy bookmark import skipped: $e');
    }

    await userDb.insert(
      'meta',
      {'key': 'bookmarks_imported', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all books
  Future<List<Book>> getAllBooks() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        orderBy: 'display_order ASC',
      );
      return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
    } catch (e, stack) {
      debugPrint('[DB] getAllBooks error: $e\n$stack');
      rethrow;
    }
  }

  /// Get books by testament
  Future<List<Book>> getBooksByTestament(String testament) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'books',
        where: 'testament = ?',
        whereArgs: [testament],
        orderBy: 'display_order ASC',
      );
      return List.generate(maps.length, (i) => Book.fromMap(maps[i]));
    } catch (e, stack) {
      debugPrint('[DB] getBooksByTestament error: $e\n$stack');
      rethrow;
    }
  }

  /// Get verses for a specific chapter
  Future<List<Verse>> getChapter({
    required String bookNum,
    required int chapter,
    int translationId = 1,
  }) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'verses',
        where: 'book_num = ? AND chapter = ? AND translation_id = ?',
        whereArgs: [bookNum, chapter, translationId],
        orderBy: 'verse ASC',
      );
      return List.generate(maps.length, (i) => Verse.fromMap(maps[i]));
    } catch (e, stack) {
      debugPrint('[DB] getChapter error (book=$bookNum ch=$chapter): $e\n$stack');
      rethrow;
    }
  }

  /// A chapter in the primary translation and, when one is chosen, the
  /// secondary — the load both readers do, in one place.
  Future<({List<Verse> primary, List<Verse> secondary})> getChapterPair({
    required String bookNum,
    required int chapter,
    required int primaryId,
    int? secondaryId,
  }) async {
    final primary = await getChapter(
        bookNum: bookNum, chapter: chapter, translationId: primaryId);
    final secondary = secondaryId == null
        ? <Verse>[]
        : await getChapter(
            bookNum: bookNum, chapter: chapter, translationId: secondaryId);
    return (primary: primary, secondary: secondary);
  }

  /// Get a specific verse by verse_uid
  Future<Verse?> getVerseByUid(int verseUid, {int translationId = 1}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'verses',
      where: 'verse_uid = ? AND translation_id = ?',
      whereArgs: [verseUid, translationId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Verse.fromMap(maps[0]);
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  /// True when every character of [word] is Hangul (spaces ignored).
  ///
  /// This decides whether the FTS5 index can be used. Korean attaches particles
  /// as suffixes, so a searched word is always at the *start* of the token that
  /// contains it — a prefix query therefore returns exactly what a substring
  /// LIKE returns. Measured against this database: 사랑 518/518, 하나님
  /// 3584/3584. English is different — "love" as a prefix query misses
  /// "beloved" (443 of 547 rows), so Latin-script searches keep using LIKE.
  static bool isHangulOnly(String word) {
    final trimmed = word.replaceAll(' ', '');
    if (trimmed.isEmpty) return false;
    for (final rune in trimmed.runes) {
      final isSyllable = rune >= 0xAC00 && rune <= 0xD7A3;
      final isJamo = rune >= 0x1100 && rune <= 0x11FF;
      final isCompatJamo = rune >= 0x3130 && rune <= 0x318F;
      if (!isSyllable && !isJamo && !isCompatJamo) return false;
    }
    return true;
  }

  /// Some Android builds ship a SQLite without FTS5. Probe once and remember;
  /// on failure every search quietly uses the LIKE path instead.
  Future<bool> _hasFts() async {
    final cached = _ftsAvailable;
    if (cached != null) return cached;
    try {
      final db = await database;
      await db.rawQuery(
          "SELECT rowid FROM fts_verses WHERE fts_verses MATCH ? LIMIT 1", ['a']);
      _ftsAvailable = true;
    } catch (e) {
      debugPrint('[DB] FTS5 unavailable, falling back to LIKE: $e');
      _ftsAvailable = false;
    }
    return _ftsAvailable!;
  }

  /// Builds an FTS5 MATCH expression for `(A AND B) OR (C AND D)`.
  /// FTS5's own operator precedence already binds AND tighter than OR, which is
  /// the same grouping the LIKE path builds by hand.
  static String buildFtsMatch(List<String> keywords, List<String> operators) {
    final buffer = StringBuffer();
    for (int i = 0; i < keywords.length; i++) {
      if (i > 0) buffer.write(operators[i - 1] == 'OR' ? ' OR ' : ' AND ');
      // Quote the term so punctuation can never be read as FTS syntax, then
      // apply the prefix operator outside the quotes.
      buffer.write('"${keywords[i].replaceAll('"', '""')}"*');
    }
    return buffer.toString();
  }

  /// Search verses for a single keyword.
  Future<List<Verse>> searchVerses(String query, {int translationId = 1}) {
    return searchVersesAdvanced(
      keywords: [query],
      operators: const [],
      translationId: translationId,
    );
  }

  /// Advanced search with AND > OR precedence.
  /// Splits keywords into OR-separated groups, each group AND-ed internally.
  /// e.g. [A] AND [B] OR [C] AND [D] → (A AND B) OR (C AND D)
  Future<List<Verse>> searchVersesAdvanced({
    required List<String> keywords,
    required List<String> operators,
    List<String>? bookNums,
    int translationId = 1,
  }) async {
    if (keywords.isEmpty) return [];
    if (operators.length != keywords.length - 1) {
      throw ArgumentError(
          'operators.length must be keywords.length - 1 '
          '(got ${operators.length} vs ${keywords.length})');
    }

    if (keywords.every(isHangulOnly) && await _hasFts()) {
      try {
        return await _searchWithFts(
          keywords: keywords,
          operators: operators,
          bookNums: bookNums,
          translationId: translationId,
        );
      } catch (e, stack) {
        // Never fail a search because the index misbehaved — the LIKE path
        // below returns the same rows, only slower.
        debugPrint('[DB] FTS search failed, using LIKE: $e\n$stack');
        _ftsAvailable = false;
      }
    }

    return _searchWithLike(
      keywords: keywords,
      operators: operators,
      bookNums: bookNums,
      translationId: translationId,
    );
  }

  Future<List<Verse>> _searchWithFts({
    required List<String> keywords,
    required List<String> operators,
    List<String>? bookNums,
    required int translationId,
  }) async {
    final db = await database;
    final args = <dynamic>[buildFtsMatch(keywords, operators), translationId];

    var sql = '''
      SELECT v.* FROM fts_verses f
      JOIN verses v ON v.id = f.rowid
      WHERE f.fts_verses MATCH ? AND v.translation_id = ?
    ''';

    if (bookNums != null && bookNums.isNotEmpty) {
      final placeholders = bookNums.map((_) => '?').join(', ');
      sql += ' AND v.book_num IN ($placeholders)';
      args.addAll(bookNums);
    }

    sql += ' ORDER BY v.book_num, v.chapter, v.verse';

    final maps = await db.rawQuery(sql, args);
    return List.generate(maps.length, (i) => Verse.fromMap(maps[i]));
  }

  Future<List<Verse>> _searchWithLike({
    required List<String> keywords,
    required List<String> operators,
    List<String>? bookNums,
    required int translationId,
  }) async {
    try {
      final db = await database;
      final args = <dynamic>[];

      // Split into OR-groups; each group is AND-ed internally
      final groups = <List<String>>[];
      var current = <String>[keywords[0]];
      for (int i = 0; i < operators.length; i++) {
        if (operators[i] == 'OR') {
          groups.add(current);
          current = [keywords[i + 1]];
        } else {
          current.add(keywords[i + 1]);
        }
      }
      groups.add(current);

      // Build (A AND B) OR (C AND D) ...
      final groupClauses = groups.map((group) {
        final andParts = group.map((k) {
          args.add('%$k%');
          return 'text LIKE ?';
        }).join(' AND ');
        return group.length > 1 ? '($andParts)' : andParts;
      }).join(' OR ');

      var sql = 'SELECT * FROM verses WHERE ($groupClauses) AND translation_id = ?';
      args.add(translationId);

      if (bookNums != null && bookNums.isNotEmpty) {
        final placeholders = bookNums.map((_) => '?').join(', ');
        sql += ' AND book_num IN ($placeholders)';
        args.addAll(bookNums);
      }

      sql += ' ORDER BY book_num, chapter, verse';

      final maps = await db.rawQuery(sql, args);
      return List.generate(maps.length, (i) => Verse.fromMap(maps[i]));
    } catch (e, stack) {
      debugPrint('[DB] searchVersesAdvanced error: $e\n$stack');
      rethrow;
    }
  }

  // ── Bookmarks (user_data.db) ───────────────────────────────────────────────

  /// Bookmarked verses, newest first, rendered in the given translation.
  ///
  /// The uids come from the user database and the text from the Bible database,
  /// so this is two queries rather than a join — bookmark counts are small and
  /// the two files must stay independent.
  Future<List<Verse>> getBookmarks({int translationId = 1}) async {
    try {
      final userDb = await userDatabase;
      final rows = await userDb.query('bookmarks', orderBy: 'created_at DESC');
      if (rows.isEmpty) return [];

      final uids = rows.map((r) => r['verse_uid'] as int).toList();
      final db = await database;
      final placeholders = uids.map((_) => '?').join(', ');
      final maps = await db.rawQuery(
        'SELECT * FROM verses '
        'WHERE verse_uid IN ($placeholders) AND translation_id = ?',
        [...uids, translationId],
      );

      final byUid = {
        for (final m in maps) m['verse_uid'] as int: Verse.fromMap(m)
      };
      // Preserve the newest-first order of the user database.
      return [
        for (final uid in uids)
          if (byUid.containsKey(uid)) byUid[uid]!
      ];
    } catch (e, stack) {
      debugPrint('[DB] getBookmarks error: $e\n$stack');
      rethrow;
    }
  }

  /// Add bookmark (translation-agnostic)
  Future<void> addBookmark(int verseUid) async {
    try {
      final userDb = await userDatabase;
      await userDb.insert(
        'bookmarks',
        {
          'verse_uid': verseUid,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      debugPrint('[DB] addBookmark verseUid=$verseUid');
    } catch (e, stack) {
      debugPrint('[DB] addBookmark error: $e\n$stack');
      rethrow;
    }
  }

  /// Every bookmarked verse uid, newest first. For export.
  Future<List<int>> allBookmarkUids() async {
    final userDb = await userDatabase;
    final rows = await userDb.query('bookmarks',
        columns: ['verse_uid'], orderBy: 'created_at DESC');
    return [for (final r in rows) r['verse_uid'] as int];
  }

  /// Adds bookmarks from an import and returns how many were new.
  ///
  /// Uids that are not a verse in the Bible database are dropped, so pasted
  /// text can never plant a bookmark that points nowhere.
  Future<int> importBookmarks(Iterable<int> uids) async {
    final wanted = uids.toSet().toList();
    if (wanted.isEmpty) return 0;
    final db = await database;
    final placeholders = wanted.map((_) => '?').join(', ');
    final rows = await db.rawQuery(
      'SELECT DISTINCT verse_uid FROM verses WHERE verse_uid IN ($placeholders)',
      wanted,
    );
    final valid = [for (final r in rows) r['verse_uid'] as int];
    if (valid.isEmpty) return 0;

    final userDb = await userDatabase;
    final before = await allBookmarkUids();
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = userDb.batch();
    for (final uid in valid) {
      batch.insert(
        'bookmarks',
        {'verse_uid': uid, 'created_at': now},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
    final after = await allBookmarkUids();
    return after.length - before.length;
  }

  /// Remove bookmark
  Future<void> removeBookmark(int verseUid) async {
    final userDb = await userDatabase;
    await userDb.delete(
      'bookmarks',
      where: 'verse_uid = ?',
      whereArgs: [verseUid],
    );
  }

  /// Which of [verseUids] are bookmarked.
  ///
  /// The reader needs this for a whole chapter at once so it can mark the
  /// bookmarked verses; one isBookmarked call per verse would be 176 queries
  /// on Psalm 119.
  Future<Set<int>> bookmarkedAmong(List<int> verseUids) async {
    if (verseUids.isEmpty) return {};
    final userDb = await userDatabase;
    final placeholders = verseUids.map((_) => '?').join(', ');
    final rows = await userDb.rawQuery(
      'SELECT verse_uid FROM bookmarks WHERE verse_uid IN ($placeholders)',
      verseUids,
    );
    return {for (final r in rows) r['verse_uid'] as int};
  }

  /// Check if verse is bookmarked
  Future<bool> isBookmarked(int verseUid) async {
    final userDb = await userDatabase;
    final maps = await userDb.query(
      'bookmarks',
      where: 'verse_uid = ?',
      whereArgs: [verseUid],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  /// Get total number of chapters in a book
  Future<int> getChapterCount(String bookNum, {int translationId = 1}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT MAX(chapter) as max_chapter
      FROM verses
      WHERE book_num = ? AND translation_id = ?
    ''', [bookNum, translationId]);
    return result.first['max_chapter'] as int? ?? 0;
  }

  /// Chapter count for every book, in one query.
  ///
  /// The book list shows each book's length beside its name; asking per book
  /// would be 66 round trips to open one dialog.
  Future<Map<String, int>> getChapterCounts({int translationId = 1}) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT book_num, MAX(chapter) AS max_chapter FROM verses '
      'WHERE translation_id = ? GROUP BY book_num',
      [translationId],
    );
    return {
      for (final r in rows)
        r['book_num'] as String: (r['max_chapter'] as int?) ?? 0,
    };
  }

  /// Close both databases
  Future<void> close() async {
    final db = _database;
    _databaseFuture = null;
    if (db != null) {
      await db.close();
      _database = null;
    }
    final userDb = _userDatabase;
    _userDatabaseFuture = null;
    if (userDb != null) {
      await userDb.close();
      _userDatabase = null;
    }
  }
}
