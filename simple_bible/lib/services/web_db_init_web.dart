import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// In the browser SQLite runs as WebAssembly in a shared worker, and the
/// database files are kept in IndexedDB. Needs sqlite3.wasm and
/// sqflite_sw.js next to index.html (made by
/// `dart run sqflite_common_ffi_web:setup`).
void initWebDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
