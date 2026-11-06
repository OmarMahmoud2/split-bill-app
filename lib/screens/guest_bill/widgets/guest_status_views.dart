import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

import 'guest_chrome.dart';

/// Waiting / confirmed: a badge, a title, a message, then the app card.
class GuestOutcomeView extends StatelessWidget {
  const GuestOutcomeView({
    super.key,
    required this.confirmed,
    required this.title,
    required this.message,
    this.footer,
  });

  final bool confirmed;
  final String title;
  final String message;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    confirmed
                        ? const GuestCheckBadge()
                        : Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: p.oweSoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.hourglass_top_rounded,
                              size: 44,
                              color: p.oweInk,
                            ),
                          ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineLarge.copyWith(
                        fontSize: 26,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge.copyWith(
                        fontSize: 15,
                        height: 1.5,
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 30),
              child: footer,
            ),
        ],
      ),
    );
  }
}

/// Teal circle whose check draws in once (static under Reduce Motion).
class GuestCheckBadge extends StatefulWidget {
  const GuestCheckBadge({super.key, this.size = 96});

  final double size;

  @override
  State<GuestCheckBadge> createState() => _GuestCheckBadgeState();
}

class _GuestCheckBadgeState extends State<GuestCheckBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduceMotion(context)) {
      _c.value = 1;
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _CheckPainter(
              progress: Curves.easeOut.transform(_c.value),
              color: p.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 2 / 24; // 48px glyph in a 96px circle
    final origin = Offset(size.width / 4, size.height / 4);
    final path = Path()
      ..moveTo(origin.dx + 5 * s, origin.dy + 12.5 * s)
      ..lineTo(origin.dx + 9.5 * s, origin.dy + 17 * s)
      ..lineTo(origin.dx + 19 * s, origin.dy + 7.5 * s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// Settled / expired / not found: a quiet message with one way forward.
class GuestMessageView extends StatelessWidget {
  const GuestMessageView({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.footer,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: AppTypography.headlineLarge.copyWith(
                          fontSize: 26,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: AppTypography.bodyLarge.copyWith(
                          fontSize: 15,
                          height: 1.5,
                          color: p.textSecondary,
                        ),
                      ),
                      if (actionLabel != null && onAction != null) ...[
                        const SizedBox(height: 22),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(64, 54),
                            side: BorderSide(color: p.borderStrong),
                          ),
                          onPressed: onAction,
                          child: Text(actionLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: footer,
              ),
            ),
        ],
      ),
    );
  }
}

/// First paint while the bill loads: the picker's shape in skeletons.
class GuestLoadingSkeleton extends StatelessWidget {
  const GuestLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Semantics(
        label: 'feedback_loading'.tr(),
        container: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Skeleton.line(width: 180),
              const SizedBox(height: 10),
              const Skeleton.line(width: 240, height: 28),
              const SizedBox(height: 10),
              const Skeleton.line(width: 160),
              const SizedBox(height: 30),
              const Skeleton.line(width: 140, height: 16),
              const SizedBox(height: 12),
              GuestCard(
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++) const SkeletonListTile(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
