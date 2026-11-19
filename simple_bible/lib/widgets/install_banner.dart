import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../install_source.dart';

/// Whether to offer installing. Never when it is already installed, never on
/// a desktop or in the Android app, never after the reader closed it, and on
/// Android only once Chrome has handed over its prompt (it does that only for
/// a site that is not installed yet).
bool shouldOfferInstall(InstallSource s, {required bool dismissed}) {
  if (dismissed || s.installed) return false;
  switch (s.platform) {
    case InstallPlatform.ios:
      return true;
    case InstallPlatform.android:
      return s.canPrompt;
    case InstallPlatform.other:
      return false;
  }
}

const _dismissedKey = 'install_hint_dismissed';

Future<bool> _loadDismissed() async {
  try {
    return (await SharedPreferences.getInstance()).getBool(_dismissedKey) ??
        false;
  } catch (_) {
    return false;
  }
}

Future<void> _saveDismissed() async {
  try {
    await (await SharedPreferences.getInstance()).setBool(_dismissedKey, true);
  } catch (_) {}
}

/// A thin bar saying how to put the site on the home screen like an app.
class InstallBanner extends StatefulWidget {
  const InstallBanner({
    super.key,
    this.source,
    this.loadDismissed = _loadDismissed,
    this.saveDismissed = _saveDismissed,
  });

  /// Defaults to the browser's. Tests pass a fake.
  final InstallSource? source;
  final Future<bool> Function() loadDismissed;
  final Future<void> Function() saveDismissed;

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  late final InstallSource _source = widget.source ?? createInstallSource();
  StreamSubscription<void>? _sub;
  bool _dismissed = true; // hidden until the saved choice is known
  bool _showSteps = false;

  @override
  void initState() {
    super.initState();
    _sub = _source.changes.listen((_) {
      if (mounted) setState(() {});
    });
    widget.loadDismissed().then((d) {
      if (mounted) setState(() => _dismissed = d);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _close() async {
    setState(() => _dismissed = true);
    await widget.saveDismissed();
  }

  Future<void> _act() async {
    if (_source.platform == InstallPlatform.android) {
      final accepted = await _source.prompt();
      if (accepted && mounted) setState(() {});
    } else {
      // Inline, not a dialog: this bar sits above the app's Navigator, so a
      // dialog has nothing to attach to.
      setState(() => _showSteps = !_showSteps);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldOfferInstall(_source, dismissed: _dismissed)) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final android = _source.platform == InstallPlatform.android;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 2, bottom: 2),
            child: Row(children: [
              Expanded(
                child: Text(
                  android ? '앱으로 설치할 수 있어요' : '홈 화면에 추가하면 앱처럼 쓸 수 있어요',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSecondaryContainer),
                ),
              ),
              TextButton(
                  onPressed: _act,
                  child: Text(android ? '설치' : (_showSteps ? '접기' : '방법'))),
              IconButton(
                tooltip: '닫기',
                icon: const Icon(Icons.close),
                onPressed: _close,
              ),
            ]),
          ),
          if (_showSteps && !android) const _IosSteps(),
        ]),
      ),
    );
  }
}

class _IosSteps extends StatelessWidget {
  const _IosSteps();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final step = TextStyle(
        fontSize: 15, height: 1.5, color: scheme.onSecondaryContainer);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(style: step, children: const [
                TextSpan(text: '1. 화면 아래의 공유 버튼 '),
                WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(Icons.ios_share, size: 18)),
                TextSpan(text: ' 을 누르세요'),
              ]),
            ),
            Text("2. 목록을 올려서 '홈 화면에 추가'를 고르세요", style: step),
            Text("3. 오른쪽 위 '추가'를 누르세요", style: step),
            const SizedBox(height: 6),
            Text('Safari에서 열어야 이 메뉴가 보여요.', style: step.copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
