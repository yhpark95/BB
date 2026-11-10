import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyFontSize = 'font_size';
  static const String _keyBoldText = 'bold_text';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyLastVerseUid = 'last_verse_uid';
  static const String _keyLastBookNum = 'last_book_num';
  static const String _keyLastChapter = 'last_chapter';
  static const String _keySelectedTranslations = 'selected_translations';
  static const String _keyTranslationId = 'translation_id'; // legacy migration
  static const String _keyLineHeight = 'line_height';
  static const String _keyVerseGap = 'verse_gap';


  /// Reading font size bounds. Wide range so low-vision users can go large.
  static const double minFontSize = 16.0;
  static const double maxFontSize = 40.0;
  static const double defaultFontSize = 22.0;

  /// Line spacing inside a verse, as a multiple of the font size. Loose
  /// leading is easier to read but costs verses per screen, and the balance is
  /// personal — especially with two translations on screen at once.
  static const double minLineHeight = 1.1;
  static const double maxLineHeight = 2.0;
  static const double defaultLineHeight = 1.2;

  /// Blank space between one verse and the next, in logical pixels.
  static const double minVerseGap = 0.0;
  static const double maxVerseGap = 24.0;
  static const double defaultVerseGap = 4.0;

  SharedPreferences? _prefs;

  double _fontSize = defaultFontSize;
  bool _boldText = false;
  ThemeMode _themeMode = ThemeMode.system;
  int? _lastVerseUid;
  String? _lastBookNum;
  int? _lastChapter;
  double _lineHeight = defaultLineHeight;
  double _verseGap = defaultVerseGap;
  // Ordered list: first = primary, optional second = secondary. Max 2.
  List<int> _selectedTranslations = [2];

  double get fontSize => _fontSize;
  bool get boldText => _boldText;
  FontWeight get textWeight => _boldText ? FontWeight.w700 : FontWeight.w400;
  ThemeMode get themeMode => _themeMode;
  int? get lastVerseUid => _lastVerseUid;
  String? get lastBookNum => _lastBookNum;
  int? get lastChapter => _lastChapter;
  double get lineHeight => _lineHeight;
  double get verseGap => _verseGap;

  int get primaryTranslationId => _selectedTranslations.first;
  int? get secondaryTranslationId =>
      _selectedTranslations.length > 1 ? _selectedTranslations[1] : null;
  bool get isDualLanguage => _selectedTranslations.length > 1;
  List<int> get selectedTranslationIds => List.unmodifiable(_selectedTranslations);

  // Legacy compatibility
  int get translationId => primaryTranslationId;
  bool get useKorean => _selectedTranslations.contains(2);

  /// `BBCCCVVV` uid for a verse, as used throughout the Bible database.
  static int verseUidOf(String bookNum, int chapter, int verse) =>
      (int.tryParse(bookNum) ?? 0) * 1000000 + chapter * 1000 + verse;

  /// The verse to resume at, or null unless the saved verse belongs to the
  /// saved chapter.
  int? get lastVerseInLastChapter {
    final uid = _lastVerseUid;
    final book = _lastBookNum;
    final chapter = _lastChapter;
    if (uid == null || book == null || chapter == null) return null;
    final verse = uid - verseUidOf(book, chapter, 0);
    return (verse > 0 && verse < 1000) ? verse : null;
  }

  bool get hasLastPosition => _lastBookNum != null && _lastChapter != null;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _fontSize = (_prefs!.getDouble(_keyFontSize) ?? defaultFontSize)
        .clamp(minFontSize, maxFontSize);
    _boldText = _prefs!.getBool(_keyBoldText) ?? false;
    _lineHeight = (_prefs!.getDouble(_keyLineHeight) ?? defaultLineHeight)
        .clamp(minLineHeight, maxLineHeight);
    _verseGap = (_prefs!.getDouble(_keyVerseGap) ?? defaultVerseGap)
        .clamp(minVerseGap, maxVerseGap);

    final themeModeIndex = _prefs!.getInt(_keyThemeMode) ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];

    _lastVerseUid = _prefs!.getInt(_keyLastVerseUid);
    _lastBookNum = _prefs!.getString(_keyLastBookNum);
    _lastChapter = _prefs!.getInt(_keyLastChapter);

    final saved = _prefs!.getString(_keySelectedTranslations);
    if (saved != null && saved.isNotEmpty) {
      _selectedTranslations = saved.split(',').map(int.parse).toList();
    } else {
      // Migration from old single translation_id key
      final oldId = _prefs!.getInt(_keyTranslationId);
      _selectedTranslations = [oldId ?? 2];
    }
    _sortTranslations();

    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    final clamped = size.clamp(minFontSize, maxFontSize);
    if (clamped == _fontSize) return;
    _fontSize = clamped;
    await _prefs?.setDouble(_keyFontSize, clamped);
    notifyListeners();
  }

  /// Font size for a pinch in progress: repaint, but do not touch the disk.
  ///
  /// A pinch calls this on every pointer move — sixty times a second — and
  /// setFontSize writes to SharedPreferences each time. Persist once, when the
  /// fingers lift, via [commitFontSize].
  void previewFontSize(double size) {
    final clamped = size.clamp(minFontSize, maxFontSize);
    if (clamped == _fontSize) return;
    _fontSize = clamped;
    notifyListeners();
  }

  Future<void> commitFontSize() async {
    await _prefs?.setDouble(_keyFontSize, _fontSize);
  }

  /// Step the font size by one notch. Used by the large +/- buttons.
  Future<void> stepFontSize(double delta) => setFontSize(_fontSize + delta);

  Future<void> setBoldText(bool value) async {
    _boldText = value;
    await _prefs?.setBool(_keyBoldText, value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt(_keyThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setLineHeight(double value) async {
    final clamped = value.clamp(minLineHeight, maxLineHeight);
    if (clamped == _lineHeight) return;
    _lineHeight = clamped;
    await _prefs?.setDouble(_keyLineHeight, clamped);
    notifyListeners();
  }

  Future<void> stepLineHeight(double delta) => setLineHeight(_lineHeight + delta);

  Future<void> setVerseGap(double value) async {
    final clamped = value.clamp(minVerseGap, maxVerseGap);
    if (clamped == _verseGap) return;
    _verseGap = clamped;
    await _prefs?.setDouble(_keyVerseGap, clamped);
    notifyListeners();
  }

  Future<void> stepVerseGap(double delta) => setVerseGap(_verseGap + delta);


  Future<void> saveLastPosition({
    required String bookNum,
    required int chapter,
    int? verseUid,
  }) async {
    _lastBookNum = bookNum;
    _lastChapter = chapter;
    _lastVerseUid = verseUid;
    await _prefs?.setString(_keyLastBookNum, bookNum);
    await _prefs?.setInt(_keyLastChapter, chapter);
    // Always written, including null: a stale verse from the previous chapter
    // must not survive a chapter turn.
    if (verseUid != null) {
      await _prefs?.setInt(_keyLastVerseUid, verseUid);
    } else {
      await _prefs?.remove(_keyLastVerseUid);
    }
    // Position is written on every chapter turn; no notifyListeners() here so
    // the whole reader does not rebuild while the user is reading.
  }

  // KR(2) → EN(1) → FR(3) priority order
  static const _translationPriority = [2, 1, 3];
  void _sortTranslations() {
    _selectedTranslations.sort((a, b) =>
        _translationPriority.indexOf(a).compareTo(_translationPriority.indexOf(b)));
  }

  /// Toggle a translation on/off. Max 2 selected. Cannot deselect the last one.
  Future<void> toggleTranslation(int id) async {
    final current = List<int>.from(_selectedTranslations);
    if (current.contains(id)) {
      if (current.length == 1) return;
      current.remove(id);
    } else {
      if (current.length >= 2) current.removeLast();
      current.add(id);
    }
    _selectedTranslations = current;
    _sortTranslations();
    await _prefs?.setString(_keySelectedTranslations, _selectedTranslations.join(','));
    notifyListeners();
  }

  /// Make [id] the only selected translation. Used by the simple language picker.
  Future<void> setSingleTranslation(int id) async {
    if (_selectedTranslations.length == 1 && _selectedTranslations.first == id) {
      return;
    }
    _selectedTranslations = [id];
    await _prefs?.setString(_keySelectedTranslations, '$id');
    notifyListeners();
  }

  /// Ensure [id] is visible, without dropping what the user already reads.
  /// Used when a search result is opened in a language that is not shown.
  Future<void> ensureTranslationVisible(int id) async {
    if (_selectedTranslations.contains(id)) return;
    await toggleTranslation(id);
  }

  Future<void> clearLastPosition() async {
    _lastBookNum = null;
    _lastChapter = null;
    _lastVerseUid = null;
    await _prefs?.remove(_keyLastBookNum);
    await _prefs?.remove(_keyLastChapter);
    await _prefs?.remove(_keyLastVerseUid);
    notifyListeners();
  }
}
