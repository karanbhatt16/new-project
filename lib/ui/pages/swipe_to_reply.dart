import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// WhatsApp/Instagram-style swipe-to-reply wrapper.
///
/// - Drag horizontally to reveal the reply icon.
/// - Crossing a threshold triggers [onReply] and snaps back.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.replyFromRight = false,
  });

  final Widget child;
  final VoidCallback onReply;

  /// If true: swipe left (towards start) to reply (typical for my outgoing messages).
  /// If false: swipe right to reply (typical for incoming messages).
  final bool replyFromRight;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  static const _maxDrag = 72.0;
  static const _trigger = 54.0;

  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );

  double _dx = 0;
  bool _triggered = false;

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _animateBack() {
    final begin = _dx;
    _snap
      ..stop()
      ..value = 0;

    _snap.addListener(() {
      setState(() {
        _dx = begin * (1 - _snap.value);
      });
    });

    _snap.forward().whenComplete(() {
      _snap.removeListener(() {});
      if (mounted) setState(() => _dx = 0);
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final sign = widget.replyFromRight ? -1.0 : 1.0;
    final drag = _dx * sign;
    final reveal = drag.clamp(0.0, _maxDrag);

    final iconProgress = (reveal / _maxDrag).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (d) {
        setState(() {
          _dx += d.delta.dx;

          // Restrict to intended direction.
          if (widget.replyFromRight && _dx > 0) _dx = 0;
          if (!widget.replyFromRight && _dx < 0) _dx = 0;

          // Clamp.
          if (_dx.abs() > _maxDrag) {
            _dx = _maxDrag * _dx.sign;
          }

          final progress = (_dx.abs());
          if (!_triggered && progress >= _trigger) {
            _triggered = true;
            // Light haptic like WhatsApp/Instagram.
            HapticFeedback.selectionClick();
            widget.onReply();
          }
        });
      },
      onHorizontalDragEnd: (_) => _animateBack(),
      onHorizontalDragCancel: _animateBack,
      child: Stack(
        alignment: widget.replyFromRight ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          // Only show the icon while swiping.
          IgnorePointer(
            child: Opacity(
              opacity: iconProgress,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Transform.scale(
                  scale: 0.7 + 0.3 * iconProgress,
                  child: Icon(
                    Icons.reply,
                    color: theme.colorScheme.secondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
