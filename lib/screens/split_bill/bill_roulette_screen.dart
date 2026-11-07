import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/bill_flow/voice/voice_logic.dart'
    show firstNameOf;
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/utils/plural_text.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';

/// Slice under the top pointer when the wheel has turned [rotation] radians
/// clockwise. Slice `i` spans `[i, i + 1) * 2π / count` clockwise from the top.
int rouletteIndexAt(double rotation, int count) {
  final step = 2 * math.pi / count;
  final under = (2 * math.pi - rotation % (2 * math.pi)) % (2 * math.pi);
  return (under / step).floor().clamp(0, count - 1);
}

/// Rotation (radians, > [from]) that stops with the pointer inside slice
/// [index], [fraction] (0..1) of the way across it, after [turns] full turns.
double rouletteTargetRotation({
  required double from,
  required int index,
  required int count,
  required double fraction,
  int turns = 5,
}) {
  final step = 2 * math.pi / count;
  final under = (index + fraction) * step;
  final stop = (2 * math.pi - under) % (2 * math.pi);
  final base = from - from % (2 * math.pi);
  var target = base + stop;
  if (target <= from) target += 2 * math.pi;
  return target + turns * 2 * math.pi;
}

/// Bill roulette (Roulette.dc.html). Pops the winner's id when the host taps
/// "Make it official", or null.
class BillRouletteScreen extends StatefulWidget {
  const BillRouletteScreen({
    super.key,
    required this.participants,
    required this.totalMinor,
    required this.currency,
    this.random,
  });

  /// Legacy participant maps (`id`, `name`, `photoUrl`, `isHost`).
  final List<Map<String, dynamic>> participants;
  final int totalMinor;
  final String currency;

  /// Test hook.
  final math.Random? random;

  static Future<String?> open(
    BuildContext context, {
    required List<Map<String, dynamic>> participants,
    required int totalMinor,
    required String currency,
  }) => Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BillRouletteScreen(
        participants: participants,
        totalMinor: totalMinor,
        currency: currency,
      ),
    ),
  );

  @override
  State<BillRouletteScreen> createState() => _BillRouletteScreenState();
}

// The game board is always dark, in light mode too (see the mockup).
const _bg = Color(0xFF0A0F1C);
const _panel = Color(0xFF121A2B);
const _line = Color(0xFF22304A);
const _mint = Color(0xFF34D7C0);
const _muted = Color(0xFF9AA4B8);
const _sliceColors = [
  Color(0xFFFF8A70),
  Color(0xFFB9A4FF),
  Color(0xFFFFD36B),
  Color(0xFFFF9EC0),
  Color(0xFF7AA2FF),
  Color(0xFF34D7C0),
];

