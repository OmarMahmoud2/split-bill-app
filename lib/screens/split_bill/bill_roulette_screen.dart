import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:split_bill_app/bill_flow/voice/voice_logic.dart'
    show firstNameOf;
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';

/// Bill roulette (Split.dc.html, third board). Pops the winner's id when
/// the host confirms "Ali pays", or null.
class BillRouletteScreen extends StatefulWidget {
  const BillRouletteScreen({
    super.key,
    required this.participants,
    required this.totalMinor,
    required this.currency,
    this.random,
  });

  /// Legacy participant maps (`id`, `name`).
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

class _BillRouletteScreenState extends State<BillRouletteScreen> {
  final _selected = StreamController<int>.broadcast();
  late final math.Random _random = widget.random ?? math.Random();
  int? _winner;
  bool _spinning = false;

  @override
  void dispose() {
    _selected.close();
    super.dispose();
  }

  void _spin() {
    if (_spinning) return;
    AppHaptics.light();
    final index = _random.nextInt(widget.participants.length);
    setState(() {
      _spinning = true;
      _winner = null;
    });
    _selected.add(index);
    // onAnimationEnd reports the end; keep a fallback for reduce motion.
    Future.delayed(_duration + const Duration(milliseconds: 100), () {
      if (mounted && _spinning) _land(index);
    });
    _pending = index;
  }

  int? _pending;

  void _land(int index) {
    AppHaptics.success();
    setState(() {
      _spinning = false;
      _winner = index;
    });
  }

  Duration get _duration => AppMotion.reduceMotion(context)
      ? const Duration(milliseconds: 150)
      : const Duration(milliseconds: 2600);

  // First names fit the wheel and the button ("Omar pays", not "Omar Mahmo…").
  String _name(int i) {
    final first = firstNameOf(widget.participants[i]['name']);
    return first.isEmpty ? '?' : first;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final amount = formatMoneyMinor(widget.totalMinor, widget.currency);
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
                child: IconButton(
                  tooltip: 'bf_roulette_close'.tr(),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: p.surface,
                    side: BorderSide(color: p.hairline),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: p.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'bf_roulette_title'.tr(namedArgs: {'amount': amount}),
                textAlign: TextAlign.center,
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 26,
                  color: p.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 280,
              height: 280,
              child: ExcludeSemantics(
                child: FortuneWheel(
                  selected: _selected.stream,
                  animateFirst: false,
                  duration: _duration,
                  onAnimationEnd: () {
                    final i = _pending;
                    if (_spinning && i != null) _land(i);
                  },
                  indicators: [
                    FortuneIndicator(
                      alignment: Alignment.topCenter,
                      child: TriangleIndicator(color: p.textPrimary),
                    ),
                  ],
                  items: [
                    for (var i = 0; i < widget.participants.length; i++)
                      FortuneItem(
                        style: FortuneItemStyle(
                          // By position so neighbouring slices never share a tint.
                          color: p.avatarTints[i % p.avatarTints.length],
                          borderColor: p.surface,
                          borderWidth: 2,
                          textStyle: AppTypography.titleSmall.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: p.textPrimary,
                          ),
                        ),
                        child: Text(_name(i)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _winner == null
                      ? 'bf_roulette_caption'.tr()
                      : 'bf_roulette_landed'.tr(
                          namedArgs: {'name': _name(_winner!)},
                        ),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    fontSize: 15,
                    color: p.textSecondary,
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 16),
              child: _winner == null
                  ? AssignPillButton(
                      key: const ValueKey('roulette_spin'),
                      label: 'bf_roulette_spin'.tr(),
                      onPressed: _spinning ? null : _spin,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: AssignPillButton(
                            key: const ValueKey('roulette_again'),
                            label: 'bf_roulette_spin_again'.tr(),
                            secondary: true,
                            onPressed: _spin,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AssignPillButton(
                            key: const ValueKey('roulette_confirm'),
                            label: 'bf_roulette_pays'.tr(
                              namedArgs: {'name': _name(_winner!)},
                            ),
                            onPressed: () => Navigator.of(context).pop(
                              (widget.participants[_winner!]['id'] ?? '')
                                  .toString(),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
