import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// Paper colours of the receipt. The paper stays light in dark mode, so its
/// ink is fixed too (these are the only non-palette colours of the paywall).
const Color _paperDark = Color(0xFFF4F6F5);
const Color _ink = Color(0xFF2B3330);
const Color _muted = Color(0xFF75807B);
const Color _rule = Color(0xFFC6CECA);
const Color _teal = Color(0xFF0F766E);

const double _toothWidth = 12;
const double _toothHeight = 8;

const _mono = 'IBMPlexMono';

/// Receipt of Pro perks: torn zigzag bottom edge, dotted leaders, a print
/// reveal (~700 ms, top-down, stepped) and then staggered lines. With Reduce
/// Motion everything is simply there.
class PaywallReceipt extends StatefulWidget {
  const PaywallReceipt({super.key});

  @override
  State<PaywallReceipt> createState() => _PaywallReceiptState();
}

class _PaywallReceiptState extends State<PaywallReceipt>
    with SingleTickerProviderStateMixin {
  static const _reveal = Duration(milliseconds: 700);
  static const _stagger = Duration(milliseconds: 70);
  static const _lineDuration = Duration(milliseconds: 300);
  static const _lineCount = 6; // five perks and the free note
  static final _total = _reveal + _stagger * (_lineCount - 1) + _lineDuration;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _total,
  );
  bool _started = false;

  static const _perks = [
    ('pw_receipt_scans', 'pw_value_unlimited'),
    ('pw_receipt_voice', 'pw_value_unlimited'),
    ('pw_receipt_recurring', 'pw_value_included'),
    ('pw_receipt_export', 'pw_value_included'),
    ('pw_receipt_ads', 'pw_value_none'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _interval(Duration start, Duration length, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          start.inMicroseconds / _total.inMicroseconds,
          (start + length).inMicroseconds / _total.inMicroseconds,
          curve: curve,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final paper = p.isDark ? _paperDark : p.surface;
    final head = TextStyle(
      fontFamily: _mono,
      fontSize: 12.5,
      height: 1.6,
      color: _muted,
    );
    final line = TextStyle(
      fontFamily: _mono,
      fontSize: 14,
      height: 1.7,
      color: _ink,
    );
    final reveal = _interval(Duration.zero, _reveal, const _Steps(14));

    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        20,
        18,
        20,
        22 + _toothHeight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('pw_receipt_title'.tr(), style: head),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'pw_receipt_sub'.tr(),
                    style: head,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _perks.length; i++)
            _fadeIn(
              _interval(_reveal + _stagger * i, _lineDuration, Curves.easeOut),
              _PerkLine(
                label: _perks[i].$1.tr(),
                value: _perks[i].$2.tr(),
                style: line,
                paper: paper,
              ),
            ),
          const SizedBox(height: 10),
          _fadeIn(
            _interval(
              _reveal + _stagger * _perks.length,
              _lineDuration,
              Curves.easeOut,
            ),
            CustomPaint(
              painter: _DashedRulePainter(),
              child: Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Text(
                  'pw_receipt_free'.tr(),
                  key: const ValueKey('paywall-receipt-free'),
                  style: head.copyWith(height: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: reveal,
      builder: (context, child) =>
          ClipRect(clipper: _RevealClipper(reveal.value), child: child),
      child: CustomPaint(
        painter: _PaperPainter(color: paper, shadow: p.shadow),
        child: ClipPath(clipper: const _TornClipper(), child: content),
      ),
    );
  }

  Widget _fadeIn(Animation<double> a, Widget child) => FadeTransition(
    opacity: a,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(a),
      child: child,
    ),
  );
}

/// One perk: label ... value, the dotted leader sits behind both.
class _PerkLine extends StatelessWidget {
  const _PerkLine({
    required this.label,
    required this.value,
    required this.style,
    required this.paper,
  });

  final String label;
  final String value;
  final TextStyle style;
  final Color paper;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    return MergeSemantics(
      child: Stack(
        alignment: AlignmentDirectional.bottomStart,
        children: [
          Positioned.directional(
            textDirection: Directionality.of(context),
            start: 0,
            end: 0,
            bottom: scaler.scale(style.fontSize! * style.height! * 0.28),
            child: const ExcludeSemantics(
              child: SizedBox(
                height: 2,
                child: CustomPaint(painter: _DottedLeaderPainter()),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: ColoredBox(
                  color: paper,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: Text(label, style: style),
                  ),
                ),
              ),
              ColoredBox(
                color: paper,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Text(
                    value,
                    style: style.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _teal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stepped easing: the print head moves in [steps] jumps.
class _Steps extends Curve {
  const _Steps(this.steps);
  final int steps;
  @override
  double transformInternal(double t) => (t * steps).ceil() / steps;
}

class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    -24,
    -24,
    size.width + 48,
    size.height * progress + 24 + (progress >= 1 ? 24 : 0),
  );

  @override
  bool shouldReclip(_RevealClipper old) => old.progress != progress;
}

Path _tornPath(Size size) {
  final body = size.height - _toothHeight;
  final path = Path()..moveTo(0, 0);
  path.lineTo(size.width, 0);
  path.lineTo(size.width, body);
  final teeth = (size.width / _toothWidth).ceil();
  final w = size.width / teeth;
  for (var i = 0; i < teeth; i++) {
    final x = size.width - i * w;
    path.lineTo(x - w / 2, body + _toothHeight);
    path.lineTo(x - w, body);
  }
  path.close();
  return path;
}

class _TornClipper extends CustomClipper<Path> {
  const _TornClipper();
  @override
  Path getClip(Size size) => _tornPath(size);
  @override
  bool shouldReclip(_TornClipper old) => false;
}

class _PaperPainter extends CustomPainter {
  const _PaperPainter({required this.color, required this.shadow});
  final Color color;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _tornPath(size);
    canvas.drawShadow(path, shadow, 6, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.color != color || old.shadow != shadow;
}

class _DottedLeaderPainter extends CustomPainter {
  const _DottedLeaderPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _rule;
    for (var x = 0.75; x < size.width; x += 4) {
      canvas.drawCircle(Offset(x, size.height / 2), 0.9, paint);
    }
  }

  @override
  bool shouldRepaint(_DottedLeaderPainter old) => false;
}

class _DashedRulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _rule
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + 4, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedRulePainter old) => false;
}
