import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../models/verse.dart';
import '../models/book.dart';
import '../widgets/reader_bar.dart';
import '../utils/korean_wrap.dart';
/// Complete snapshot of a search session — used to restore state exactly.
class SearchState {
  final List<String> keywords;
  final List<String> operators;
  final Set<String> selectedBookNums;
  final int translationId;
  final List<Verse> results;

  const SearchState({
    required this.keywords,
    required this.operators,
    required this.selectedBookNums,
    required this.translationId,
    required this.results,
  });
}

class SearchScreen extends StatefulWidget {
  /// Called with the chosen result. Always supplied by the reader — search
  /// never pushes a second reader on top of the one already running.
  final void Function(
      String bookNum, int chapter, int? highlightVerse, SearchState state) onSelect;

  /// Restore a complete previous search session on open.
  final SearchState? initialState;

  const SearchScreen({super.key, required this.onSelect, this.initialState});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();

  List<String> _keywords = [];
  List<String> _operators = []; // 'AND' | 'OR', length == _keywords.length - 1

  Set<String> _selectedBookNums = {};
  List<Verse> _results = [];
  Map<String, Book> _booksCache = {};
  List<Book> _allBooks = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _tooMany = false;
  int _searchTranslationId = 2; // independent per-search language
  bool _translationInitialized = false;

  late TabController _filterTabController;

