import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_colors.dart';
import 'package:split_bill_app/theme/app_haptics.dart';
import 'package:split_bill_app/theme/app_motion.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_spacing.dart';
import 'package:split_bill_app/theme/app_typography.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Full-screen v3 success moment.
///
/// A check draws and scales in, the amount counts up (or rolls from
/// [rollFromMinor] to [amountMinor], e.g. a balance settling to zero), the
/// title and message fade in, a one-shot confetti burst (mint, coral, sky and
/// sun) plays and a success haptic fires once. Set [celebrate] for the big
/// moments ("whole group settled") to get a bigger burst. Under Reduce Motion everything is a 150 ms crossfade
/// and there is no confetti; the haptic stays.
///
/// ```dart
/// SuccessScreen.show(context,
///   title: 'everyones_square'.tr(),
///   message: 'recap_ready'.tr(),
///   caption: 'trip_balance'.tr(),
///   rollFromMinor: 4100, amountMinor: 0, currency: 'USD',
///   celebrate: true,
///   primaryLabel: 'share_recap'.tr(), onPrimary: _share,
///   secondaryLabel: 'archive_group'.tr(), onSecondary: _archive);
/// ```
class SuccessScreen extends StatefulWidget {
  const SuccessScreen({
    super.key,
    required this.title,
    required this.primaryLabel,
    required this.onPrimary,
    this.message,
    this.caption,
    this.amountMinor,
    this.rollFromMinor,
    this.currency = 'USD',
    this.amountSign = MoneySign.negativeOnly,
    this.amountTone = MoneyTone.neutral,
    this.secondaryLabel,
    this.onSecondary,
    this.tertiaryLabel,
    this.onTertiary,
    this.celebrate = false,
    this.haptic = true,
    this.showCheck = true,
  });

