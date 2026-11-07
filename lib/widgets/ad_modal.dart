import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';

/// "Rewarded ad, always optional" offer shown before a rewarded ad: what you
/// get, how many ads are left today (of the daily cap) and a quiet decline.
///
/// Returns true when the person chose to watch (and [onWatchAd] ran), false
/// or null when they declined.
class AdModal extends StatefulWidget {
  const AdModal({super.key, required this.onWatchAd, this.watchedToday});

  final VoidCallback onWatchAd;

  /// Test hook: ads already watched today; null reads the device counter.
  final int? watchedToday;

  static Future<bool?> show(
    BuildContext context, {
    required VoidCallback onWatchAd,
    @visibleForTesting int? watchedToday,
  }) {
    return showLedgerSheet<bool>(
      context,
      showClose: false,
      builder: (_) => AdModal(onWatchAd: onWatchAd, watchedToday: watchedToday),
    );
  }

  @override
  State<AdModal> createState() => _AdModalState();
}

class _AdModalState extends State<AdModal> {
  int _watched = 0;

  @override
  void initState() {
    super.initState();
    final injected = widget.watchedToday;
    if (injected != null) {
      _watched = injected;
    } else {
      RewardedAdHelper.watchedToday().then((n) {
        if (mounted) setState(() => _watched = n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const cap = RewardedAdHelper.dailyCap;
    final left = (cap - _watched).clamp(0, cap);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.skySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(AppIcons.play, size: 22, color: p.sky),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'pw_ad_title'.tr(),
                    style: AppTypography.headlineMedium.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'pw_ad_offer'.tr(namedArgs: {'left': '$left'}),
            key: const ValueKey('ad-offer'),
            style: AppTypography.titleMedium.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < cap; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < _watched ? p.accent : p.hairline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'pw_ad_promise'.tr(),
            style: AppTypography.bodyMedium.copyWith(
              color: p.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('ad-watch'),
            onPressed: left == 0
                ? null
                : () {
                    AppHaptics.light();
                    Navigator.of(context).pop(true);
                    widget.onWatchAd();
                  },
            icon: const Icon(AppIcons.play),
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
      ),
    );
  }
}
