import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/paywall/paywall_text.dart';

const _ctx = PresentedOfferingContext('default', null, null);

Package _pkg(
  PackageType type,
  double price,
  String priceString, {
  IntroductoryPrice? intro,
  SubscriptionOption? option,
  String? perMonth,
  String currency = 'USD',
}) => Package(
  type.name,
  type,
  StoreProduct(
    'id_${type.name}',
    '',
    'Split Bill Pro',
    price,
    priceString,
    currency,
    introductoryPrice: intro,
    defaultOption: option,
    pricePerMonthString: perMonth,
  ),
  _ctx,
);

void main() {
  group('PaywallPlan.fromPackages', () {
    test('keeps yearly, monthly, lifetime in that order and drops others', () {
      final plans = PaywallPlan.fromPackages([
        _pkg(PackageType.lifetime, 59.99, r'$59.99'),
        _pkg(PackageType.weekly, 0.99, r'$0.99'),
        _pkg(PackageType.monthly, 2.99, r'$2.99'),
        _pkg(PackageType.annual, 24.99, r'$24.99'),
      ]);
      expect(plans.map((p) => p.kind), [
        PaywallPlanKind.yearly,
        PaywallPlanKind.monthly,
        PaywallPlanKind.lifetime,
      ]);
      expect(PaywallPlan.defaultPlan(plans)!.kind, PaywallPlanKind.yearly);
      expect(plans.first.priceString, r'$24.99');
    });

    test('yearly per-month uses the store string, else computes it', () {
      final store = PaywallPlan.fromPackage(
        _pkg(PackageType.annual, 24.99, r'$24.99', perMonth: r'$2.08'),
      )!;
      expect(store.perMonthString, r'$2.08');
      final computed = PaywallPlan.fromPackage(
        _pkg(PackageType.annual, 24.99, r'$24.99'),
        locale: 'en_US',
      )!;
      expect(computed.perMonthString, r'$2.08');
    });

    test('free trial only when the store offers a zero-price intro', () {
      final trial = PaywallPlan.fromPackage(
        _pkg(
          PackageType.annual,
          24.99,
          r'$24.99',
          intro: const IntroductoryPrice(
            0,
            'Free',
            'P1W',
            1,
            PeriodUnit.week,
            1,
          ),
        ),
      )!;
      expect(trial.freeTrialDays, 7);
      expect(trial.cta.key, 'pw_cta_trial');

      final paidIntro = PaywallPlan.fromPackage(
        _pkg(
          PackageType.annual,
          24.99,
          r'$24.99',
          intro: const IntroductoryPrice(
            9.99,
            r'$9.99',
            'P1Y',
            1,
            PeriodUnit.year,
            1,
          ),
        ),
      )!;
      expect(paidIntro.hasFreeTrial, isFalse);
      expect(paidIntro.cta.key, 'pw_cta_yearly');
    });

    test('reads the Play free phase', () {
      const free = PricingPhase(
        Period(PeriodUnit.day, 7, 'P7D'),
        RecurrenceMode.finiteRecurring,
        1,
        Price('Free', 0, 'USD'),
        OfferPaymentMode.freeTrial,
      );
      const option = SubscriptionOption(
        'trial',
        'pro_yearly:base',
        'pro_yearly',
        [free],
        [],
        false,
        Period(PeriodUnit.year, 1, 'P1Y'),
        false,
        null,
        free,
        null,
        null,
        null,
      );
      final plan = PaywallPlan.fromPackage(
        _pkg(PackageType.annual, 24.99, r'$24.99', option: option),
      )!;
      expect(plan.freeTrialDays, 7);
    });
  });

  group('copy', () {
    final yearly = PaywallPlan.previews[0];
    final monthly = PaywallPlan.previews[1];
    final lifetime = PaywallPlan.previews[2];

    test('CTA per plan', () {
      expect(yearly.cta.key, 'pw_cta_trial');
      expect(yearly.cta.args, {'days': '7'});
      expect(monthly.cta.key, 'pw_cta_monthly');
      expect(monthly.cta.args, {'price': r'$2.99'});
      expect(lifetime.cta.key, 'pw_cta_lifetime');
      expect(lifetime.cta.args, {'price': r'$59.99'});
    });

    test(
      'subscriptions disclose renewal and cancellation; lifetime does not',
      () {
        final subKeys = monthly.legal(store: 'App Store').map((c) => c.key);
        expect(
          subKeys,
          containsAll([
            'pw_legal_price',
            'pw_legal_renews',
            'pw_legal_cancel',
            'pw_legal_charged',
          ]),
        );
        final trialKeys = yearly.legal(store: 'App Store').map((c) => c.key);
        expect(trialKeys, contains('pw_legal_trial'));
        final lifeKeys = lifetime.legal(store: 'App Store').map((c) => c.key);
        expect(lifeKeys, contains('pw_legal_lifetime'));
        expect(lifeKeys, isNot(contains('pw_legal_renews')));
      },
    );

    test('trailing price: per month for yearly, plain otherwise', () {
      expect(yearly.trailingPrice.key, 'pw_price_per_month_short');
      expect(monthly.trailingPrice.key, 'pw_price_plain');
    });

    test('cheapest monthly equivalent', () {
      expect(PaywallPlan.cheapestMonthly(PaywallPlan.previews), r'$2.08');
      expect(PaywallPlan.cheapestMonthly([lifetime]), isNull);
      expect(PaywallPlan.cheapestMonthly([monthly, lifetime]), r'$2.99');
    });
  });

  test('product id and store helpers', () {
    expect(
      planKindForProductId('splitbill_pro_yearly'),
      PaywallPlanKind.yearly,
    );
    expect(planKindForProductId('premium_annual:base'), PaywallPlanKind.yearly);
    expect(planKindForProductId('pro_monthly'), PaywallPlanKind.monthly);
    expect(planKindForProductId('lifetime_pro'), PaywallPlanKind.lifetime);
    expect(planKindForProductId(null), isNull);
    expect(storeNameForId('APP_STORE'), 'App Store');
    expect(storeNameForId('PLAY_STORE'), 'Google Play');
    expect(storeNameForId('PROMOTIONAL'), isNull);
    expect(paywallStoreName(TargetPlatform.iOS), 'App Store');
    expect(paywallStoreName(TargetPlatform.android), 'Google Play');
  });
}
