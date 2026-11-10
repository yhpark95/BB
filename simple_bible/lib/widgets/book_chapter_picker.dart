import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import 'chapter_picker.dart';

/// Book and chapter picker. Two steps: pick the book, then the chapter.
///
/// The book step is a list, not a grid. Three columns split a 320dp dialog into
/// 61dp of text per cell, which cut 데살로니가전서 and every English and French
/// name longer than a word — and the abbreviation fallback meant to rescue them
/// could not, because the abbreviation columns are empty for all 66 books. One
/// book per row fits the longest name on the narrowest phone with room left for
/// its chapter count.
class BookChapterPicker extends StatefulWidget {
  /// Called with the chosen book + chapter. Always supplied by the reader.
  final void Function(String bookNum, int chapter) onSelected;
  final Book? initialBook;

  /// Marked in the chapter grid when the reader stays in the current book.
  final int? currentChapter;

  const BookChapterPicker({
    super.key,
    required this.onSelected,
    this.initialBook,
    this.currentChapter,
  });

  @override
  State<BookChapterPicker> createState() => _BookChapterPickerState();
}

class _BookChapterPickerState extends State<BookChapterPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Book? _selectedBook;
  Map<String, int> _chapterCounts = {};

  @override
  void initState() {
    super.initState();
    // Open on the testament the reader is already in.
    final startOnNewTestament = widget.initialBook?.isNewTestament ?? false;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: startOnNewTestament ? 1 : 0,
    );
    _loadChapterCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChapterCounts() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final settings = Provider.of<SettingsService>(context, listen: false);
    try {
      final counts = await db.getChapterCounts(
          translationId: settings.primaryTranslationId);
      if (!mounted) return;
      setState(() => _chapterCounts = counts);
    } catch (e) {
      // The counts are a nicety beside each name; never block the picker.
      debugPrint('[Picker] chapter counts unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context, listen: false);
    final translationId = settings.primaryTranslationId;

    if (_selectedBook != null) {
      final book = _selectedBook!;
      // Back belongs to the step, not the dialog: from the chapter grid it
      // should return to the book list, the same as the 책 목록 button.
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() => _selectedBook = null);
        },
        child: ChapterPicker(
        bookLabel: book.nameFor(translationId),
        chapterCount: _chapterCounts[book.bookNum] ?? 1,
        // Only the book being read has a "current" chapter.
        currentChapter: book.bookNum == widget.initialBook?.bookNum
            ? widget.currentChapter
            : null,
        onBack: () => setState(() => _selectedBook = null),
          onSelected: (chapter) {
            Navigator.pop(context);
            widget.onSelected(book.bookNum, chapter);
          },
        ),
      );
    }

    return Column(
      children: [
        const PickerHeader(title: '성경'),
        TabBar(
          controller: _tabController,
          labelStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          tabs: const [Tab(text: '구약'), Tab(text: '신약')],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _BookList(
                testament: 'OT',
                translationId: translationId,
                chapterCounts: _chapterCounts,
                currentBookNum: widget.initialBook?.bookNum,
                onSelected: (book) => setState(() => _selectedBook = book),
              ),
              _BookList(
                testament: 'NT',
                translationId: translationId,
                chapterCounts: _chapterCounts,
                currentBookNum: widget.initialBook?.bookNum,
                onSelected: (book) => setState(() => _selectedBook = book),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BookList extends StatefulWidget {
  final String testament;
  final int translationId;
  final Map<String, int> chapterCounts;
  final String? currentBookNum;
  final void Function(Book book) onSelected;

  const _BookList({
    required this.testament,
    required this.translationId,
    required this.chapterCounts,
    required this.currentBookNum,
    required this.onSelected,
  });

  @override
  State<_BookList> createState() => _BookListState();
}

class _BookListState extends State<_BookList> {
  static const double _rowExtent = 60;
  final ScrollController _controller = ScrollController();
  bool _scrolled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Brings the book being read into view. Revelation is 27 rows down the New
  /// Testament list; starting at Matthew every time is a scroll the reader
  /// never asked for.
  void _scrollToCurrent(List<Book> books) {
    if (_scrolled || widget.currentBookNum == null) return;
    final index = books.indexWhere((b) => b.bookNum == widget.currentBookNum);
    if (index < 0) return;
    _scrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final target = (index - 1) * _rowExtent;
      _controller
          .jumpTo(target.clamp(0.0, _controller.position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Book>>(
      future: db.getBooksByTestament(widget.testament),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('책 목록을 불러오지 못했어요\n${snapshot.error}',
              textAlign: TextAlign.center));
        }

        final books = snapshot.data ?? [];
        _scrollToCurrent(books);

        return ListView.separated(
          controller: _controller,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: books.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            thickness: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          itemBuilder: (context, index) {
            final book = books[index];
            final isCurrent = book.bookNum == widget.currentBookNum;
            final count = widget.chapterCounts[book.bookNum];

            return Material(
              color: isCurrent ? scheme.primaryContainer : null,
              child: InkWell(
                onTap: () => widget.onSelected(book),
                child: Container(
                  constraints: const BoxConstraints(minHeight: _rowExtent - 1),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      if (isCurrent) ...[
                        Icon(Icons.play_arrow,
                            size: 20, color: scheme.primary),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          book.nameFor(widget.translationId),
                          // A whole row per book, so the longest name fits at
                          // full size — no ellipsis, no shrinking.
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight:
                                isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? scheme.primary : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (count != null)
                        Text(
                          '$count장',
                          style: TextStyle(
                            fontSize: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
