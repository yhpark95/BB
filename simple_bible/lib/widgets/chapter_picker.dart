import 'package:flutter/material.dart';

import 'reader_bar.dart';

/// The one chapter grid.
///
/// There used to be two: one behind the book pill (four columns, no marker for
/// the chapter being read) and one behind the bottom bar (five columns, with a
/// marker). Same task, two answers, and only one of them told you where you
/// were.
class ChapterPicker extends StatefulWidget {
  /// Shown in the header, e.g. "마가복음".
  final String bookLabel;
  final int chapterCount;

  /// Marked and scrolled to on open. Null when arriving from another book.
  final int? currentChapter;
  final void Function(int chapter) onSelected;

  /// Shown instead of a close button when this is the second step of the book
  /// picker, so there is a way back to the list.
  final VoidCallback? onBack;

  const ChapterPicker({
    super.key,
    required this.bookLabel,
    required this.chapterCount,
    required this.onSelected,
    this.currentChapter,
    this.onBack,
  });

  @override
  State<ChapterPicker> createState() => _ChapterPickerState();
}

class _ChapterPickerState extends State<ChapterPicker> {
  static const int _columns = 5;
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    // Psalms is 30 rows deep. Opening at chapter 1 when the reader is in 119
    // means scrolling for it every single time.
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    final current = widget.currentChapter;
    if (current == null || !_controller.hasClients) return;
    final row = (current - 1) ~/ _columns;
    // Land the row a little below the top rather than flush against it, so the
    // chapters before it stay visible for context.
    final target = (row - 1) * _rowExtent;
    _controller.jumpTo(
      target.clamp(0.0, _controller.position.maxScrollExtent),
    );
  }

  double get _rowExtent => 56 + 8;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // The book name alone. A grid of chapter numbers under a back button
        // does not need to be told what it is.
        _PickerHeader(
          title: widget.bookLabel,
          onBack: widget.onBack,
        ),
        Expanded(
          child: GridView.builder(
            controller: _controller,
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              // Square-ish and at least 48dp, for readers who are not precise
              // tappers.
              mainAxisExtent: 56,
            ),
            itemCount: widget.chapterCount,
            itemBuilder: (context, index) {
              final chapter = index + 1;
              final isCurrent = chapter == widget.currentChapter;
              return Material(
                color: isCurrent
                    ? scheme.primary
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => widget.onSelected(chapter),
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Text(
                      '$chapter',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isCurrent
                            ? scheme.onPrimary
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Shared header for both picker steps.
class _PickerHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const _PickerHeader({required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            // Same rule as the rest of the chrome: fold at a space, shrink if
            // that is not enough, never cut.
            child: shrinkLabel(
              title,
              alignment: Alignment.centerLeft,
              maxLines: 2,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (onBack != null)
            TextButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('책 목록', style: TextStyle(fontSize: 15)),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: onBack,
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              iconSize: 28,
              onPressed: () => Navigator.pop(context),
              tooltip: '닫기',
            ),
        ],
      ),
    );
  }
}

/// Header used by the book list step.
class PickerHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const PickerHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) =>
      _PickerHeader(title: title, onBack: onBack);
}

/// Wraps a picker step in the dialog both entry points use.
Future<void> showPickerDialog(BuildContext context, Widget child) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: child,
        ),
      ),
    ),
  );
}
