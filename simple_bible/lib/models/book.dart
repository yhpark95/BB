class Book {
  final String bookNum;
  final String nameEn;
  final String nameKo;
  final String? nameFr;
  final String? abbrEn;
  final String? abbrKo;
  final String testament;
  final int displayOrder;

  Book({
    required this.bookNum,
    required this.nameEn,
    required this.nameKo,
    this.nameFr,
    this.abbrEn,
    this.abbrKo,
    required this.testament,
    required this.displayOrder,
  });

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      bookNum: map['book_num'] as String,
      nameEn: map['name_en'] as String,
      nameKo: map['name_ko'] as String,
      nameFr: map['name_fr'] as String?,
      abbrEn: map['abbr_en'] as String?,
      abbrKo: map['abbr_ko'] as String?,
      testament: map['testament'] as String,
      displayOrder: map['display_order'] as int,
    );
  }

  // Fallback French names — used when the DB name_fr column is absent/null.
  static const Map<String, String> _frFallback = {
    '01': 'Genèse',        '02': 'Exode',              '03': 'Lévitique',
    '04': 'Nombres',       '05': 'Deutéronome',         '06': 'Josué',
    '07': 'Juges',         '08': 'Ruth',                '09': '1 Samuel',
    '10': '2 Samuel',      '11': '1 Rois',              '12': '2 Rois',
    '13': '1 Chroniques',  '14': '2 Chroniques',        '15': 'Esdras',
    '16': 'Néhémie',       '17': 'Esther',              '18': 'Job',
    '19': 'Psaumes',       '20': 'Proverbes',           '21': 'Ecclésiaste',
    '22': 'Cantique des Cantiques', '23': 'Ésaïe',      '24': 'Jérémie',
    '25': 'Lamentations',  '26': 'Ézéchiel',            '27': 'Daniel',
    '28': 'Osée',          '29': 'Joël',                '30': 'Amos',
    '31': 'Abdias',        '32': 'Jonas',               '33': 'Michée',
    '34': 'Nahoum',        '35': 'Habacuc',             '36': 'Sophonie',
    '37': 'Aggée',         '38': 'Zacharie',            '39': 'Malachie',
    '40': 'Matthieu',      '41': 'Marc',                '42': 'Luc',
    '43': 'Jean',          '44': 'Actes',               '45': 'Romains',
    '46': '1 Corinthiens', '47': '2 Corinthiens',       '48': 'Galates',
    '49': 'Éphésiens',     '50': 'Philippiens',         '51': 'Colossiens',
    '52': '1 Thessaloniciens', '53': '2 Thessaloniciens', '54': '1 Timothée',
    '55': '2 Timothée',    '56': 'Tite',                '57': 'Philémon',
    '58': 'Hébreux',       '59': 'Jacques',             '60': '1 Pierre',
    '61': '2 Pierre',      '62': '1 Jean',              '63': '2 Jean',
    '64': '3 Jean',        '65': 'Jude',                '66': 'Apocalypse',
  };

  /// Returns the book name for the given translation ID.
  /// 1 = KJV (English), 2 = 개역한글 (Korean), 3 = LSG (French)
  String nameFor(int translationId) {
    if (translationId == 1) return nameEn;
    if (translationId == 3) return nameFr ?? _frFallback[bookNum] ?? nameEn;
    return nameKo;
  }

  /// Returns the abbreviation for the given translation ID, or null if unavailable.
  String? abbrFor(int translationId) {
    if (translationId == 1) return abbrEn;
    return abbrKo;
  }

  bool get isOldTestament => testament == 'OT';
  bool get isNewTestament => testament == 'NT';
}
