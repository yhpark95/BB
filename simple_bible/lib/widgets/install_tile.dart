import 'dart:async';

import 'package:flutter/material.dart';

import '../install_source.dart';
import 'install_banner.dart';

/// "앱으로 설치하기" in the settings, for a reader who closed the bar or let it
/// stop. Not shown when there is nothing to install: already installed, a
/// desktop, the Android app, or Android before Chrome offers its prompt.
class InstallTile extends StatefulWidget {
  const InstallTile({super.key, this.source});

  /// Defaults to the browser's. Tests pass a fake.
  final InstallSource? source;

  @override
  State<InstallTile> createState() => _InstallTileState();
}

class _InstallTileState extends State<InstallTile> {
  late final InstallSource _source = widget.source ?? createInstallSource();
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _source.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _tap() async {
    if (_source.platform == InstallPlatform.android) {
      await _source.prompt();
      if (mounted) setState(() {});
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('홈 화면에 추가하기'),
        content: SingleChildScrollView(
          child:
              IosInstallSteps(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldOfferInstall(_source, dismissed: false)) {
      return const SizedBox.shrink();
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: const Icon(Icons.install_mobile, size: 26),
      title: const Text('앱으로 설치하기', style: TextStyle(fontSize: 16)),
      subtitle: const Text('홈 화면에 두고 앱처럼 열어요'),
      trailing: const Icon(Icons.chevron_right),
      onTap: _tap,
    );
  }
}