class _BillRouletteScreenState extends State<BillRouletteScreen>
    with SingleTickerProviderStateMixin {
  late final math.Random _random = widget.random ?? math.Random();
  late final AnimationController _anim = AnimationController(vsync: this);
  double _from = 0;
  double _to = 0;
  double _rotation = 0;
  int _lastTick = 0;
  int? _winner;
  bool _spinning = false;
  bool _leaveMeOut = false;

  /// Everyone on the wheel (the host steps out with "Leave me out").
  List<Map<String, dynamic>> get _people {
    if (!_leaveMeOut) return widget.participants;
    final rest = widget.participants.where((p) => p['isHost'] != true).toList();
    return rest.length >= 2 ? rest : widget.participants;
  }

  bool get _hasHost => widget.participants.any((p) => p['isHost'] == true);

  @override
  void initState() {
    super.initState();
    _anim.addListener(_onTick);
    _anim.addStatusListener((s) {
      if (s == AnimationStatus.completed && _spinning) _land();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onTick() {
    final t = Curves.easeOutCubic.transform(_anim.value);
    final rot = _from + (_to - _from) * t;
    final slice = (rot / (2 * math.pi / _people.length)).floor();
    if (slice != _lastTick) {
      _lastTick = slice;
      AppHaptics.tick();
    }
    setState(() => _rotation = rot);
  }

  void _spin() {
    if (_spinning) return;
    AppHaptics.light();
    final n = _people.length;
    _from = _rotation;
    _to = rouletteTargetRotation(
      from: _from,
      index: _random.nextInt(n),
      count: n,
      // Stay clear of slice borders so the pointer is never ambiguous.
      fraction: 0.15 + _random.nextDouble() * 0.7,
    );
    _lastTick = (_from / (2 * math.pi / n)).floor();
    setState(() {
      _spinning = true;
      _winner = null;
    });
    _anim.duration = AppMotion.reduceMotion(context)
        ? const Duration(milliseconds: 150)
        : const Duration(milliseconds: 3500);
    _anim.forward(from: 0);
  }

  void _land() {
    AppHaptics.heavy();
    setState(() {
      _spinning = false;
      _winner = rouletteIndexAt(_rotation, _people.length);
    });
  }

  void _toggleLeaveOut() {
    if (_spinning) return;
    setState(() {
      _leaveMeOut = !_leaveMeOut;
      _winner = null;
      _rotation = 0;
    });
  }

  // First names fit the wheel and the button ("Omar pays", not "Omar Mahmo…").
  String _name(Map<String, dynamic> person) {
    final first = firstNameOf(person['name']);
    return first.isEmpty ? '?' : first;
  }

  String _seed(Map<String, dynamic> person) =>
      (person['id'] ?? person['name'] ?? '').toString().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final amount = formatMoneyMinor(widget.totalMinor, widget.currency);
    final people = _people;
    final winner = _winner == null ? null : people[_winner!];
    // Always-dark board: light status bar in both app themes.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: AdaptiveBody.form(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          12,
                          20,
                          0,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'bf_roulette_close'.tr(),
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 44,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: _panel,
                                side: const BorderSide(color: _line),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                AppIcons.close,
                                color: Colors.white,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'bf_roulette_title'.tr(
                                  namedArgs: {'amount': amount},
                                ),
                                textAlign: TextAlign.center,
                                style: AppTypography.headlineMedium.copyWith(
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 44),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _Wheel(
                        rotation: _rotation,
                        people: people,
                        nameOf: _name,
                        seedOf: _seed,
                        hub: _spinning ? '…' : 'bf_roulette_spin'.tr(),
                        onHub: _spinning ? null : _spin,
                      ),
                      const SizedBox(height: 24),
                      Semantics(
                        liveRegion: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: winner == null
                              ? Text(
                                  _spinning
                                      ? 'bf_roulette_spinning'.tr()
                                      : 'bf_roulette_caption'.tr(),
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: _muted,
                                  ),
                                )
                              : _ResultCard(
                                  name: _name(winner),
                                  seed: _seed(winner),
                                  photoUrl: winner['photoUrl']?.toString(),
                                  amount: amount,
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _Chip(
                            label: pluralText(
                              'bf_roulette_people_in',
                              people.length,
                            ),
                            selected: true,
                          ),
                          if (_hasHost)
                            _Chip(
                              key: const ValueKey('roulette_leave_out'),
                              label: 'bf_roulette_leave_me_out'.tr(),
                              selected: _leaveMeOut,
                              onTap: _toggleLeaveOut,
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          20,
                          0,
                          20,
                          16,
                        ),
                        child: winner == null
                            ? _RouletteButton(
                                key: const ValueKey('roulette_spin'),
                                label: _spinning
                                    ? 'bf_roulette_good_luck'.tr()
                                    : 'bf_roulette_spin_wheel'.tr(),
                                onPressed: _spinning ? null : _spin,
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _RouletteButton(
                                      key: const ValueKey('roulette_again'),
                                      label: 'bf_roulette_spin_again'.tr(),
                                      secondary: true,
                                      onPressed: _spin,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: _RouletteButton(
                                      key: const ValueKey('roulette_confirm'),
                                      label: 'bf_roulette_make_official'.tr(),
                                      onPressed: () => Navigator.of(
                                        context,
                                      ).pop((winner['id'] ?? '').toString()),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.rotation,
    required this.people,
    required this.nameOf,
    required this.seedOf,
    required this.hub,
    required this.onHub,
  });

  final double rotation;
  final List<Map<String, dynamic>> people;
  final String Function(Map<String, dynamic>) nameOf;
  final String Function(Map<String, dynamic>) seedOf;
  final String hub;
  final VoidCallback? onHub;

  static const double size = 300;

  @override
  Widget build(BuildContext context) {
    final n = people.length;
    final step = 2 * math.pi / n;
    // Hide avatars when slices get too narrow for them.
    final avatar = n > 8 ? 0.0 : 30.0;
    return SizedBox(
      width: size + 24,
      height: size + 24,
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size + 16,
              height: size + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _panel,
                border: Border.all(color: _line, width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x2634D7C0), blurRadius: 40),
                ],
              ),
            ),
            Transform.rotate(
              angle: rotation,
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(size),
                      painter: _WheelPainter(n),
                    ),
                    for (var i = 0; i < n; i++)
                      Transform.rotate(
                        angle: (i + 0.5) * step,
                        child: Transform.translate(
                          offset: const Offset(0, -size * 0.32),
                          // Undo the slice angle and the wheel's spin so
                          // names and faces stay upright while it turns.
                          child: Transform.rotate(
                            angle: -(i + 0.5) * step - rotation,
                            child: SizedBox(
                              width: 70,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (avatar > 0)
                                    PalAvatar(
                                      seed: seedOf(people[i]),
                                      name: nameOf(people[i]),
                                      photoUrl: people[i]['photoUrl']
                                          ?.toString(),
                                      size: avatar,
                                      ringColor: Colors.white,
                                    ),
                                  Text(
                                    nameOf(people[i]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.titleSmall.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0E1526),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: onHub,
              child: Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _bg,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Text(
                  hub,
                  style: AppTypography.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 0,
              child: CustomPaint(
                size: Size(26, 26),
                painter: _PointerPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.count);
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final step = 2 * math.pi / count;
    for (var i = 0; i < count; i++) {
      // -π/2: slice 0 starts at the top and runs clockwise.
      final start = -math.pi / 2 + i * step;
      canvas.drawArc(
        rect,
        start,
        step,
        true,
        Paint()..color = _sliceColors[i % _sliceColors.length],
      );
      canvas.drawArc(
        rect,
        start,
        step,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = _bg,
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.count != count;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, true);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PointerPainter old) => false;
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.name,
    required this.seed,
    required this.photoUrl,
    required this.amount,
  });

  final String name;
  final String seed;
  final String? photoUrl;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _mint.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          PalAvatar(
            seed: seed,
            name: name,
            photoUrl: photoUrl,
            size: 48,
            ringColor: _mint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'bf_roulette_card_title'.tr(namedArgs: {'name': name}),
                  style: AppTypography.titleMedium.copyWith(
                    color: Colors.white,
                    fontFamily: AppTypography.displayFamily,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'bf_roulette_card_body'.tr(
                    namedArgs: {'amount': amount, 'name': name},
                  ),
                  style: AppTypography.bodySmall.copyWith(color: _muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                AppHaptics.selection();
                onTap!();
              },
        child: Container(
          // Sized by padding (12 + 20 line ≈ 44 pt): `alignment` would make
          // the pill fill the whole row.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? _mint.withValues(alpha: 0.14) : _panel,
            border: Border.all(color: selected ? _mint : _line),
          ),
          child: Text(
            label,
            style: AppTypography.labelLarge.copyWith(
              color: selected ? _mint : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Mint pill on the dark board (the themed button turns ink in light mode).
class _RouletteButton extends StatelessWidget {
  const _RouletteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: secondary
              ? _panel
              : enabled
              ? _mint
              : _mint.withValues(alpha: 0.4),
          border: secondary ? Border.all(color: _line, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: secondary ? Colors.white : const Color(0xFF06231F),
          ),
        ),
      ),
    );
  }
}
