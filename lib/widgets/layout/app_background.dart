import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// The canvas with two or three huge, very soft colour orbs (mint, sky and a
/// touch of coral) behind [child].
///
/// Cheap by design: each orb is one pre-faded [RadialGradient] (no blur
/// filter), painted once inside a [RepaintBoundary]. Put it under a
/// transparent Scaffold, or under tab pages.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, this.child, this.enabled = true});

  /// False when a parent already paints the background (tab pages).
  final bool enabled;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child ?? const SizedBox.shrink();
    final p = context.palette;
    return ColoredBox(
      color: p.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _OrbPainter(
                    mint: p.accent,
                    sky: p.sky,
                    coral: p.coral,
                    dark: p.isDark,
                  ),
                ),
              ),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  const _OrbPainter({
    required this.mint,
    required this.sky,
    required this.coral,
    required this.dark,
  });

  final Color mint;
  final Color sky;
  final Color coral;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = (w < h ? w : h) * 0.9;
    void orb(Offset c, double radius, Color color, double alpha) {
      final rect = Rect.fromCircle(center: c, radius: radius);
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }

    orb(Offset(w * 0.05, h * 0.02), r, mint, dark ? 0.16 : 0.13);
    orb(Offset(w * 0.98, h * 0.12), r * 0.85, sky, dark ? 0.15 : 0.12);
    orb(Offset(w * 0.55, h * 0.58), r * 0.8, coral, dark ? 0.1 : 0.08);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
      old.mint != mint ||
      old.sky != sky ||
      old.coral != coral ||
      old.dark != dark;
}
