import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

/// "Reading receipt": a receipt-shaped skeleton whose lines appear one by
/// one under a scanning sweep, the usual wait, the privacy note and Cancel.
///
/// Under Reduce Motion every line is shown at once and nothing sweeps.
class ScanReadingView extends StatefulWidget {
  const ScanReadingView({
    super.key,
    required this.onCancel,
    this.image,
    this.titleKey = 'bf_scan_reading_title',
    this.subtitleKey = 'bf_scan_reading_eta',
    this.showPrivacyNote = true,
  });

  final VoidCallback? onCancel;

  /// Shown as a small thumbnail next to the title when present.
  final File? image;
  final String titleKey;
  final String subtitleKey;
  final bool showPrivacyNote;

  @override
  State<ScanReadingView> createState() => _ScanReadingViewState();
}

class _ScanReadingViewState extends State<ScanReadingView>
    with TickerProviderStateMixin {
  static const _lineWidths = [0.62, 0.48, 0.70, 0.40, 0.56, 0.36];

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  bool? _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = AppMotion.reduceMotion(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _reveal.value = 1;
      _sweep.stop();
    } else {
      _reveal.forward();
      _sweep.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _sweep.dispose();
    super.dispose();
  }

  Widget _line(int index, Widget child) {
    final start = (0.08 + index * 0.12).clamp(0.0, 0.9);
    final end = (start + 0.18).clamp(0.0, 1.0);
    final curve = CurvedAnimation(
      parent: _reveal,
      curve: Interval(start, end, curve: AppMotion.standard),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, c) => Opacity(
        opacity: curve.value,
        child: ClipRect(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: curve.value,
            child: c,
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lines = <Widget>[
      for (var i = 0; i < _lineWidths.length; i++)
        Row(
          children: [
            Expanded(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: _lineWidths[i],
                child: const Skeleton.line(height: 12),
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            const Skeleton.line(width: 44, height: 12),
          ],
        ),
    ];
    final totals = <Widget>[
      const Row(
        children: [
          Skeleton.line(width: 64, height: 12),
          Spacer(),
          Skeleton.line(width: 40, height: 12),
        ],
      ),
      const Row(
        children: [
          Skeleton.line(width: 88, height: 12),
          Spacer(),
          Skeleton.line(width: 40, height: 12),
        ],
      ),
    ];

    return Semantics(
      liveRegion: true,
      label: widget.titleKey.tr(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titleKey.tr(),
                          style: AppTypography.headlineMedium.copyWith(
                            fontSize: 24,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.subtitleKey.tr(),
                          style: AppTypography.bodyMedium.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.image != null)
                    ClipRRect(
                      borderRadius: AppRadii.rowRadius,
                      child: Image.file(
                        widget.image!,
                        width: 44,
                        height: 56,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SkeletonShimmer(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: AppRadii.cardRadius,
                    border: Border.all(color: p.border),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: Skeleton.line(width: 150)),
                          const SizedBox(height: 16),
                          for (var i = 0; i < lines.length; i++) ...[
                            _line(i, lines[i]),
                            const SizedBox(height: 12),
                          ],
                          Container(height: 1, color: p.border),
                          const SizedBox(height: 12),
                          for (var i = 0; i < totals.length; i++) ...[
                            _line(lines.length + i, totals[i]),
                            if (i < totals.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                      if (_reduced != true)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _sweep,
                              builder: (context, _) => Align(
                                alignment: Alignment(
                                  0,
                                  -0.9 +
                                      1.8 *
                                          AppMotion.standard.transform(
                                            _sweep.value,
                                          ),
                                ),
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: p.accent,
                                    boxShadow: [
                                      BoxShadow(
                                        color: p.accent.withValues(alpha: 0.45),
                                        blurRadius: 14,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) {
                  final step = (_reveal.value * 3).floor().clamp(0, 2);
                  return AnimatedSwitcher(
                    duration: AppMotion.durationFor(context, AppMotion.medium),
                    child: Row(
                      key: ValueKey(step),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(AppIcons.sparkle, size: 16, color: p.accent),
                        const SizedBox(width: 6),
                        Text(
                          'scanx_step_${step + 1}'.tr(),
                          style: AppTypography.labelLarge.copyWith(
                            color: p.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Spacer(),
              if (widget.showPrivacyNote) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.lock,
                      size: 14,
                      color: p.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'bf_scan_privacy_note'.tr(),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 13,
                          color: p.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (widget.onCancel != null)
                OutlinedButton(
                  onPressed: widget.onCancel,
                  child: Text('common_cancel'.tr()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
