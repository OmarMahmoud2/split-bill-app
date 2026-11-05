import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/paywall/paywall_text.dart';
import 'package:url_launcher/url_launcher.dart';

/// Subscription terms shown before purchase (App Store 3.1.2, Play
/// subscriptions policy): price, billing period, free trial, auto-renewal,
/// how to cancel, plus Terms, Privacy and (optionally) Restore links.
class SubscriptionLegalDisclosure extends StatelessWidget {
  const SubscriptionLegalDisclosure({
    super.key,
    required this.package,
    this.dark = false,
  }) : plan = null,
       onRestore = null;

  /// From a mapped paywall [plan]; [onRestore] adds a "Restore" link.
  const SubscriptionLegalDisclosure.plan({
    super.key,
    required PaywallPlan this.plan,
    this.onRestore,
  }) : package = null,
       dark = false;

  final Package? package;
  final PaywallPlan? plan;
  final VoidCallback? onRestore;

  /// Ignored since v3; kept so older call sites compile.
  final bool dark;

  List<String> _lines() {
    final store = paywallStoreName();
    final mapped =
        plan ?? (package == null ? null : PaywallPlan.fromPackage(package!));
    if (mapped != null) {
      return [for (final c in mapped.legal(store: store)) paywallText(c)];
    }
    final pkg = package;
    if (pkg == null) return ['subscription_details_loading'.tr()];
    final title = pkg.storeProduct.title.trim().isEmpty
        ? 'go_premium'.tr()
        : pkg.storeProduct.title.trim();
    return [
      'subscription_auto_renew_disclosure'.tr(
        namedArgs: {
          'title': title,
          'price': pkg.storeProduct.priceString,
          'period': 'subscription_period_billing_period'.tr(),
        },
      ),
      'pw_legal_cancel'.tr(namedArgs: {'store': store}),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = AppTypography.labelSmall.copyWith(
      color: p.textSecondary,
      fontWeight: FontWeight.w400,
      height: 1.5,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _lines().join(' '),
          key: const ValueKey('paywall-legal'),
          textAlign: TextAlign.center,
          style: style,
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _LegalLink(
              label: 'pw_link_terms'.tr(),
              onTap: () => _open(context, AppLinks.termsOfUseUrl),
            ),
            _Dot(style: style),
            _LegalLink(
              label: 'pw_link_privacy'.tr(),
              onTap: () => _open(context, AppLinks.privacyPolicyUrl),
            ),
            if (onRestore != null) ...[
              _Dot(style: style),
              _LegalLink(
                key: const ValueKey('paywall-restore'),
                label: 'pw_link_restore'.tr(),
                onTap: onRestore!,
              ),
            ],
          ],
        ),
      ],
    );
  }

  static Future<void> _open(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      AppToast.show(
        context,
        message: 'could_not_open_legal_link'.tr(),
        type: AppToastType.error,
      );
    }
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.style});
  final TextStyle style;

  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: Text('·', style: style));
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: p.textPrimary,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: AppTypography.labelSmall.copyWith(
          decoration: TextDecoration.underline,
        ),
      ),
      child: Text(label),
    );
  }
}
