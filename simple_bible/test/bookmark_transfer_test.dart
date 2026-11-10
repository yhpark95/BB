import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/utils/bookmark_transfer.dart';

void main() {
  test('export puts an 8-digit uid first and a readable reference after', () {
    final text = formatBookmarkExport([
      (uid: 1001001, reference: '창세기 1장 1절'),
      (uid: 43003016, reference: '요한복음 3장 16절'),
    ]);
    expect(text, '01001001 창세기 1장 1절\n43003016 요한복음 3장 16절');
  });

  test('what is exported can be imported back', () {
    final text = formatBookmarkExport([
      (uid: 1001001, reference: '창세기 1장 1절'),
      (uid: 43003016, reference: '요한복음 3장 16절'),
    ]);
    expect(parseBookmarkImport(text), [1001001, 43003016]);
  });

  test('surrounding text and blank lines are ignored', () {
    const text = '내 북마크입니다\n\n01001001 창세기 1장 1절\r\n'
        '  43003016 요한복음 3장 16절\n감사합니다';
    expect(parseBookmarkImport(text), [1001001, 43003016]);
  });

  test('numbers that cannot be a verse are rejected', () {
    // book 0, book 99, chapter 0, verse 0
    const text = '00001001\n99001001\n01000001\n01001000\n12345678';
    expect(parseBookmarkImport(text), isEmpty);
  });

  test('longer digit runs are not read as a uid prefix', () {
    expect(parseBookmarkImport('010010011 x'), isEmpty);
  });

  test('empty input gives nothing', () {
    expect(parseBookmarkImport(''), isEmpty);
    expect(formatBookmarkExport([]), '');
  });
}
