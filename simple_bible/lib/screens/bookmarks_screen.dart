import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../utils/bookmark_transfer.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../models/verse.dart';
import '../models/book.dart';
import '../utils/korean_wrap.dart';

class BookmarksScreen extends StatefulWidget {
  /// Called with the verse to open. Always supplied by the reader — bookmarks
  /// never push a second reader on top of the one already running.
  final void Function(String bookNum, int chapter, int? highlightVerse)
      onSelect;

  const BookmarksScreen({super.key, required this.onSelect});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  Map<String, Book> _booksCache = {};
  Future<List<Verse>>? _bookmarksFuture;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bookmarksFuture ??= _fetchBookmarks();
  }

  Future<List<Verse>> _fetchBookmarks() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final translationId =
        Provider.of<SettingsService>(context, listen: false).translationId;
    return dbService.getBookmarks(translationId: translationId);
  }

  void _reload() {
    // A block body, not an arrow: `() => x = f()` returns the assigned Future,
    // and setState rejects a callback that returns one. That assertion fired
    // on every delete in a debug build and aborted the rest of the handler.
    final future = _fetchBookmarks();
    setState(() {
      _bookmarksFuture = future;
    });
  }

  Future<void> _loadBooks() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final books = await dbService.getAllBooks();
    if (!mounted) return;
    setState(() {
      _booksCache = {for (var book in books) book.bookNum: book};
    });
  }

  String _getVerseReference(Verse verse) {
    final book = _booksCache[verse.bookNum];
    if (book == null) return '${verse.bookNum} ${verse.chapter}:${verse.verse}';
    final settings = Provider.of<SettingsService>(context, listen: false);
    final name = book.nameFor(settings.primaryTranslationId);
    return '$name ${verse.chapter}장 ${verse.verse}절';
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final tid = Provider.of<SettingsService>(context, listen: false)
        .primaryTranslationId;
    final verses = await db.getBookmarks(translationId: tid);
    if (verses.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('복사할 북마크가 없어요')));
      return;
    }
    final text = formatBookmarkExport([
      for (final v in verses)
        (uid: v.verseUid, reference: _getVerseReference(v)),
    ]);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(
        content: Text('북마크 ${verses.length}개를 복사했어요. '
            '메모나 카톡에 붙여 넣어 보관하세요')));
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final uids = parseBookmarkImport(data?.text ?? '');
    if (uids.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('붙여 넣을 북마크가 없어요. 먼저 복사해 두세요')));
      return;
    }
    final added = await db.importBookmarks(uids);
    _reload();
    messenger.showSnackBar(SnackBar(
        content: Text(added == 0
            ? '새로 추가된 북마크가 없어요 (이미 모두 있어요)'
            : '북마크 $added개를 가져왔어요')));
  }

  /// Deleting is one tap away, so it must be undoable.
  Future<void> _removeBookmark(Verse verse) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    await dbService.removeBookmark(verse.verseUid);
    debugPrint('[Bookmark] Removed verseUid=${verse.verseUid}');
    _reload();
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        // Material's own default. Six seconds of a bar covering the list
        // reads as the app being stuck.
        duration: const Duration(seconds: 4),
        content: Text('북마크를 지웠어요 · ${_getVerseReference(verse)}',
            style: const TextStyle(fontSize: 15)),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () async {
            await dbService.addBookmark(verse.verseUid);
            _reload();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('북마크',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            tooltip: '북마크 옮기기',
            onSelected: (v) => v == 'export' ? _export() : _import(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('북마크 복사하기')),
              PopupMenuItem(value: 'import', child: Text('복사한 북마크 가져오기')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Verse>>(
        future: _bookmarksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // The exception itself goes to the log, not to the reader: a
            // DatabaseException with its SQL in it means nothing to anyone
            // using this app, and looks like the phone is broken.
            debugPrint('[Bookmarks] load failed: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('북마크를 불러오지 못했어요',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도',
                        style: TextStyle(fontSize: 16)),
                    onPressed: _reload,
                  ),
                ],
              ),
            );
          }

          final bookmarks = snapshot.data ?? [];

          if (bookmarks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_border,
                      size: 72,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 20),
                    const Text('아직 저장한 구절이 없어요',
                        style: TextStyle(
                            fontSize: 19, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      '성경을 읽다가 구절을 누르면\n여기에 저장돼요',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: bookmarks.length,
                itemBuilder: (context, index) {
                  final verse = bookmarks[index];
                  final reference = _getVerseReference(verse);

                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: InkWell(
                      onTap: () => widget.onSelect(
                          verse.bookNum, verse.chapter, verse.verse),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bookmark,
                                  size: 22,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    reference,
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  iconSize: 26,
                                  color: Theme.of(context).colorScheme.error,
                                  onPressed: () => _removeBookmark(verse),
                                  tooltip: '북마크 지우기',
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                // Every other screen wraps Korean at word
                                // boundaries; without this the bookmark list
                                // alone broke words in half.
                                joinKoreanWords(verse.text),
                                style:
                                    const TextStyle(fontSize: 16, height: 1.5),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