  @override
  void initState() {
    super.initState();
    _filterTabController = TabController(length: 2, vsync: this);
    _loadBooks();
    final s = widget.initialState;
    if (s != null && s.keywords.isNotEmpty) {
      _keywords = List.from(s.keywords);
      _operators = List.from(s.operators);
      _selectedBookNums = Set.from(s.selectedBookNums);
      _searchTranslationId = s.translationId;
      _results = List.from(s.results);
      _hasSearched = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only initialize translation from settings on a fresh (non-restored) session.
    // Runs once. didChangeDependencies fires again whenever the keyboard opens
    // or the theme changes, and a value-based check (== 2) silently reset a
    // language the user had just picked.
    if (!_translationInitialized) {
      _translationInitialized = true;
      if (widget.initialState == null) {
        final settings = Provider.of<SettingsService>(context, listen: false);
        _searchTranslationId = settings.primaryTranslationId;
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _filterTabController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final books = await dbService.getAllBooks();
    if (!mounted) return;
    setState(() {
      _allBooks = books;
      _booksCache = {for (var b in books) b.bookNum: b};
    });
  }

  void _addKeyword() {
    final text = _inputController.text.trim();
    if (text.isEmpty || _keywords.contains(text)) return;
    setState(() {
      if (_keywords.isNotEmpty) _operators.add('AND');
      _keywords.add(text);
      _inputController.clear();
    });
    _performSearch();
  }

  void _removeKeyword(int index) {
    setState(() {
      _keywords.removeAt(index);
      if (_operators.isNotEmpty) {
        final opIndex = index == 0 ? 0 : index - 1;
        if (opIndex < _operators.length) _operators.removeAt(opIndex);
      }
    });
    if (_keywords.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
    } else {
      _performSearch();
    }
  }

  void _toggleOperator(int index) {
    setState(() {
      _operators[index] = _operators[index] == 'AND' ? 'OR' : 'AND';
    });
    _performSearch();
  }

  Future<void> _performSearch() async {
    if (_keywords.isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      List<Verse> results;
      if (_keywords.length == 1 && _selectedBookNums.isEmpty) {
        results = await dbService.searchVerses(
          _keywords[0],
          translationId: _searchTranslationId,
        );
      } else {
        results = await dbService.searchVersesAdvanced(
          keywords: _keywords,
          operators: _operators,
          bookNums: _selectedBookNums.isEmpty ? null : _selectedBookNums.toList(),
          translationId: _searchTranslationId,
        );
      }

      if (mounted) {
        setState(() {
          _results = results;
          _tooMany =
              results.length >= DatabaseService.searchAdviseNarrowing;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('검색 오류: $e')),
        );
      }
    }
  }

  /// The language the keywords look like they are written in, when that is not
  /// the language being searched: Hangul while searching English or French,
  /// Latin letters while searching Korean. Null when there is no mismatch.
  int? get _suggestedLanguage {
    if (_keywords.isEmpty) return null;
    if (_keywords.every(DatabaseService.isHangulOnly)) {
      return _searchTranslationId == 2 ? null : 2;
    }
    final latin = RegExp(r'^[A-Za-zÀ-ÿ\s\-]+$');
    if (_keywords.every(latin.hasMatch) && _searchTranslationId == 2) {
      // English is the likelier intent for a bare Latin word.
      return 1;
    }
    return null;
  }

  void _setSearchTranslation(int id) {
    if (_searchTranslationId == id) return;
    setState(() => _searchTranslationId = id);
    if (_keywords.isNotEmpty) _performSearch();
  }

  void _showBookFilterDialog() {
    final otBooks = _allBooks.where((b) => b.isOldTestament).toList();
    final ntBooks = _allBooks.where((b) => b.isNewTestament).toList();
    final localSelected = Set<String>.from(_selectedBookNums);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('찾을 범위',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      if (localSelected.isNotEmpty)
                        TextButton(
                          onPressed: () =>
                              setDialogState(() => localSelected.clear()),
                          child: const Text('전체'),
                        ),
                      // Not an X: this control keeps the choice and runs
                      // the search again, which is the opposite of what a
                      // close icon promises.
                      FilledButton(
                        onPressed: () {
                          setState(() =>
                              _selectedBookNums = Set.from(localSelected));
                          Navigator.pop(ctx);
                          if (_keywords.isNotEmpty) _performSearch();
                        },
                        child: const Text('확인',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _filterTabController,
                  tabs: const [Tab(text: '구약'), Tab(text: '신약')],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _filterTabController,
                    children: [
                      _buildFilterBookGrid(
                          otBooks, localSelected, setDialogState),
                      _buildFilterBookGrid(
                          ntBooks, localSelected, setDialogState),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBookGrid(
    List<Book> books,
    Set<String> localSelected,
    StateSetter setDialogState,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.2,
      ),
      itemCount: books.length,
      itemBuilder: (_, i) {
        final book = books[i];
        final selected = localSelected.contains(book.bookNum);
        return Material(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => setDialogState(() {
              selected
                  ? localSelected.remove(book.bookNum)
                  : localSelected.add(book.bookNum);
            }),
            borderRadius: BorderRadius.circular(10),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  book.nameFor(_readingTranslationId),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Books are named by the translation being read, not the one being
  /// searched. Searching in English used to list "Mark 3장 16절" and then open
  /// a page titled 마가복음 — the same place under two names. Which language
  /// the search runs in is a separate question from what the book is called.
  String _getReference(Verse verse) {
    final book = _booksCache[verse.bookNum];
    if (book == null) return '${verse.bookNum} ${verse.chapter}:${verse.verse}';
    final name = book.nameFor(_readingTranslationId);
    return '$name ${verse.chapter}장 ${verse.verse}절';
  }

  int get _readingTranslationId =>
      Provider.of<SettingsService>(context, listen: false)
          .primaryTranslationId;

  /// Builds a RichText widget with keywords bolded in the verse text.
  Widget _buildHighlightedText(String text, List<String> keywords,
      TextStyle? baseStyle) {
    text = joinKoreanWords(text);
    if (keywords.isEmpty) {
      return Text(text,
          style: baseStyle, maxLines: 3, overflow: TextOverflow.ellipsis);
    }
    final pattern = RegExp(
      keywords.map(keywordPatternForJoined).join('|'),
      caseSensitive: false,
    );
    final spans = <TextSpan>[];
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
    // Text.rich, not RichText: RichText ignores the inherited text style, so
    // the verse had no colour of its own and came out near-white on the light
    // card — the matched words were bold and everything else was unreadable.
    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Language picker for the search itself, spelled out rather than the old
  /// KR / EN / FR codes.
  void _showTranslationPicker() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('언어',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            for (final entry in kTranslationShortNames.entries)
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Icon(
                  entry.key == _searchTranslationId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 28,
                ),
                title: Text(entry.value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _setSearchTranslation(entry.key);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: searchAppBar(
        context,
        controller: _inputController,
        translationLabel: kTranslationShortNames[_searchTranslationId] ??
            '$_searchTranslationId',
        bookLabel: _selectedBookNums.isEmpty
            ? '전체'
            : '${_selectedBookNums.length}권',
        bookSelected: _selectedBookNums.isNotEmpty,
        // The word just searched moves up into a chip and the field empties.
        // Without a different hint that read as "nothing was searched"; this
        // says what the empty field is for now.
        hintText:
            _keywords.isEmpty ? '찾을 낱말을 넣으세요' : '낱말을 더 넣어 좁혀 보세요',
        onTranslationTap: _showTranslationPicker,
        onBookTap: _allBooks.isEmpty ? null : _showBookFilterDialog,
        onSubmit: _addKeyword,
        onClear: () {
          _inputController.clear();
          setState(() {});
        },
        onChanged: (_) => setState(() {}),
      ),
      body: Column(
        children: [
          if (_keywords.isNotEmpty)
            Container(
              // Full width: left to shrink-wrap, the bar was a grey box the
              // size of one chip, floating in the middle of the screen.
              width: double.infinity,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < _keywords.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => _toggleOperator(i - 1),
                            child: _operators[i - 1] == 'AND'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '그리고',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '또는',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onTertiary,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      InputChip(
                        label: Text(_keywords[i]),
                        onDeleted: () => _removeKeyword(i),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              ),
              // Words are joined with "그리고" by default, and tapping that
              // switches to "또는". Nothing said so; the pill looked like a
              // label. One plain line, only once there is something to join.
              if (_keywords.length >= 2)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _operators.contains('OR') && _operators.contains('AND')
                        ? "'그리고'는 둘 다, '또는'은 하나라도 (눌러서 변경)"
                        : _operators.contains('OR')
                            ? "하나라도 있는 구절을 찾아요 (누르면 '그리고')"
                            : "둘 다 있는 구절만 찾아요 (누르면 '또는')",
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ],
              ),
            ),

          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) return const Center(child: CircularProgressIndicator());

    if (_keywords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '예: 사랑',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasSearched && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text('찾지 못했어요',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('다른 낱말로 찾거나 범위를 넓혀 보세요',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
            if (_suggestedLanguage != null) ...[
              const SizedBox(height: 20),
              // The usual reason a word is not found is that it is in a
              // different language than the one being searched. Say so and
              // offer the fix, instead of leaving the language chip to be
              // noticed.
              FilledButton.tonalIcon(
                icon: const Icon(Icons.translate),
                label: Text(
                  '${kTranslationShortNames[_suggestedLanguage]}로 찾아보기',
                  style: const TextStyle(fontSize: 16),
                ),
                onPressed: () => _setSearchTranslation(_suggestedLanguage!),
              ),
            ],
          ],
        ),
      );
    }

    if (_results.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_results.length}개 찾았어요'
                '${_selectedBookNums.isNotEmpty ? ' · ${_selectedBookNums.length}권 안에서' : ''}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              // Every row is listed either way; this is advice, not a cap.
              if (_tooMany)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    '찾은 구절이 너무 많아요\n'
                    '낱말을 더 넣거나 범위를 좁혀 보세요',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final verse = _results[index];
              const baseStyle = TextStyle(fontSize: 16, height: 1.5);
              return Card(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: InkWell(
                  onTap: () => widget.onSelect(
                    verse.bookNum,
                    verse.chapter,
                    verse.verse,
                    SearchState(
                      keywords: List.from(_keywords),
                      operators: List.from(_operators),
                      selectedBookNums: Set.from(_selectedBookNums),
                      translationId: _searchTranslationId,
                      results: List.from(_results),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getReference(verse),
                          style: TextStyle(
                            fontSize: 17,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildHighlightedText(
                            verse.text, _keywords, baseStyle),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
