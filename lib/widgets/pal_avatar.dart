import 'package:flutter/material.dart';
import 'package:split_bill_app/utils/image_utils.dart';

/// Every person gets a "pal": the photo when there is one, else a friendly
/// face drawn from a stable seed (docs/2.0/PREMIUM_POLISH.md, "Pal avatars").
///
/// [seed] should be the user id, else the lowercased name. The same seed
/// always yields the same pal on every device, including the guest web.
class PalAvatar extends StatelessWidget {
  const PalAvatar({
    super.key,
    required this.seed,
    this.name,
    this.photoUrl,
    this.size = 44,
    this.ringColor,
  });

  final String seed;
  final String? name;
  final String? photoUrl;
  final double size;

  /// Optional 2.5 px ring: mint for "you"/selected, surface for stacks.
  final Color? ringColor;

  static const double ringWidth = 2.5;

  /// (background, foreground) pairs: mint, coral, sky, sun, lilac, rose,
  /// ocean, peach.
  static const List<(Color, Color)> pairs = [
    (Color(0xFFC9F2EA), Color(0xFF0E7C72)),
    (Color(0xFFFFD8CC), Color(0xFFE8664A)),
    (Color(0xFFD8E3FF), Color(0xFF3B6FE0)),
    (Color(0xFFFFE7A8), Color(0xFFC98A1E)),
    (Color(0xFFE7DBFF), Color(0xFF7C5CE0)),
    (Color(0xFFFFD6E4), Color(0xFFD84C7E)),
    (Color(0xFFCDEFFF), Color(0xFF1E88B4)),
    (Color(0xFFFFE2C2), Color(0xFFD9741E)),
  ];

