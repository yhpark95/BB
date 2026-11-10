/// Verse model representing a Bible verse
class Verse {
  final int id;
  final int verseUid;
  final int translationId;
  final String bookNum;
  final int chapter;
  final int verse;
  final String text;

  Verse({
    required this.id,
    required this.verseUid,
    required this.translationId,
    required this.bookNum,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  factory Verse.fromMap(Map<String, dynamic> map) {
    return Verse(
      id: map['id'] as int,
      verseUid: map['verse_uid'] as int,
      translationId: map['translation_id'] as int,
      bookNum: map['book_num'] as String,
      chapter: map['chapter'] as int,
      verse: map['verse'] as int,
      text: map['text'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'verse_uid': verseUid,
      'translation_id': translationId,
      'book_num': bookNum,
      'chapter': chapter,
      'verse': verse,
      'text': text,
    };
  }
}
