import 'package:flutter/material.dart';

/// What the reader and the bookmark list show when something failed to load.
///
/// The exception itself goes to the log, not here: a DatabaseException with its
/// SQL in it means nothing to someone reading the Bible, and looks like the
/// phone is broken. What they can act on is trying again.
class LoadErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const LoadErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도', style: TextStyle(fontSize: 16)),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
