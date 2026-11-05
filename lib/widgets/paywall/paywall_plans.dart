/// Pure mapping from RevenueCat packages to the three v3 paywall plans
/// (Yearly, Monthly, Lifetime), plus the copy keys each plan needs.
///
/// Prices always come from the store ([PaywallPlan.priceString] is the
/// store-localized string). [PaywallPlan.previews] holds USD fallback
/// labels for tests and design previews only; production never shows them.
library;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

enum PaywallPlanKind { yearly, monthly, lifetime }

/// A translation key with its named arguments.
typedef PaywallCopy = ({String key, Map<String, String> args});

PaywallCopy _copy(String key, [Map<String, String> args = const {}]) =>
    (key: key, args: args);

@immutable
class PaywallPlan {
  const PaywallPlan({
    required this.kind,
    required this.price,
    required this.priceString,
    required this.currencyCode,
    this.perMonthString,
    this.freeTrialDays,
    this.package,
  });

  final PaywallPlanKind kind;

  /// Numeric store price, used only to compare plans.
  final double price;

  /// Store-localized price ("$24.99", "EGP 1,199.99").
  final String priceString;
  final String currencyCode;

  /// Yearly only: the price per month, store-formatted when available.
  final String? perMonthString;

  /// Free-trial length in days when the store offers one, else null.
  final int? freeTrialDays;

  /// The RevenueCat package to buy; null for previews.
  final Package? package;

  bool get isSubscription => kind != PaywallPlanKind.lifetime;
  bool get hasFreeTrial => (freeTrialDays ?? 0) > 0;

  /// Monthly-equivalent price, for "from X a month".
  double? get monthlyEquivalent => switch (kind) {
    PaywallPlanKind.yearly => price / 12,
    PaywallPlanKind.monthly => price,
    PaywallPlanKind.lifetime => null,
  };

  /// Plan name key.
  String get nameKey => switch (kind) {
    PaywallPlanKind.yearly => 'pw_plan_yearly',
    PaywallPlanKind.monthly => 'pw_plan_monthly',
    PaywallPlanKind.lifetime => 'pw_plan_lifetime',
  };

  /// Badge key on the subscription screen ("PRO YEARLY").
  String get badgeKey => switch (kind) {
    PaywallPlanKind.yearly => 'pw_badge_yearly',
    PaywallPlanKind.monthly => 'pw_badge_monthly',
    PaywallPlanKind.lifetime => 'pw_badge_lifetime',
  };

  /// The line under the plan name.
  PaywallCopy get subtitle => switch (kind) {
    PaywallPlanKind.yearly when hasFreeTrial => _copy(
      'pw_plan_yearly_trial_sub',
      {'days': '$freeTrialDays', 'price': priceString},
    ),
    PaywallPlanKind.yearly => _copy('pw_plan_yearly_sub', {
      'price': priceString,
    }),
    PaywallPlanKind.monthly => _copy('pw_plan_monthly_sub'),
    PaywallPlanKind.lifetime => _copy('pw_plan_lifetime_sub'),
  };

  /// The price on the trailing side of the plan row.
  PaywallCopy get trailingPrice =>
      kind == PaywallPlanKind.yearly && perMonthString != null
      ? _copy('pw_price_per_month_short', {'price': perMonthString!})
      : _copy('pw_price_plain', {'price': priceString});

  /// The CTA label for this plan.
  PaywallCopy get cta => switch (kind) {
    PaywallPlanKind.yearly when hasFreeTrial => _copy('pw_cta_trial', {
      'days': '$freeTrialDays',
    }),
    PaywallPlanKind.yearly => _copy('pw_cta_yearly', {'price': priceString}),
    PaywallPlanKind.monthly => _copy('pw_cta_monthly', {'price': priceString}),
    PaywallPlanKind.lifetime => _copy('pw_cta_lifetime', {
      'price': priceString,
    }),
  };

  /// The legal lines under the CTA, in order (price/period first, then
  /// renewal and cancellation, or the one-time note).
  List<PaywallCopy> legal({required String store}) {
    if (!isSubscription) {
      return [
        _copy('pw_legal_lifetime_price', {'price': priceString}),
        _copy('pw_legal_lifetime'),
        _copy('pw_legal_charged', {'store': store}),
      ];
    }
    final period = kind == PaywallPlanKind.yearly
        ? 'subscription_period_year'
        : 'subscription_period_month';
    return [
      if (hasFreeTrial)
        _copy('pw_legal_trial', {
          'days': '$freeTrialDays',
          'price': priceString,
          'period': period,
        })
      else
        _copy('pw_legal_price', {'price': priceString, 'period': period}),
      _copy('pw_legal_renews'),
      _copy('pw_legal_charged', {'store': store}),
      _copy('pw_legal_cancel', {'store': store}),
    ];
  }

  static PaywallPlanKind? kindFor(PackageType type) => switch (type) {
    PackageType.annual => PaywallPlanKind.yearly,
    PackageType.monthly => PaywallPlanKind.monthly,
    PackageType.lifetime => PaywallPlanKind.lifetime,
    _ => null,
  };

