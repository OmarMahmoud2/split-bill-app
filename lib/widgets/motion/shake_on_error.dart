import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_haptics.dart';
import 'package:split_bill_app/theme/app_motion.dart';

/// Triggers a [ShakeOnError]: `controller.shake()` after a failed validation.
class ShakeController extends ChangeNotifier {
  int _count = 0;

  /// Number of shakes requested so far.
  int get count => _count;

  /// Shakes the attached [ShakeOnError] once and fires the warning haptic.
  void shake() {
    _count++;
    AppHaptics.warning();
    notifyListeners();
  }
}

/// Shakes [child] horizontally once (6 px, 3 cycles, 300 ms) each time
/// [controller] is asked to. Under Reduce Motion there is no movement (the
/// haptic still fires).
class ShakeOnError extends StatefulWidget {
  const ShakeOnError({
    super.key,
    required this.controller,
    required this.child,
  });

  final ShakeController controller;
  final Widget child;

  @override
  State<ShakeOnError> createState() => _ShakeOnErrorState();
}

class _ShakeOnErrorState extends State<ShakeOnError>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShake);
  }

  @override
  void didUpdateWidget(ShakeOnError old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onShake);
      widget.controller.addListener(_onShake);
    }
  }

  void _onShake() {
    if (!mounted || AppMotion.reduceMotion(context)) return;
    _anim.forward(from: 0);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShake);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(math.sin(_anim.value * 3 * 2 * math.pi) * 6, 0),
        child: child,
      ),
    );
  }
}
