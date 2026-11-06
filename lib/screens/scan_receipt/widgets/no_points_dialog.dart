import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/ad_modal.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';

/// Which feature ran out of points; picks the wording.
enum NoPointsFeature { scan, voice }

/// "Out of free scans" (or voice commands) sheet: Go Pro, watch a short ad for points, or type
/// the bill in by hand (always free).
class NoPointsDialog extends StatefulWidget {
  const NoPointsDialog({
    super.key,
    required this.onWatchAd,
    required this.requiredPoints,
    this.onTypeItIn,
    this.loadPlans,
    this.feature = NoPointsFeature.scan,
  });

  final NoPointsFeature feature;

  final Future<void> Function() onWatchAd;
  final int requiredPoints;

  /// Opens manual entry; when null, "Type it in instead" just closes.
  final VoidCallback? onTypeItIn;

  /// Plan source for the "from X a month" price; null reads RevenueCat.
  @visibleForTesting
  final Future<List<PaywallPlan>> Function()? loadPlans;

  static Future<void> show(
    BuildContext context, {
    required int requiredPoints,
    required Future<void> Function() onWatchAd,
    VoidCallback? onTypeItIn,
    NoPointsFeature feature = NoPointsFeature.scan,
  }) {
    return PremiumBottomSheet.show(
      context: context,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: NoPointsDialog(
        requiredPoints: requiredPoints,
        onWatchAd: onWatchAd,
        onTypeItIn: onTypeItIn,
        feature: feature,
      ),
    );
  }

  @override
  State<NoPointsDialog> createState() => _NoPointsDialogState();
}

class _NoPointsDialogState extends State<NoPointsDialog> {
  String? _fromPrice;

  @override
  void initState() {
    super.initState();
    _loadPrice();
  }

  Future<void> _loadPrice() async {
    try {
      final plans = widget.loadPlans != null
          ? await widget.loadPlans!()
          : PaywallPlan.fromPackages(
              await RevenueCatService.getPremiumPackages(),
            );
      final price = PaywallPlan.cheapestMonthly(plans);
      if (mounted && price != null) setState(() => _fromPrice = price);
    } catch (e) {
      debugPrint('No-points sheet price unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final navigator = Navigator.of(context);
    // The navigator's own context outlives this sheet, so follow-up
    // routes can open from it after the sheet closes.
    final hostContext = navigator.context;
    final voice = widget.feature == NoPointsFeature.voice;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            (voice ? 'pw_out_voice_title' : 'pw_out_title').tr(),
            style: AppTypography.headlineLarge.copyWith(color: p.textPrimary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (voice ? 'pw_out_voice_body' : 'pw_out_body').tr(
            namedArgs: {'points': widget.requiredPoints.toString()},
          ),
          style: AppTypography.bodyLarge.copyWith(
            color: p.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          key: const ValueKey('no-points-pro'),
          onPressed: () {
            AppHaptics.light();
            navigator.pop();
            PremiumModal.show(hostContext);
          },
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            foregroundColor: p.onAccent,
            minimumSize: const Size.fromHeight(54),
          ),
          child: Text(
            _fromPrice == null
                ? 'pw_out_go_pro'.tr()
                : 'pw_out_go_pro_from'.tr(namedArgs: {'price': _fromPrice!}),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const ValueKey('no-points-ad'),
          onPressed: () {
            navigator.pop();
            AdModal.show(hostContext, onWatchAd: widget.onWatchAd);
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
          ),
          child: Text('pw_out_watch_ad'.tr()),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: const ValueKey('no-points-manual'),
          onPressed: () {
            navigator.pop();
            widget.onTypeItIn?.call();
          },
          style: TextButton.styleFrom(
            foregroundColor: p.textPrimary,
            minimumSize: const Size.fromHeight(54),
          ),
          child: Text((voice ? 'pw_out_voice_tap' : 'pw_out_type_it').tr()),
        ),
      ],
    );
  }
}
