/// Version shown in Settings.
///
/// Kept beside the code rather than read from the package at runtime so the
/// About screen cannot drift from the build the way a hardcoded string did —
/// the release checklist changes this line and pubspec.yaml together.
const String kAppVersion = '1.13.0 (30)';
