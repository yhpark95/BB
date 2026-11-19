import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:simple_bible/services/database_service.dart';

void main() {
  test('the web stamp matches the bundled Bible', () {
    // The browser decides whether to re-download the Bible by this number.
    // Change assets/bible.db and this fails until the stamp is updated.
    expect(DatabaseService.webBibleStamp,
        File('assets/bible.db').lengthSync());
  });
}
