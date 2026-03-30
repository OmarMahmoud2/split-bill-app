import 'package:flutter/material.dart';
import 'package:split_bill_app/widgets/ad_modal.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

class NoPointsDialog extends StatelessWidget {
  final Future<void> Function() onWatchAd;

  const NoPointsDialog({super.key, required this.onWatchAd});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function() onWatchAd,
  }) {
    return PremiumBottomSheet.show(
      context: context,
      child: NoPointsDialog(onWatchAd: onWatchAd),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.stars_rounded,
            size: 64,
            color: Colors.orange.shade400,
          ),
        ),

        const SizedBox(height: 24),

        // Title
        Text(
          'running_low_on_points',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
          textAlign: TextAlign.center,
        ).tr(),

        const SizedBox(height: 12),

        // Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'you_need_1_point_to_use_this_feature_nwatch_a_quick_ad_or_go_premium_to_continue',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ).tr(),
        ),

        const SizedBox(height: 40),

        // Options
        _buildPremiumOptions(context),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildPremiumOptions(BuildContext context) {
    return Column(
      children: [
        // Watch Ad Button
        GestureDetector(
          onTap: () async {
            Navigator.pop(context);
            await AdModal.show(context, onWatchAd: onWatchAd);
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade400,
                        Colors.deepPurple.shade600,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('watch_a_quick_ad',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ).tr(),
                      SizedBox(height: 4),
                      Text('plus_1_point_instantly',
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ).tr(),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Premium Button
        GestureDetector(
          onTap: () async {
            Navigator.pop(context);
            await PremiumModal.show(context);
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.diamond_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('split_bill_premium',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ).tr(),
                      SizedBox(height: 4),
                      Text('unlimited_scans_and_no_ads',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ).tr(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
