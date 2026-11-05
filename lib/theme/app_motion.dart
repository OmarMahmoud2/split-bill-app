import 'package:flutter/widgets.dart';

/// v3 motion tokens.
///
/// 150-250 ms for UI, 300-450 ms when money moves. Reduce Motion turns
/// every movement into a 150 ms crossfade ([reduceMotion]); haptics stay.
/// Nothing loops except an active scan (and skeleton shimmer, which stops
/// under Reduce Motion).
///
/// Built on implicit animations / [TweenAnimationBuilder] only, so there is
/// no animation package dependency.
class AppMotion {
  AppMotion._();

  // ------------------------------------------------------------- durations
  /// Hover, press, small state changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// Default UI transition.
  static const Duration medium = Duration(milliseconds: 200);

  /// Larger UI transitions (sheets, toasts).
  static const Duration slow = Duration(milliseconds: 250);

  /// Money moved: short (row updates).
  static const Duration moneyShort = Duration(milliseconds: 300);

  /// Money moved: default (count-up, roll to zero).
  static const Duration money = Duration(milliseconds: 400);

  /// Money moved: long (hero amount, success check).
  static const Duration moneyLong = Duration(milliseconds: 450);

  /// The crossfade every movement becomes under Reduce Motion.
  static const Duration reducedCrossfade = fast;

  /// Delay between items of a staggered entrance.
  static const Duration staggerStep = Duration(milliseconds: 40);

  /// Toast auto-dismiss.
  static const Duration toastVisible = Duration(milliseconds: 4000);

  // ---------------------------------------------------------------- curves
  /// Material 3 emphasized decelerate: things arriving on screen.
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Material 3 emphasized accelerate: things leaving the screen.
  static const Curve emphasizedAccelerate = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Material 3 standard easing.
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);

  /// The spec's `cubic-bezier(.2,.8,.2,1)`: quick start, soft landing. Used
  /// for count-up, hop and roll.
  static const Curve quiet = Cubic(0.2, 0.8, 0.2, 1.0);

  // ---------------------------------------------------------- reduce motion
  /// Test hook: forces [reduceMotion] on or off when non-null.
  static bool? debugReduceMotionOverride;

  /// Whether the user asked the OS to reduce motion
  /// (`MediaQuery.disableAnimations`).
  static bool reduceMotion(BuildContext context) =>
      debugReduceMotionOverride ??
      MediaQuery.maybeDisableAnimationsOf(context) ??
      false;

  /// [normal], or [reducedCrossfade] when motion is reduced.
  static Duration durationFor(BuildContext context, Duration normal) =>
      reduceMotion(context) ? reducedCrossfade : normal;
}

/// Fades and lifts [child] in when first built; with [index] the delay is
/// staggered so lists cascade in. Under Reduce Motion it only crossfades.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 8,
    this.duration = AppMotion.slow,
    this.maxStaggeredItems = 8,
  });

  final Widget child;

  /// Position in the list; items past [maxStaggeredItems] share the last
  /// delay so long lists do not wait.
  final int index;

  /// Vertical travel in logical pixels.
  final double offset;
  final Duration duration;
  final int maxStaggeredItems;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _curved;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_curved != null) return;
    _reduce = AppMotion.reduceMotion(context);
    final run = _reduce ? AppMotion.reducedCrossfade : widget.duration;
    final steps = widget.index.clamp(0, widget.maxStaggeredItems);
    final delay = _reduce ? Duration.zero : AppMotion.staggerStep * steps;
    final total = delay + run;
    // The delay is the first part of one controller run, so no timers.
    _controller.duration = total;
    _curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: AppMotion.emphasizedDecelerate,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _curved!;
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) {
        final t = curved.value;
        return Opacity(
          opacity: t,
          child: _reduce
              ? child
              : Transform.translate(
                  offset: Offset(0, widget.offset * (1 - t)),
                  child: child,
                ),
        );
      },
    );
  }
}

/// Animates a number from its previous value (or [from] on first build) to
/// [value] and hands the current value to [builder]. Under Reduce Motion the
/// final value is shown immediately.
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.builder,
    this.from = 0,
    this.duration = AppMotion.money,
    this.curve = AppMotion.quiet,
  });

  final double value;
  final double from;
  final Duration duration;
  final Curve curve;
  final Widget Function(BuildContext context, double value) builder;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduceMotion(context)) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: from, end: value),
      duration: duration,
      curve: curve,
      builder: (context, v, _) => builder(context, v),
    );
  }
}

/// An avatar "hops" onto an item: drops 12 px with one small overshoot.
/// Pair with `AppHaptics.selection()` at the call site. Reduce Motion: fade.
class AvatarHop extends StatelessWidget {
  const AvatarHop({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduce ? AppMotion.reducedCrossfade : duration,
      curve: Curves.linear,
      child: child,
      builder: (context, t, child) {
        if (reduce) return Opacity(opacity: t, child: child);
        // 0 -> 60%: from -12 to +1 (fade in); 60 -> 100%: settle at 0.
        final double dy;
        if (t < 0.6) {
          dy = -12 + 13 * AppMotion.quiet.transform(t / 0.6);
        } else {
          dy = 1 - AppMotion.quiet.transform((t - 0.6) / 0.4);
        }
        return Opacity(
          opacity: (t / 0.6).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}

/// The settled moment: [from] slides up and out while [to] (usually the zero
/// amount) slides in from below, clipped to one line. Reduce Motion:
/// crossfade.
class RollToZero extends StatelessWidget {
  const RollToZero({
    super.key,
    required this.from,
    required this.to,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
  });

  final Widget from;
  final Widget to;
  final Duration duration;

  /// Hold [from] for this long before rolling.
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final reduce = AppMotion.reduceMotion(context);
    final total = delay + (reduce ? AppMotion.reducedCrossfade : duration);
    final start = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, raw, _) {
        final t = start >= 1
            ? 1.0
            : ((raw - start) / (1 - start)).clamp(0.0, 1.0);
        if (reduce) {
          return Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              Opacity(opacity: 1 - t, child: from),
              Opacity(opacity: t, child: to),
            ],
          );
        }
        final eased = AppMotion.quiet.transform(t);
        return ClipRect(
          child: Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              FractionalTranslation(
                translation: Offset(0, -eased),
                child: Opacity(opacity: 1 - eased, child: from),
              ),
              FractionalTranslation(
                translation: Offset(0, 1 - eased),
                child: Opacity(opacity: eased, child: to),
              ),
            ],
          ),
        );
      },
    );
  }
}
