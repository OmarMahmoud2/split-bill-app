import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_motion.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_spacing.dart';

/// Shares one shimmer sweep with every [Skeleton] below it, so a whole
/// list shimmers in sync. Optional: a lone [Skeleton] runs its own.
/// Under Reduce Motion the skeletons are static.
///
/// "Loading uses skeletons, never a lone spinner" (v3 states mockup).
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  static Animation<double>? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.animation;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduceMotion(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'feedback_loading'.tr(),
    container: true,
    excludeSemantics: true,
    child: _ShimmerScope(animation: _controller, child: widget.child),
  );
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_ShimmerScope old) => old.animation != animation;
}

/// A placeholder block. Use [Skeleton.line] for text lines,
/// [Skeleton.circle] for avatars and [SkeletonCard] for a card of lines.
///
/// ```dart
/// SkeletonShimmer(child: Column(children: [
///   for (var i = 0; i < 3; i++) const SkeletonCard(),
/// ]))
/// ```
const _lineRadius = BorderRadius.all(Radius.circular(8));

class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = _lineRadius,
    this.shape = BoxShape.rectangle,
  });

  const Skeleton.line({super.key, this.width, this.height = 14})
    : borderRadius = _lineRadius,
      shape = BoxShape.rectangle;

  const Skeleton.circle({super.key, double size = 40})
    : width = size,
      height = size,
      borderRadius = null,
      shape = BoxShape.circle;

  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  AnimationController? _own;

  Animation<double>? _animation(BuildContext context) {
    final shared = SkeletonShimmer._of(context);
    if (shared != null) return shared;
    if (AppMotion.reduceMotion(context)) {
      _own?.stop();
      return null;
    }
    _own ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!_own!.isAnimating) _own!.repeat();
    return _own;
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = AppMotion.reduceMotion(context);
    final animation = reduce ? null : _animation(context);

    BoxDecoration decoration(double t) {
      final gradient = animation == null
          ? null
          : LinearGradient(
              begin: Alignment(-1.5 + 3 * t, 0),
              end: Alignment(-0.5 + 3 * t, 0),
              colors: [p.skeleton, p.skeletonHighlight, p.skeleton],
            );
      return BoxDecoration(
        color: gradient == null ? p.skeleton : null,
        gradient: gradient,
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.circle
            ? null
            : widget.borderRadius,
      );
    }

    final size = Size(widget.width ?? double.infinity, widget.height);
    if (animation == null) {
      return SizedBox.fromSize(
        size: size,
        child: DecoratedBox(decoration: decoration(0)),
      );
    }
    return SizedBox.fromSize(
      size: size,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) =>
            DecoratedBox(decoration: decoration(animation.value)),
      ),
    );
  }
}

/// A hairline card with three skeleton lines (60%, 85%, 40%), as in the
/// v3 states mockup.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.lines = const [0.6, 0.85, 0.4]});

  /// Width fraction of each line.
  final List<double> lines;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              Skeleton.line(width: constraints.maxWidth * lines[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// A list-row placeholder: avatar circle, two lines, an amount block.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: AppSpacing.listItemPadding,
    child: Row(
      children: [
        Skeleton.circle(size: 40),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(widthFactor: 0.6, child: Skeleton.line()),
              SizedBox(height: AppSpacing.sm),
              FractionallySizedBox(
                widthFactor: 0.35,
                child: Skeleton.line(height: 12),
              ),
            ],
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Skeleton.line(width: 56, height: 16),
      ],
    ),
  );
}
