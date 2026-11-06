/// Pure helpers for the v4 paywall: trial dates, "due today", and the
/// per-plan copy (CTA, legal lines).
library;

import 'package:intl/intl.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';

PaywallCopy _copy(String key, [Map<String, String> args = const {}]) =>
    (key: key, args: args);

/// The day the free trial ends and the first charge happens: [now] plus
/// [days] calendar days (time of day dropped).
DateTime trialEndDate(DateTime now, int days) =>
    DateTime(now.year, now.month, now.day + days);

/// Short locale-formatted date ("Nov 13", "13 nov").
String formatTrialDate(DateTime date, String locale) {
  try {
    return DateFormat.MMMd(locale).format(date);
  } catch (_) {
    return DateFormat.MMMd().format(date);
  }
}

extension PaywallPlanV4 on PaywallPlan {
  bool get hasTrialSubscription => hasFreeTrial && isSubscription;

  /// Store-formatted amount charged today: zero for a trial, else the price.
  String dueTodayString({String? locale}) => hasTrialSubscription
      ? formatPrice(0, currencyCode, locale: locale)
      : priceString;

  /// CTA label.
  PaywallCopy get ctaV4 => switch (kind) {
    PaywallPlanKind.yearly when hasFreeTrial => _copy('pw_cta_trial', {
      'days': '$freeTrialDays',
    }),
    PaywallPlanKind.yearly => _copy('pw_cta_continue_yearly'),
    PaywallPlanKind.monthly => _copy('pw_cta_continue_monthly'),
    PaywallPlanKind.lifetime => _copy('pw_cta_get_lifetime'),
  };

  /// The small line under the stub's price.
  PaywallCopy get stubPerLine => switch (kind) {
    PaywallPlanKind.monthly => _copy('pw_stub_per_month'),
    PaywallPlanKind.yearly =>
      perMonthString != null
          ? _copy('pw_stub_per_month_price', {'price': perMonthString!})
          : _copy('pw_plan_yearly_sub', {'price': priceString}),
    PaywallPlanKind.lifetime => _copy('pw_stub_once'),
  };

  /// Legal lines under the CTA. [date] is the trial end ("Nov 13").
  /// Keeps the store-required disclosures: auto-renewal, cancelling in the
  /// store settings at least 24 h before renewal, and who charges.
  List<PaywallCopy> legalV4({required String store, String? date}) {
    final args = {'price': priceString, 'store': store, 'date': date ?? ''};
    return switch (kind) {
      PaywallPlanKind.lifetime => [
        _copy('pw_legal_v4_lifetime'),
        _copy('pw_legal_charged', {'store': store}),
      ],
      PaywallPlanKind.monthly => [
        _copy('pw_legal_v4_monthly', args),
        _copy('pw_legal_charged', {'store': store}),
      ],
      PaywallPlanKind.yearly when hasFreeTrial && date != null => [
        _copy('pw_legal_v4_trial', args),
        _copy('pw_legal_renews'),
        _copy('pw_legal_charged', {'store': store}),
      ],
      PaywallPlanKind.yearly => [
        _copy('pw_legal_v4_yearly', args),
        _copy('pw_legal_charged', {'store': store}),
      ],
    };
  }
}
