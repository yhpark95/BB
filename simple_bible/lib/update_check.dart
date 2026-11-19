import 'update_check_stub.dart'
    if (dart.library.js_interop) 'update_check_web.dart' as impl;

/// Stamped by tools/build_web.sh. A plain `flutter run` or an Android build
/// is 'dev', which never asks to update.
const String kBuildStamp =
    String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// True when the running build differs from the latest one. A dev build, or a
/// failed check (null or empty), is never outdated.
bool isOutdated(String running, String? latest) {
  if (running == 'dev' || latest == null || latest.isEmpty) return false;
  return running != latest;
}

/// The latest version from the server's app-version.json, or null on failure.
Future<String?> fetchLatestVersion() => impl.fetchLatestVersion();

/// Clears the service worker and caches, then reloads.
Future<void> reloadFresh() => impl.reloadFresh();
