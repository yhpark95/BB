import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import '../models/verse.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

/// Verse selection, bookmarking and copying, shared by the phone reader and
/// the fold-open / tablet reader.
///
/// These two screens used to carry near-identical copies of this logic, which
/// is how one of them ends up with a fix the other never gets. The host state
/// supplies the verses through the abstract getters below; everything a reader
/// does with a selection lives here.
mixin VerseSelectionMixin<T extends StatefulWidget> on State<T> {
  final Set<int> selectedVerses = {};

  /// verse_uid of every bookmarked verse on screen, so the reader can mark
  /// them. Refreshed whenever the chapter or the bookmarks change.
  final Set<int> bookmarkedUids = {};

  /// Where a range selection starts. Set by the first long-press.
  int? _anchorVerse;

  // ── supplied by the host state ────────────────────────────────────────────

  /// Verses of the chapter in the primary translation.
  List<Verse> get selectionPrimary;

  /// Same chapter in the second translation, or empty.
  List<Verse> get selectionSecondary;

  Book? get selectionBook;
  int get selectionChapter;

  // ── queries ──────────────────────────────────────────────────────────────

  bool get hasSelection => selectedVerses.isNotEmpty;

  bool isSelected(int verseNum) => selectedVerses.contains(verseNum);

  bool isBookmarkedVerse(Verse verse) => bookmarkedUids.contains(verse.verseUid);

  /// True when every selected verse is already bookmarked, which turns the
  /// bookmark button into a remove button.
  bool get allSelectedBookmarked {
    if (selectedVerses.isEmpty) return false;
    for (final num in selectedVerses) {
      final verse = _primaryVerse(num);
      if (verse == null || !bookmarkedUids.contains(verse.verseUid)) {
        return false;
      }
    }
    return true;
  }

  Verse? _primaryVerse(int verseNum) {
    for (final v in selectionPrimary) {
      if (v.verse == verseNum) return v;
    }
    return null;
  }

  // ── selection ────────────────────────────────────────────────────────────

  /// A plain tap selects or deselects the verse.
  ///
  /// Selection used to need a long-press so a stray tap while reading could not
  /// start it. That trade was wrong for this app: a hidden gesture is a feature
  /// most readers never find, and undoing an accidental selection is one more
  /// tap. A tap it is.
  void tapVerse(int verseNum) {
    // A verse is selected by tapping the text itself, with no button to press
    // and no sound; without a tick there is nothing to tell a reader it
    // registered except the colour.
    HapticFeedback.selectionClick();
    setState(() {
      _anchorVerse = verseNum;
      _toggle(verseNum);
    });
  }

  /// A long-press extends the selection to cover everything between the last
  /// tapped verse and this one, so a passage takes two touches rather than one
  /// per verse. With nothing selected yet it behaves like a tap.
  void longPressVerse(int verseNum) {
    HapticFeedback.selectionClick();
    final anchor = _anchorVerse;
    setState(() {
      if (anchor == null || anchor == verseNum || selectedVerses.isEmpty) {
        _anchorVerse = verseNum;
        _toggle(verseNum);
      } else {
        final from = anchor < verseNum ? anchor : verseNum;
        final to = anchor < verseNum ? verseNum : anchor;
        for (final v in selectionPrimary) {
          if (v.verse >= from && v.verse <= to) selectedVerses.add(v.verse);
        }
      }
    });
  }

  void _toggle(int verseNum) {
    if (!selectedVerses.remove(verseNum)) selectedVerses.add(verseNum);
    if (selectedVerses.isEmpty) _anchorVerse = null;
  }

  void clearSelection() {
    if (selectedVerses.isEmpty && _anchorVerse == null) return;
    setState(() {
      selectedVerses.clear();
      _anchorVerse = null;
    });
  }

  /// Drops the selection without a rebuild, for callers already inside a
  /// setState — chapter changes, for instance.
  void resetSelectionState() {
    selectedVerses.clear();
    _anchorVerse = null;
  }


  // ── bookmarks ────────────────────────────────────────────────────────────

  /// Reloads which of the verses on screen are bookmarked.
  Future<void> refreshBookmarks(DatabaseService db) async {
    final uids = [for (final v in selectionPrimary) v.verseUid];
    if (uids.isEmpty) {
      if (bookmarkedUids.isNotEmpty && mounted) {
        setState(bookmarkedUids.clear);
      }
      return;
    }
    try {
      final found = await db.bookmarkedAmong(uids);
      if (!mounted) return;
      setState(() {
        bookmarkedUids
          ..clear()
          ..addAll(found);
      });
    } catch (e) {
      // A bookmark marker is decoration; never let it break the reader.
      debugPrint('[Selection] refreshBookmarks failed: $e');
    }
  }

  /// Bookmarks the selection, or removes the bookmarks when every selected
  /// verse already has one.
  Future<void> toggleBookmarkSelected(DatabaseService db) async {
    final removing = allSelectedBookmarked;
    final verses = [
      for (final num in selectedVerses.toList()..sort())
        if (_primaryVerse(num) != null) _primaryVerse(num)!,
    ];
    if (verses.isEmpty) return;

    for (final verse in verses) {
      if (removing) {
        await db.removeBookmark(verse.verseUid);
      } else {
        await db.addBookmark(verse.verseUid);
      }
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      for (final verse in verses) {
        removing
            ? bookmarkedUids.remove(verse.verseUid)
            : bookmarkedUids.add(verse.verseUid);
      }
      resetSelectionState();
    });
    showSelectionMessage(removing
        ? '북마크 ${verses.length}개를 지웠어요'
        : '북마크 ${verses.length}개를 저장했어요');
  }

  // ── copy ─────────────────────────────────────────────────────────────────

  Future<void> copySelected(SettingsService settings) async {
    final buffer = StringBuffer();
    for (final num in selectedVerses.toList()..sort()) {
      final primary = _primaryVerse(num);
      if (primary == null) continue;

      if (settings.isDualLanguage) {
        final label = settings.selectedTranslationIds
            .map((id) => selectionBook?.nameFor(id) ?? '')
            .toSet()
            .join('/');
        buffer.writeln('$label $selectionChapter:$num');
        buffer.writeln(primary.text);
        for (final v in selectionSecondary) {
          if (v.verse == num && v.text != primary.text) buffer.writeln(v.text);
        }
      } else {
        final name = selectionBook?.nameFor(settings.primaryTranslationId) ?? '';
        buffer.writeln('$name $selectionChapter:$num - ${primary.text}');
      }
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (!mounted) return;
    // The selection stays: copying is often followed by bookmarking the same
    // verses, and re-selecting them was the cost of copying first.
    showSelectionMessage('구절을 복사했어요');
  }

  void showSelectionMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontSize: 15)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 56),
      ),
    );
  }
}
