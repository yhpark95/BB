import 'dart:async';

import 'package:flutter/material.dart';

import '../update_check.dart';

/// A thin bar at the top that appears when a newer build has been published.
/// Does nothing on a dev build, so it never runs in tests or on the phone.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({
    super.key,
    this.running = kBuildStamp,
    this.fetch = fetchLatestVersion,
    this.onUpdate = reloadFresh,
    this.interval = const Duration(minutes: 10),
  });

  final String running;
  final Future<String?> Function() fetch;
  final Future<void> Function() onUpdate;
  final Duration interval;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with WidgetsBindingObserver {
  bool _outdated = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.running == 'dev') return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(widget.interval, (_) => _check());
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final latest = await widget.fetch();
    if (!mounted) return;
    final out = isOutdated(widget.running, latest);
    if (out != _outdated) setState(() => _outdated = out);
  }

  @override
  Widget build(BuildContext context) {
    if (!_outdated) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Expanded(
              child: Text('새 버전이 있어요',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onTertiaryContainer)),
            ),
            TextButton(
                onPressed: widget.onUpdate, child: const Text('업데이트')),
          ]),
        ),
      ),
    );
  }
}
