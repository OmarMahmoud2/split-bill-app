import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

/// "Rewarded ad, always optional" explainer shown before a rewarded ad.
///
/// Returns true when the person chose to watch (and [onWatchAd] ran), false
/// or null when they declined.
class AdModal extends StatelessWidget {
  const AdModal({super.key, required this.onWatchAd});

  final VoidCallback onWatchAd;

  static Future<bool?> show(
    BuildContext context, {
    required VoidCallback onWatchAd,
  }) {
    return PremiumBottomSheet.show<bool>(
      context: context,
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 20),
      child: AdModal(onWatchAd: onWatchAd),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'pw_ad_title'.tr(),
            style: AppTypography.headlineLarge.copyWith(color: p.textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'pw_ad_body'.tr(),
          style: AppTypography.bodyLarge.copyWith(
            color: p.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: p.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, size: 20, color: p.onAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'pw_ad_promise'.tr(),
                  style: AppTypography.bodyMedium.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          key: const ValueKey('ad-watch'),
          onPressed: () {
            AppHaptics.light();
            Navigator.of(context).pop(true);
            onWatchAd();
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('pw_ad_watch'.tr()),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const ValueKey('ad-not-now'),
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(foregroundColor: p.textPrimary),
          child: Text('pw_not_now'.tr()),
        ),
      ],
    );
  }
}
