import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_haptics.dart';
import 'package:split_bill_app/theme/app_motion.dart';

/// Scales [child] to 0.97 while pressed (120 ms) and optionally gives a
/// light haptic on tap (primary buttons, toggles, chips). Skips the scale
/// under Reduce Motion; the haptic stays.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = false,
    this.scale = 0.97,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Light haptic on tap.
  final bool haptic;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final reduce = AppMotion.reduceMotion(context);
    final child = AnimatedScale(
      scale: _down && !reduce ? widget.scale : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    );
    if (!enabled) return child;
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) AppHaptics.light();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: child,
    );
  }
}
