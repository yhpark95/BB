import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<String?> fetchLatestVersion() async {
  try {
    final url = 'app-version.json?t=${DateTime.now().millisecondsSinceEpoch}';
    final res =
        await web.window.fetch(url.toJS, web.RequestInit(cache: 'no-store')).toDart;
    if (!res.ok) return null;
    final text = (await res.text().toDart).toDart;
    final v = (jsonDecode(text) as Map)['v'];
    return v is String ? v : null;
  } catch (_) {
    return null;
  }
}

/// Drops the service worker and its cache so the reload fetches the new build.
/// The Bible and the bookmarks live in IndexedDB, which this leaves alone.
Future<void> reloadFresh() async {
  try {
    final regs =
        (await web.window.navigator.serviceWorker.getRegistrations().toDart).toDart;
    for (final r in regs) {
      await r.unregister().toDart;
    }
    final keys = (await web.window.caches.keys().toDart).toDart;
    for (final k in keys) {
      await web.window.caches.delete(k.toDart).toDart;
    }
  } catch (_) {}
  web.window.location.reload();
}
