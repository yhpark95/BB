import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

/// Shared gesture layer used by all reader views (narrow and wide).
///
/// Handles:
/// - 2-finger pinch-to-zoom → updates [SettingsService.fontSize]
/// - 1-finger horizontal swipe → calls [onSwipeLeft] / [onSwipeRight]
/// - Optional live-drag callbacks for PageView-based readers ([onDragStart],
///   [onDragUpdate], [onDragCancel])
class ReaderGestureLayer extends StatefulWidget {
  final Widget child;

  /// Confirmed left swipe → navigate to next page/chapter.
  final VoidCallback? onSwipeLeft;

  /// Confirmed right swipe → navigate to previous page/chapter.
  final VoidCallback? onSwipeRight;

  /// Called once when a horizontal drag is first confirmed.
  /// Use this to snapshot the current scroll offset before [onDragUpdate] fires.
  final VoidCallback? onDragStart;

  /// Called each pointer-move frame with total horizontal displacement (in
  /// logical pixels) from the drag start. Positive dx = dragged right.
  /// Only provided by PageView-based readers for live-drag animation.
  final void Function(double dx)? onDragUpdate;

  /// Called when a drag is cancelled or does not meet the threshold.
  /// Use this to snap back to the nearest page.
  final VoidCallback? onDragCancel;

  const ReaderGestureLayer({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragCancel,
  });

  @override
  State<ReaderGestureLayer> createState() => _ReaderGestureLayerState();
}

class _ReaderGestureLayerState extends State<ReaderGestureLayer> {
  final Map<int, Offset> _activePointers = {};

  // Pinch-to-zoom
  double? _initialPinchDistance;
  double _initialFontSize = SettingsService.defaultFontSize;

  // Swipe tracking
  Offset? _swipeStart;
  DateTime? _swipeStartTime;
  bool _isSwiping = false;
  bool _dragStartFired = false;

  // Minimum horizontal movement before swipe is recognised
  static const double _swipeSlop = 8.0;
  // dx/dy ratio required to confirm horizontal intent (vs vertical scroll)
  static const double _swipeDirectionRatio = 1.5;
  // Minimum velocity (dp/s) for a fast flick to trigger page turn
  static const double _flickVelocity = 300.0;
  // Fraction of widget width required for a slow drag to trigger page turn
  // Only enforced when live-drag callbacks are provided
  static const double _dragFraction = 0.3;

  void _resetSwipe() {
    _isSwiping = false;
    _swipeStart = null;
    _swipeStartTime = null;
    _dragStartFired = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) => LayoutBuilder(
        builder: (context, constraints) => Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _activePointers[e.pointer] = e.position;

            if (_activePointers.length == 1) {
              _swipeStart = e.position;
              _swipeStartTime = DateTime.now();
              _isSwiping = false;
              _dragStartFired = false;
            }

            // Second finger cancels swipe and starts pinch
            if (_activePointers.length == 2) {
              if (_isSwiping) widget.onDragCancel?.call();
              _resetSwipe();
              final pts = _activePointers.values.toList();
              _initialPinchDistance = (pts[0] - pts[1]).distance;
              _initialFontSize = settings.fontSize;
            }
          },
          onPointerMove: (e) {
            _activePointers[e.pointer] = e.position;

            // Single-finger: detect and drive horizontal page swipe
            if (_activePointers.length == 1 && _swipeStart != null) {
              final dx = e.position.dx - _swipeStart!.dx;
              final dy = e.position.dy - _swipeStart!.dy;

              if (!_isSwiping &&
                  dx.abs() > _swipeSlop &&
                  dx.abs() > dy.abs() * _swipeDirectionRatio) {
                _isSwiping = true;
                if (!_dragStartFired) {
                  _dragStartFired = true;
                  widget.onDragStart?.call();
                }
              }
              if (_isSwiping) widget.onDragUpdate?.call(dx);
            }

            // Two-finger: pinch-to-zoom
            if (_activePointers.length == 2 &&
                _initialPinchDistance != null &&
                _initialPinchDistance! > 1) {
              final pts = _activePointers.values.toList();
              final dist = (pts[0] - pts[1]).distance;
              final scale = dist / _initialPinchDistance!;
              // Preview only; the size is written once the pinch ends.
              settings.previewFontSize(_initialFontSize * scale);
            }
          },
          onPointerUp: (e) {
            if (_isSwiping && _activePointers.length == 1 && _swipeStart != null) {
              final dx = e.position.dx - _swipeStart!.dx;
              final ms = _swipeStartTime != null
                  ? DateTime.now().difference(_swipeStartTime!).inMilliseconds
                  : 1;
              final vx = ms > 0 ? dx / ms * 1000.0 : 0.0;
              final viewportWidth = constraints.maxWidth;
              final hasLiveDrag = widget.onDragUpdate != null;

              final bool goLeft = vx < -_flickVelocity ||
                  (hasLiveDrag && dx < -(viewportWidth * _dragFraction));
              final bool goRight = vx > _flickVelocity ||
                  (hasLiveDrag && dx > viewportWidth * _dragFraction);

              if (goLeft) {
                widget.onSwipeLeft?.call();
              } else if (goRight) {
                widget.onSwipeRight?.call();
              } else if (hasLiveDrag) {
                widget.onDragCancel?.call();
              }
            }

            _resetSwipe();
            _activePointers.remove(e.pointer);
            if (_activePointers.length < 2 && _initialPinchDistance != null) {
              _initialPinchDistance = null;
              settings.commitFontSize();
            }
          },
          onPointerCancel: (e) {
            if (_isSwiping) widget.onDragCancel?.call();
            _resetSwipe();
            _activePointers.remove(e.pointer);
            if (_activePointers.length < 2 && _initialPinchDistance != null) {
              _initialPinchDistance = null;
              settings.commitFontSize();
            }
          },
          child: widget.child,
        ),
      ),
    );
  }
}
