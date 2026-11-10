/// Moving bookmarks between phones as plain text, with no file picker or
/// extra permission: copy them out, paste them into a note or a chat, paste
/// them back in on the other device.
///
/// One verse per line: the 8-digit uid first, then a readable reference. The
/// uid is what is read back; the reference is only there so the text makes
/// sense to the person holding it.
library;

/// `01001001 창세기 1장 1절` for each entry.
String formatBookmarkExport(List<({int uid, String reference})> entries) {
  final buffer = StringBuffer();
  for (final e in entries) {
    buffer.writeln('${e.uid.toString().padLeft(8, '0')} ${e.reference}');
  }
  return buffer.toString().trimRight();
}

final RegExp _uidAtLineStart = RegExp(r'^\s*(\d{7,8})(?!\d)');

/// Uids found at the start of each line. Lines that do not begin with a
/// 7–8 digit number are ignored, so extra text around the list is harmless.
List<int> parseBookmarkImport(String text) {
  final uids = <int>[];
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final m = _uidAtLineStart.firstMatch(line);
    if (m == null) continue;
    final uid = int.parse(m.group(1)!);
    // Book 1–66, chapter 1–150, verse 1–176.
    final book = uid ~/ 1000000;
    final chapter = (uid ~/ 1000) % 1000;
    final verse = uid % 1000;
    if (book < 1 || book > 66) continue;
    if (chapter < 1 || chapter > 150) continue; // Psalms is the longest
    if (verse < 1 || verse > 176) continue; // Psalm 119 is the longest
    uids.add(uid);
  }
  return uids;
}
