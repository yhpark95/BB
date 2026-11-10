import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simple_bible/models/book.dart';
import 'package:simple_bible/models/verse.dart';
import 'package:simple_bible/services/database_service.dart';
import 'package:simple_bible/services/settings_service.dart';
import 'package:simple_bible/widgets/verse_selection.dart';

/// Verse selection is shared by the phone reader and the fold-open reader, so
/// it is tested once, here, against the mixin itself.

Verse _verse(int n) => Verse(
      id: n,
      verseUid: 1000 + n,
      translationId: 2,
      bookNum: '43',
      chapter: 3,
      verse: n,
      text: '$n절 본문',
    );

final Book _book = Book(
  bookNum: '43',
  nameEn: 'John',
  nameKo: '요한복음',
  testament: 'NT',
  displayOrder: 43,
);

/// Records what the mixin asks of the database without touching sqflite.
class _FakeDb extends DatabaseService {
  final Set<int> stored;
  _FakeDb([Set<int>? initial]) : stored = {...?initial};

  @override
  Future<Set<int>> bookmarkedAmong(List<int> uids) async =>
      stored.intersection(uids.toSet());

  @override
  Future<void> addBookmark(int verseUid) async {
    stored.add(verseUid);
  }

  @override
  Future<void> removeBookmark(int verseUid) async {
    stored.remove(verseUid);
  }
}

class _Host extends StatefulWidget {
  final List<Verse> verses;
  final List<Verse> secondary;
  const _Host({super.key, required this.verses, this.secondary = const []});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with VerseSelectionMixin {
  @override
  List<Verse> get selectionPrimary => widget.verses;
  @override
  List<Verse> get selectionSecondary => widget.secondary;
  @override
  Book? get selectionBook => _book;
  @override
  int get selectionChapter => 3;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final verses = [for (int i = 1; i <= 20; i++) _verse(i)];

  /// Mounts the host and returns its state.
  Future<_HostState> mount(WidgetTester tester,
      {List<Verse>? secondary}) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();
    await settings.initialize();
    final key = GlobalKey<_HostState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsService>.value(
        value: settings,
        child: MaterialApp(
          home: Scaffold(
            body: _Host(
                key: key, verses: verses, secondary: secondary ?? const []),
          ),
        ),
      ),
    );
    return key.currentState!;
  }

  group('selecting', () {
    testWidgets('a long-press with nothing selected behaves like a tap',
        (tester) async {
      final s = await mount(tester);
      expect(s.hasSelection, isFalse);
      s.longPressVerse(5);
      expect(s.selectedVerses, {5});
    });

    testWidgets('a plain tap selects, with nothing selected yet',
        (tester) async {
      final s = await mount(tester);
      // Selection used to need a long-press. A hidden gesture is one most
      // readers never find, so a tap starts it now.
      s.tapVerse(5);
      expect(s.selectedVerses, {5});

      s.tapVerse(7);
      expect(s.selectedVerses, {5, 7});
    });

    testWidgets('a long-press after a tap takes the whole range',
        (tester) async {
      final s = await mount(tester);
      s.tapVerse(3);
      s.longPressVerse(9);
      // Two touches instead of seven.
      expect(s.selectedVerses, {3, 4, 5, 6, 7, 8, 9});
    });

    testWidgets('two long-presses do the same', (tester) async {
      final s = await mount(tester);
      s.longPressVerse(3);
      s.longPressVerse(9);
      expect(s.selectedVerses, {3, 4, 5, 6, 7, 8, 9});
    });

    testWidgets('the range works backwards too', (tester) async {
      final s = await mount(tester);
      s.longPressVerse(9);
      s.longPressVerse(6);
      expect(s.selectedVerses, {6, 7, 8, 9});
    });

    testWidgets('a range never invents verses the chapter does not have',
        (tester) async {
      final s = await mount(tester);
      s.longPressVerse(18);
      s.longPressVerse(20);
      expect(s.selectedVerses, {18, 19, 20});
    });

    testWidgets('a tap deselects, and the last one ends selection mode',
        (tester) async {
      final s = await mount(tester);
      s.tapVerse(5);
      s.tapVerse(6);
      s.tapVerse(6);
      expect(s.selectedVerses, {5});
      s.tapVerse(5);
      expect(s.hasSelection, isFalse);
    });

    testWidgets('long-pressing after clearing starts over, not a range',
        (tester) async {
      final s = await mount(tester);
      s.longPressVerse(3);
      s.clearSelection();
      s.longPressVerse(9);
      expect(s.selectedVerses, {9});
    });

  });

  group('bookmarking', () {
    testWidgets('marks are loaded for the whole chapter at once',
        (tester) async {
      final db = _FakeDb({1002, 1004});
      final s = await mount(tester);
      await s.refreshBookmarks(db);
      expect(s.isBookmarkedVerse(_verse(2)), isTrue);
      expect(s.isBookmarkedVerse(_verse(3)), isFalse);
    });

    testWidgets('the selection is bookmarked and then cleared',
        (tester) async {
      final db = _FakeDb();
      final s = await mount(tester);
      s.longPressVerse(2);
      s.longPressVerse(4);
      await s.toggleBookmarkSelected(db);

      expect(db.stored, {1002, 1003, 1004});
      expect(s.hasSelection, isFalse);
      expect(s.isBookmarkedVerse(_verse(3)), isTrue);
    });

    testWidgets('an all-bookmarked selection removes instead of adding',
        (tester) async {
      final db = _FakeDb({1002, 1003});
      final s = await mount(tester);
      await s.refreshBookmarks(db);

      s.longPressVerse(2);
      s.longPressVerse(3);
      expect(s.allSelectedBookmarked, isTrue);

      await s.toggleBookmarkSelected(db);
      expect(db.stored, isEmpty);
    });

    testWidgets('a partly bookmarked selection adds the missing ones',
        (tester) async {
      final db = _FakeDb({1002});
      final s = await mount(tester);
      await s.refreshBookmarks(db);

      s.longPressVerse(2);
      s.tapVerse(3);
      expect(s.allSelectedBookmarked, isFalse);

      await s.toggleBookmarkSelected(db);
      expect(db.stored, {1002, 1003});
    });
  });

  group('copying', () {
    late List<MethodCall> clipboard;

    setUp(() {
      clipboard = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard.add(call);
        return null;
      });
    });

    testWidgets('copies the selection in verse order, not tap order',
        (tester) async {
      final s = await mount(tester);
      s.longPressVerse(7);
      s.tapVerse(2);
      await s
          .copySelected(Provider.of<SettingsService>(s.context, listen: false));

      final text = clipboard.single.arguments['text'] as String;
      expect(text, '요한복음 3:2 - 2절 본문\n\n요한복음 3:7 - 7절 본문');
      expect(s.hasSelection, isFalse);
    });

    testWidgets('a dual-language copy carries both translations',
        (tester) async {
      final second = [
        Verse(
            id: 900,
            verseUid: 1002,
            translationId: 1,
            bookNum: '43',
            chapter: 3,
            verse: 2,
            text: 'verse two'),
      ];
      final s = await mount(tester, secondary: second);
      final settings = Provider.of<SettingsService>(s.context, listen: false);
      await settings.toggleTranslation(1);
      expect(settings.isDualLanguage, isTrue);

      s.longPressVerse(2);
      await s.copySelected(settings);

      final text = clipboard.single.arguments['text'] as String;
      expect(text, contains('2절 본문'));
      expect(text, contains('verse two'));
    });
  });
}
