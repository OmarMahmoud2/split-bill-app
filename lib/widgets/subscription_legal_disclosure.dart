import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionLegalDisclosure extends StatelessWidget {
  const SubscriptionLegalDisclosure({
    super.key,
    required this.package,
    this.dark = false,
  });

  final Package? package;
  final bool dark;

  bool get _isSubscription {
    if (package?.storeProduct.subscriptionPeriod != null) return true;

    final type = package?.packageType;
    return type != null &&
        type != PackageType.lifetime &&
        type != PackageType.unknown &&
        type != PackageType.custom;
  }

  @override
  Widget build(BuildContext context) {
    final package = this.package;
    final foreground = dark ? Colors.white : const Color(0xFF1F2933);
    final muted = dark
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF667085);
    final linkColor = dark ? const Color(0xFFFFD700) : const Color(0xFF006D3C);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFE4E7EC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'subscription_details',
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ).tr(),
          const SizedBox(height: 6),
          Text(
            package == null
                ? 'subscription_details_loading'.tr()
                : _disclosureText(package),
            style: TextStyle(color: muted, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _LegalLink(
                label: 'privacy_policy'.tr(),
                url: AppLinks.privacyPolicyUrl,
                color: linkColor,
              ),
              _LegalLink(
                label: 'terms_of_use_eula'.tr(),
                url: AppLinks.termsOfUseUrl,
                color: linkColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _disclosureText(Package package) {
    final title = package.storeProduct.title.trim().isEmpty
        ? _fallbackTitle(package)
        : package.storeProduct.title.trim();
    final price = package.storeProduct.priceString;

    if (!_isSubscription) {
      return 'subscription_lifetime_disclosure'.tr(
        namedArgs: {'title': title, 'price': price},
      );
    }

    return 'subscription_auto_renew_disclosure'.tr(
      namedArgs: {
        'title': title,
        'price': price,
        'period': _periodLabel(package),
      },
    );
  }

  String _fallbackTitle(Package package) {
    switch (package.packageType) {
      case PackageType.lifetime:
        return 'plan_lifetime'.tr();
      case PackageType.annual:
        return 'plan_annual'.tr();
      case PackageType.monthly:
        return 'plan_monthly'.tr();
      case PackageType.weekly:
        return 'plan_weekly'.tr();
      default:
        return 'go_premium'.tr();
    }
  }

  String _periodLabel(Package package) {
    final period = package.storeProduct.subscriptionPeriod;
    switch (period) {
      case 'P1W':
        return 'subscription_period_week'.tr();
      case 'P1M':
        return 'subscription_period_month'.tr();
      case 'P2M':
        return 'subscription_period_two_months'.tr();
      case 'P3M':
        return 'subscription_period_three_months'.tr();
      case 'P6M':
        return 'subscription_period_six_months'.tr();
      case 'P1Y':
        return 'subscription_period_year'.tr();
    }

    switch (package.packageType) {
      case PackageType.weekly:
        return 'subscription_period_week'.tr();
      case PackageType.monthly:
        return 'subscription_period_month'.tr();
      case PackageType.twoMonth:
        return 'subscription_period_two_months'.tr();
      case PackageType.threeMonth:
        return 'subscription_period_three_months'.tr();
      case PackageType.sixMonth:
        return 'subscription_period_six_months'.tr();
      case PackageType.annual:
        return 'subscription_period_year'.tr();
      default:
        return 'subscription_period_billing_period'.tr();
    }
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.url,
    required this.color,
  });

  final String label;
  final String url;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _open(context),
      icon: const Icon(Icons.open_in_new_rounded, size: 15),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('could_not_open_legal_link').tr()));
    }
  }
}