  /// Pushes a [SuccessScreen] with a fade transition.
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String primaryLabel,
    required VoidCallback onPrimary,
    String? message,
    String? caption,
    int? amountMinor,
    int? rollFromMinor,
    String currency = 'USD',
    MoneySign amountSign = MoneySign.negativeOnly,
    MoneyTone amountTone = MoneyTone.neutral,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    String? tertiaryLabel,
    VoidCallback? onTertiary,
    bool celebrate = false,
    bool haptic = true,
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        transitionDuration: AppMotion.durationFor(context, AppMotion.slow),
        reverseTransitionDuration: AppMotion.durationFor(context, AppMotion.medium),
        pageBuilder: (_, _, _) => SuccessScreen(
          title: title,
          primaryLabel: primaryLabel,
          onPrimary: onPrimary,
          message: message,
          caption: caption,
          amountMinor: amountMinor,
          rollFromMinor: rollFromMinor,
          currency: currency,
          amountSign: amountSign,
          amountTone: amountTone,
          secondaryLabel: secondaryLabel,
          onSecondary: onSecondary,
          tertiaryLabel: tertiaryLabel,
          onTertiary: onTertiary,
          celebrate: celebrate,
          haptic: haptic,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  final String title;
  final String? message;

  /// Small muted line above the amount ("Dahab trip balance").
  final String? caption;

  /// Hero amount in minor units; hidden when null.
  final int? amountMinor;

  /// When set, the amount rolls from this value to [amountMinor].
  final int? rollFromMinor;
  final String currency;
  final MoneySign amountSign;
  final MoneyTone amountTone;

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Optional third, quietest action (e.g. "Archive group").
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;

  /// Quiet one-shot confetti. Only for whole-group-settled moments.
  final bool celebrate;

  /// Fire `AppHaptics.success()` once when shown.
  final bool haptic;
  final bool showCheck;

  @override
  State<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<SuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  AnimationController? _confetti;
  bool _started = false;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.haptic) AppHaptics.success();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduce = AppMotion.reduceMotion(context);
    if (_reduce) _intro.duration = AppMotion.reducedCrossfade;
    _intro.forward();
    if (!_reduce) {
      _confetti = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: widget.celebrate ? 3200 : 2400),
      )..forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _confetti?.dispose();
    super.dispose();
  }

  Animation<double> _interval(double begin, double end, [Curve? curve]) =>
      CurvedAnimation(
        parent: _intro,
        curve: _reduce
            ? Curves.linear
            : Interval(begin, end, curve: curve ?? AppMotion.quiet),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final checkScale = _interval(0, 0.45, Curves.easeOutBack);
    final checkDraw = _interval(0.2, 0.7, AppMotion.emphasizedDecelerate);
    final textFade = _interval(0.35, 1);

    Widget fadeUp(Widget child) => AnimatedBuilder(
      animation: textFade,
      child: child,
      builder: (context, child) => Opacity(
        opacity: textFade.value,
        child: _reduce
            ? child
            : Transform.translate(
                offset: Offset(0, 8 * (1 - textFade.value)),
                child: child,
              ),
      ),
    );

    Widget? amount;
    if (widget.amountMinor != null) {
      final finalAmount = MoneyText(
        minor: widget.amountMinor!,
        currency: widget.currency,
        sign: widget.amountSign,
        tone: widget.amountTone,
        size: MoneySize.hero,
        animate: widget.rollFromMinor == null,
        textAlign: TextAlign.center,
      );
      if (widget.rollFromMinor != null) {
        final from = MoneyText(
          minor: widget.rollFromMinor!,
          currency: widget.currency,
          sign: MoneySign.always,
          tone: MoneyTone.auto,
          size: MoneySize.hero,
          textAlign: TextAlign.center,
        );
        amount = SizedBox(
          height: 64,
          child: RollToZero(
            from: from,
            to: finalAmount,
            delay: const Duration(milliseconds: 400),
          ),
        );
      } else {
        amount = finalAmount;
      }
    }

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          if (_confetti != null)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    painter: _ConfettiPainter(
                      animation: _confetti!,
                      pieces: widget.celebrate ? 56 : 32,
                      colors: [p.accent, p.coral, p.sky, AppColors.sun],
                    ),
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xxl,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showCheck) ...[
                              _AnimatedCheck(
                                scale: checkScale,
                                draw: checkDraw,
                                color: p.accent,
                                soft: p.accentSoft,
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                            ],
                            if (widget.caption != null)
                              fadeUp(
                                Text(
                                  widget.caption!,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: p.textSecondary,
                                  ),
                                ),
                              ),
                            if (amount != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              FittedBox(fit: BoxFit.scaleDown, child: amount),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            fadeUp(
                              Semantics(
                                header: true,
                                liveRegion: true,
                                child: Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.headlineLarge.copyWith(
                                    fontSize: 26,
                                    color: p.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.message != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              fadeUp(
                                Text(
                                  widget.message!,
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: p.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  fadeUp(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: widget.onPrimary,
                          child: Text(widget.primaryLabel),
                        ),
                        if (widget.secondaryLabel != null &&
                            widget.onSecondary != null) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: widget.onSecondary,
                            style: TextButton.styleFrom(
                              foregroundColor: p.textPrimary,
                              minimumSize: const Size(0, AppSpacing.buttonLg),
                              textStyle: AppTypography.labelLarge,
                            ),
                            child: Text(widget.secondaryLabel!),
                          ),
                        ],
                        if (widget.tertiaryLabel != null &&
                            widget.onTertiary != null)
                          TextButton(
                            onPressed: widget.onTertiary,
                            style: TextButton.styleFrom(
                              foregroundColor: p.textSecondary,
                              minimumSize: const Size(0, AppSpacing.buttonLg),
                              textStyle: AppTypography.labelLarge,
                            ),
                            child: Text(widget.tertiaryLabel!),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedCheck extends StatelessWidget {
  const _AnimatedCheck({
    required this.scale,
    required this.draw,
    required this.color,
    required this.soft,
  });

  final Animation<double> scale;
  final Animation<double> draw;
  final Color color;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: Listenable.merge([scale, draw]),
        builder: (context, _) => Transform.scale(
          scale: scale.value,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
            child: CustomPaint(
              painter: _CheckPainter(progress: draw.value, color: color),
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
    if (progress <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.29, w * 0.52)
      ..lineTo(w * 0.44, w * 0.66)
      ..lineTo(w * 0.71, w * 0.37);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// A burst of mint, coral, sky and sun pieces from the top centre that fan
/// out, fall with gravity and fade, once. Deterministic (seeded) so tests
/// and golden frames are stable.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.animation,
    required this.colors,
    required this.pieces,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Color> colors;
  final int pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final t = animation.value;
    final origin = Offset(size.width / 2, size.height * 0.28);
    for (var i = 0; i < pieces; i++) {
      final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.1;
      final speed = size.height * (0.18 + 0.32 * rnd.nextDouble());
      final delay = 0.12 * rnd.nextDouble();
      final local = ((t - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final burst = Curves.easeOutCubic.transform(local);
      final pos = Offset(
        origin.dx + math.cos(angle) * speed * burst,
        origin.dy +
            math.sin(angle) * speed * burst +
            size.height * 0.5 * local * local,
      );
      final opacity = local < 0.7 ? 1.0 : 1 - (local - 0.7) / 0.3;
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(local * math.pi * (2 + 3 * rnd.nextDouble()));
      final w = 5 + 4 * rnd.nextDouble();
      if (i % 3 == 0) {
        canvas.drawCircle(Offset.zero, w / 2, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: w * 1.8),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
