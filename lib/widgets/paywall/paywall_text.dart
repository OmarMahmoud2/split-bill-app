import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';

/// Resolves a [PaywallCopy]; a `period` argument is itself a translation
/// key ("subscription_period_year").
String paywallText(PaywallCopy copy) => copy.key.tr(
  namedArgs: {
    for (final e in copy.args.entries)
      e.key: e.key == 'period' ? e.value.tr() : e.value,
  },
);

/// The store the purchase goes through (a proper noun, not translated).
String paywallStoreName([TargetPlatform? platform]) =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.iOS ||
        (platform ?? defaultTargetPlatform) == TargetPlatform.macOS
    ? 'App Store'
    : 'Google Play';
