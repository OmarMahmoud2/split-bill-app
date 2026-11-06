import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// The Evens mark: a coin split into two equal halves resting on one line.
/// Matches tool/brand/make_brand_assets.py so the native splash hands over
/// without a jump.
class EvensMark extends StatelessWidget {
  const EvensMark({
    super.key,
    this.size = 192,
    this.split = 0,
    this.line = 1,
    this.coinColor,
    this.lineColor,
  });

  final double size;

  /// Extra gap between the halves, as a fraction of the coin diameter.
  final double split;

  /// How much of the baseline is drawn, 0..1.
  final double line;
  final Color? coinColor;
  final Color? lineColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      size: Size.square(size),
      painter: _EvensMarkPainter(
        split: split,
        line: line,
        coin: coinColor ?? p.accent,
        lineColor: lineColor ?? p.textPrimary,
      ),
    );
  }
}

class _EvensMarkPainter extends CustomPainter {
  _EvensMarkPainter({
    required this.split,
    required this.line,
    required this.coin,
    required this.lineColor,
  });

  final double split;
  final double line;
  final Color coin;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Same proportions as the native splash (180 px tile, 0.9 scale).
    final u = size.width * 0.9 / 180;
    final dia = 86 * u, gap = 11 * u, lineH = 7 * u, lineGap = 12 * u;
    final cx = size.width / 2;
    final top = size.height / 2 - (dia + lineGap + lineH) / 2;
    final rect = Rect.fromLTWH(cx - dia / 2, top, dia, dia);
    final shift = split * dia;
    final paint = Paint()..color = coin;

    for (final side in [-1.0, 1.0]) {
      canvas.save();
      final half = side < 0
          ? Rect.fromLTRB(rect.left, rect.top, cx - gap / 2, rect.bottom)
          : Rect.fromLTRB(cx + gap / 2, rect.top, rect.right, rect.bottom);
      canvas.translate(side * shift, 0);
      canvas.clipRect(half);
      canvas.drawOval(rect, paint);
      canvas.restore();
    }

    if (line > 0) {
      final ly = top + dia + lineGap;
      final width = dia * line.clamp(0.0, 1.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - width / 2, ly, width, lineH),
          Radius.circular(lineH / 2),
        ),
        Paint()..color = lineColor,
      );
    }
  }

  @override
  bool shouldRepaint(_EvensMarkPainter old) =>
      old.split != split ||
      old.line != line ||
      old.coin != coin ||
      old.lineColor != lineColor;
}

/// Cold-start intro shown over the app while it loads: the halves part a
/// little and settle back level, the line draws, the wordmark appears, then
/// everything fades into [child]. Skipped under Reduce Motion.
class BrandIntro extends StatefulWidget {
  const BrandIntro({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1100),
  });

  final Widget child;
  final Duration duration;

  /// Set once per process so hot restarts and new routes don't replay it.
  static bool played = false;

  @override
  State<BrandIntro> createState() => _BrandIntroState();
}

class _BrandIntroState extends State<BrandIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration + AppMotion.medium,
  );
  bool _visible = !BrandIntro.played;
  bool _hapticDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_visible || _c.isAnimating || _c.isCompleted) return;
    if (AppMotion.reduceMotion(context)) {
      BrandIntro.played = true;
      _visible = false;
      return;
    }
    BrandIntro.played = true;
    _c.addListener(_maybeHaptic);
    _c.forward().whenComplete(() {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _maybeHaptic() {
    if (!_hapticDone && _c.value >= _settleAt) {
      _hapticDone = true;
      AppHaptics.light();
    }
  }

  double get _total => _c.duration!.inMilliseconds.toDouble();
  double get _settleAt => 520 / _total;

  double _interval(double startMs, double endMs, Curve curve) {
    final t = ((_c.value * _total - startMs) / (endMs - startMs)).clamp(
      0.0,
      1.0,
    );
    return curve.transform(t);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Same structure before, during and after the intro: the child stays at
    // index 0 of the Stack, so its subtree is never remounted when the
    // overlay goes away.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_visible)
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              // Part (0–260 ms) then settle level (260–520 ms).
              final out = _interval(0, 260, Curves.easeOut);
              final back = _interval(260, 520, AppMotion.emphasizedDecelerate);
              final split = 0.08 * out * (1 - back);
              final line = _interval(380, 760, AppMotion.emphasizedDecelerate);
              final word = _interval(620, 900, Curves.easeOut);
              final fade = 1 - _interval(_total - 250, _total, Curves.easeIn);
              return IgnorePointer(
                child: Opacity(
                  opacity: fade,
                  child: ColoredBox(
                    color: p.background,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Native splash also lays out on line: keep the mark centred.
                        EvensMark(split: split, line: math.max(line, 0)),
                        Positioned(
                          bottom: MediaQuery.paddingOf(context).bottom + 24,
                          child: Opacity(
                            opacity: word,
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - word)),
                              child: Text(
                                'Evens',
                                style: AppTypography.amountLarge.copyWith(
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