  /// FNV-1a over UTF-16 code units: stable across platforms and runs
  /// (unlike [String.hashCode]).
  static int hashSeed(String seed) {
    var h = 0x811c9dc5;
    for (final unit in seed.codeUnits) {
      h = ((h ^ unit) * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// Colour pair index for [seed].
  static int pairIndex(String seed) => hashSeed(seed) % pairs.length;

  /// Hair variant (0 cap, 1 bun, 2 tuft) for [seed].
  /// Uses the hash bits above the colour index so colour and hair vary
  /// independently (24 looks, not 6).
  static int hairVariant(String seed) => (hashSeed(seed) ~/ pairs.length) % 3;

  /// Guests get a new id on every bill; seed them by name so "Sara" looks
  /// the same on every bill, in the app and on the guest web.
  String get _effectiveSeed {
    final n = name?.trim().toLowerCase() ?? '';
    return seed.startsWith('guest_') && n.isNotEmpty ? n : seed;
  }

  @override
  Widget build(BuildContext context) {
    final key = _effectiveSeed;
    final pal = CustomPaint(
      size: Size.square(size),
      painter: _PalPainter(pair: pairs[pairIndex(key)], hair: hairVariant(key)),
    );
    final url = photoUrl?.trim() ?? '';
    final image = url.isEmpty ? null : ImageUtils.getAvatarImage(url);
    Widget avatar = SizedBox.square(
      dimension: size,
      child: image == null
          ? pal
          : ClipOval(
              child: Image(
                image: image,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, _, _) => pal,
              ),
            ),
    );
    if (ringColor != null) {
      avatar = Container(
        padding: const EdgeInsets.all(ringWidth),
        decoration: BoxDecoration(shape: BoxShape.circle, color: ringColor),
        child: avatar,
      );
    }
    return Semantics(
      label: name,
      image: true,
      excludeSemantics: true,
      child: avatar,
    );
  }
}

class _PalPainter extends CustomPainter {
  _PalPainter({required this.pair, required this.hair});

  final (Color, Color) pair;
  final int hair;

  // Path data from the spec, in a 48x48 box.
  static final Path _shoulders = _parse(
    'M8 48c1.5-9 8-13.5 16-13.5S38.5 39 40 48z',
  );
  static final List<Path> _hair = [
    _parse(
      'M13.6 20.5c0-6.6 4.7-10.6 10.4-10.6s10.4 4 10.4 10.6c-3.2-2.6-6.6-3.6-10.4-3.6s-7.2 1-10.4 3.6z',
    ),
    _parse(
      'M13.6 21c.6-6.4 5-10.1 10.4-10.1 5.2 0 9.4 3.4 10.3 9.2-4.6-.4-9.4-2.4-12.4-5.6-1.8 3.2-4.6 5.4-8.3 6.5z',
    ),
    _parse('M15 17l3-6 2.6 4 3.4-6 3.2 6 2.8-4 3 6c-3-1.4-6-2-9-2s-6 .6-9 2z'),
  ];
  static final Path _smile = _parse('M20.6 26.6c1.9 1.9 4.9 1.9 6.8 0');

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48;
    canvas.save();
    canvas.scale(s);
    final (bg, fg) = pair;
    canvas.drawCircle(const Offset(24, 24), 24, Paint()..color = bg);
    canvas.save();
    canvas.clipPath(Path()..addOval(const Rect.fromLTWH(0, 0, 48, 48)));
    final fill = Paint()..color = fg;
    canvas.drawPath(_shoulders, fill);
    canvas.drawCircle(
      const Offset(24, 22),
      10.5,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.drawPath(_hair[hair], fill);
    if (hair == 1) canvas.drawCircle(const Offset(33.5, 12.5), 4.6, fill);
    canvas.restore();
    final inkFill = Paint()..color = const Color(0xFF0E1526);
    canvas.drawCircle(const Offset(20.2, 22.6), 1.35, inkFill);
    canvas.drawCircle(const Offset(27.8, 22.6), 1.35, inkFill);
    canvas.drawPath(
      _smile,
      Paint()
        ..color = const Color(0xFF0E1526)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PalPainter old) => old.pair != pair || old.hair != hair;

  /// Minimal SVG path parser for the commands the pal uses
  /// (M m L l C c S s z, absolute and relative).
  static Path _parse(String d) {
    final path = Path();
    final tokens = RegExp(
      r'[a-zA-Z]|-?\d*\.?\d+',
    ).allMatches(d).map((m) => m[0]!).toList();
    var i = 0;
    var cx = 0.0, cy = 0.0, sx = 0.0, sy = 0.0;
    var lastCx = 0.0, lastCy = 0.0; // last cubic control point, for S
    var prevCubic = false;
    String cmd = 'M';
    double n() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      if (RegExp(r'[a-zA-Z]').hasMatch(tokens[i])) cmd = tokens[i++];
      final rel = cmd == cmd.toLowerCase();
      final up = cmd.toUpperCase();
      final ox = rel ? cx : 0.0, oy = rel ? cy : 0.0;
      switch (up) {
        case 'M':
          cx = ox + n();
          cy = oy + n();
          sx = cx;
          sy = cy;
          path.moveTo(cx, cy);
          cmd = rel ? 'l' : 'L'; // implicit lineto after moveto
          prevCubic = false;
        case 'L':
          cx = ox + n();
          cy = oy + n();
          path.lineTo(cx, cy);
          prevCubic = false;
        case 'C':
          final x1 = ox + n(), y1 = oy + n();
          final x2 = ox + n(), y2 = oy + n();
          final x = ox + n(), y = oy + n();
          path.cubicTo(x1, y1, x2, y2, x, y);
          lastCx = x2;
          lastCy = y2;
          cx = x;
          cy = y;
          prevCubic = true;
        case 'S':
          final x1 = prevCubic ? 2 * cx - lastCx : cx;
          final y1 = prevCubic ? 2 * cy - lastCy : cy;
          final x2 = ox + n(), y2 = oy + n();
          final x = ox + n(), y = oy + n();
          path.cubicTo(x1, y1, x2, y2, x, y);
          lastCx = x2;
          lastCy = y2;
          cx = x;
          cy = y;
          prevCubic = true;
        case 'Z':
          path.close();
          cx = sx;
          cy = sy;
          prevCubic = false;
        default:
          throw FormatException('Unsupported path command $cmd');
      }
    }
    return path;
  }
}
