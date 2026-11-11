import 'package:flutter/material.dart';

import '../services/donation_service.dart';

/// Opens the donation sheet. [gateway] is only for tests; the app uses Play.
Future<void> showDonationSheet(BuildContext context,
    {DonationGateway Function()? gateway}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DonationSheet(gateway: gateway),
  );
}

class DonationSheet extends StatefulWidget {
  final DonationGateway Function()? gateway;
  const DonationSheet({super.key, this.gateway});

  @override
  State<DonationSheet> createState() => _DonationSheetState();
}

class _DonationSheetState extends State<DonationSheet> {
  late final DonationService _service;

  @override
  void initState() {
    super.initState();
    _service = DonationService(
        widget.gateway?.call() ?? PlayDonationGateway());
    _service.addListener(_onChange);
    _service.load();
  }

  void _onChange() {
    if (!mounted) return;
    final e = _service.lastEvent;
    if (e == DonationEvent.thanked) {
      _service.clearEvent();
      Navigator.of(context).pop();
      // The sheet is gone, so the thanks goes to the screen below it.
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('후원해 주셔서 고맙습니다')));
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _service.removeListener(_onChange);
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('개발자 후원하기',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              '이 앱은 광고도 없고, 후원하지 않아도 모든 기능을 쓸 수 있어요.\n'
              '고마운 마음이 들 때만 후원해 주세요. 후원해도 달라지는 건 없어요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 20),
            _body(scheme),
            if (_service.lastEvent == DonationEvent.failed) ...[
              const SizedBox(height: 12),
              Text('결제하지 못했어요. 잠시 뒤 다시 해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _body(ColorScheme scheme) {
    switch (_service.state) {
      case DonationState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        );
      case DonationState.unavailable:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('지금은 후원할 수 없어요.\n나중에 다시 눌러 보세요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: _service.load,
              child: const Text('다시 시도'),
            ),
          ],
        );
      case DonationState.ready:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final o in _service.options) ...[
              FilledButton.tonal(
                style:
                    FilledButton.styleFrom(minimumSize: const Size(0, 56)),
                onPressed: _service.buying ? null : () => _service.buy(o),
                child: Text(o.price,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
    }
  }
}
