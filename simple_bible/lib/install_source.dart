import 'install_source_stub.dart'
    if (dart.library.js_interop) 'install_source_web.dart' as impl;

enum InstallPlatform { ios, android, other }

/// What the browser can tell us about installing the site as an app.
abstract class InstallSource {
  InstallPlatform get platform;

  /// Opened from the home screen, i.e. already installed.
  bool get installed;

  /// Chrome handed over its install prompt (Android). It only does that when
  /// the app is not installed yet, which makes it the reliable "not installed".
  bool get canPrompt;

  /// Shows the browser's own install dialog. True when the reader accepted.
  Future<bool> prompt();

  /// Fires when [canPrompt] or [installed] may have changed.
  Stream<void> get changes;
}

InstallSource createInstallSource() => impl.createInstallSource();