  /// Maps one package; null for package types the paywall does not offer.
  static PaywallPlan? fromPackage(Package package, {String? locale}) {
    final kind = kindFor(package.packageType);
    if (kind == null) return null;
    final product = package.storeProduct;
    String? perMonth;
    if (kind == PaywallPlanKind.yearly) {
      perMonth = product.pricePerMonthString;
      if (perMonth == null || perMonth.trim().isEmpty) {
        perMonth = formatPrice(
          product.price / 12,
          product.currencyCode,
          locale: locale,
        );
      }
    }
    return PaywallPlan(
      kind: kind,
      price: product.price,
      priceString: product.priceString,
      currencyCode: product.currencyCode,
      perMonthString: perMonth,
      freeTrialDays: kind == PaywallPlanKind.lifetime
          ? null
          : freeTrialDaysOf(product),
      package: package,
    );
  }

  /// Yearly, Monthly, Lifetime (whichever exist), one of each.
  static List<PaywallPlan> fromPackages(
    Iterable<Package> packages, {
    String? locale,
  }) {
    final byKind = <PaywallPlanKind, PaywallPlan>{};
    for (final package in packages) {
      final plan = fromPackage(package, locale: locale);
      if (plan != null) byKind.putIfAbsent(plan.kind, () => plan);
    }
    return [
      for (final kind in PaywallPlanKind.values)
        if (byKind[kind] != null) byKind[kind]!,
    ];
  }

  /// The plan selected when the paywall opens: Yearly, else the first.
  static PaywallPlan? defaultPlan(List<PaywallPlan> plans) {
    if (plans.isEmpty) return null;
    return plans.firstWhere(
      (p) => p.kind == PaywallPlanKind.yearly,
      orElse: () => plans.first,
    );
  }

  /// Cheapest monthly-equivalent price ("from $2.08 a month"), or null.
  static String? cheapestMonthly(List<PaywallPlan> plans, {String? locale}) {
    PaywallPlan? best;
    for (final plan in plans) {
      final m = plan.monthlyEquivalent;
      if (m == null) continue;
      if (best == null || m < best.monthlyEquivalent!) best = plan;
    }
    if (best == null) return null;
    if (best.kind == PaywallPlanKind.monthly) return best.priceString;
    return best.perMonthString ??
        formatPrice(best.monthlyEquivalent!, best.currencyCode, locale: locale);
  }

  /// USD fallback plans for previews and tests only (never shown to
  /// buyers: production reads store prices).
  static const List<PaywallPlan> previews = [
    PaywallPlan(
      kind: PaywallPlanKind.yearly,
      price: 24.99,
      priceString: r'$24.99',
      currencyCode: 'USD',
      perMonthString: r'$2.08',
      freeTrialDays: 7,
    ),
    PaywallPlan(
      kind: PaywallPlanKind.monthly,
      price: 2.99,
      priceString: r'$2.99',
      currencyCode: 'USD',
    ),
    PaywallPlan(
      kind: PaywallPlanKind.lifetime,
      price: 59.99,
      priceString: r'$59.99',
      currencyCode: 'USD',
    ),
  ];
}

/// Free-trial days from the store product: the iOS introductory price or the
/// Play default option's free phase. Null when there is no free trial.
int? freeTrialDaysOf(StoreProduct product) {
  final intro = product.introductoryPrice;
  if (intro != null && intro.price == 0) {
    final days = _days(intro.periodUnit, intro.periodNumberOfUnits);
    if (days > 0) return days;
  }
  final period = product.defaultOption?.freePhase?.billingPeriod;
  if (period != null) {
    final days = _days(period.unit, period.value);
    if (days > 0) return days;
  }
  return null;
}

int _days(PeriodUnit unit, int count) => switch (unit) {
  PeriodUnit.day => count,
  PeriodUnit.week => count * 7,
  PeriodUnit.month => count * 30,
  PeriodUnit.year => count * 365,
  PeriodUnit.unknown => 0,
};

/// Formats [amount] in [currencyCode] with the currency symbol.
String formatPrice(double amount, String currencyCode, {String? locale}) {
  try {
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: currencyCode,
    ).format(amount);
  } catch (_) {
    return '${amount.toStringAsFixed(2)} $currencyCode';
  }
}

/// Best guess of the plan from a store product id
/// ("splitbill_pro_yearly", "premium_monthly:base", "lifetime_pro").
PaywallPlanKind? planKindForProductId(String? productId) {
  final id = productId?.toLowerCase() ?? '';
  if (id.isEmpty) return null;
  if (id.contains('life')) return PaywallPlanKind.lifetime;
  if (id.contains('year') || id.contains('annual') || id.contains('p1y')) {
    return PaywallPlanKind.yearly;
  }
  if (id.contains('month') || id.contains('p1m')) {
    return PaywallPlanKind.monthly;
  }
  return null;
}

/// Readable store name for a RevenueCat store id ("APP_STORE",
/// "PLAY_STORE"); null for promotional or unknown grants.
String? storeNameForId(String? store) => switch (store?.toUpperCase()) {
  'APP_STORE' || 'MAC_APP_STORE' => 'App Store',
  'PLAY_STORE' => 'Google Play',
  'STRIPE' => 'Stripe',
  _ => null,
};
