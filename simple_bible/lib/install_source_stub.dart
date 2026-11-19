import 'install_source.dart';

/// Not a browser: there is nothing to install.
InstallSource createInstallSource() => const _NoInstall();

class _NoInstall implements InstallSource {
  const _NoInstall();
  @override
  InstallPlatform get platform => InstallPlatform.other;
  @override
  bool get installed => false;
  @override
  bool get canPrompt => false;
  @override
  Future<bool> prompt() async => false;
  @override
  Stream<void> get changes => const Stream.empty();
}
