import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/screens/profile/subscription_screen.dart';
import 'package:split_bill_app/screens/scan_receipt/widgets/no_points_dialog.dart';
import 'package:split_bill_app/utils/app_theme.dart';
import 'package:split_bill_app/widgets/ad_modal.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';

/// Overridable so the suite can run against a translations checkout.
const _dir = String.fromEnvironment(
  'TRANSLATIONS_DIR',
  defaultValue: 'assets/translations',
);

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$_dir/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

Future<void> _mount(
  WidgetTester tester,
  Widget home, {
  ThemeMode mode = ThemeMode.light,
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(locale),
      saveLocale: false,
      path: _dir,
      assetLoader: const _Translations(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _textContaining(String s) => find.byWidgetPredicate(
  (w) => w is Text && (w.data ?? w.textSpan?.toPlainText() ?? '').contains(s),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('paywall preview: perks, plans, CTA and legal (${mode.name})', (
      tester,
    ) async {
      await _mount(tester, const PremiumModal.preview(), mode: mode);
      expect(tester.takeException(), isNull);

      expect(find.text('Split everything, without limits'), findsOneWidget);
      for (final perk in [
        'Unlimited AI receipt scans',
        'Unlimited voice assigning',
        'Recurring bills and PDF or CSV export',
        'No ads, anywhere',
      ]) {
        expect(find.text(perk), findsOneWidget);
      }
      // Trip currency conversion is not sold until it ships.
      expect(find.text('Trips with several currencies'), findsNothing);
      expect(find.byKey(const ValueKey('paywall-plan-yearly')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('paywall-plan-monthly')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('paywall-plan-lifetime')),
        findsOneWidget,
      );
      expect(find.text(r'7 days free, then $24.99 a year'), findsOneWidget);
      expect(find.text(r'$2.08/mo'), findsOneWidget);

      // Yearly is the default, with the store's trial.
      expect(find.text('Start 7-day free trial'), findsOneWidget);
      expect(_textContaining('Renews automatically'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.byKey(const ValueKey('paywall-restore')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('paywall-plan-monthly')));
      await tester.pumpAndSettle();
      expect(find.text(r'Subscribe for $2.99 a month'), findsOneWidget);
      expect(_textContaining('Renews automatically'), findsOneWidget);
      expect(_textContaining(r'$2.99 per month'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('paywall-plan-lifetime')),
      );
      await tester.tap(find.byKey(const ValueKey('paywall-plan-lifetime')));
      await tester.pumpAndSettle();
      expect(find.text(r'Buy lifetime for $59.99'), findsOneWidget);
      expect(_textContaining('One-time purchase, no renewal.'), findsOneWidget);
      expect(_textContaining('Renews automatically'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('paywall renders in Arabic (RTL) without overflow', (
    tester,
  ) async {
    await _mount(tester, const PremiumModal.preview(), locale: 'ar');
    expect(tester.takeException(), isNull);
    final ctx = tester.element(find.byType(PremiumModal));
    expect(Directionality.of(ctx).name, 'rtl');
  });

  testWidgets('paywall shows a friendly error when no prices load', (
    tester,
  ) async {
    await _mount(
      tester,
      PremiumModal.preview(loadPlans: () async => const <PaywallPlan>[]),
    );
    expect(find.text('Pricing unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const ValueKey('paywall-cta')), findsNothing);
  });

  testWidgets('out-of-scans sheet offers Pro, an ad and manual entry', (
    tester,
  ) async {
    var typed = false;
    await _mount(
      tester,
      Scaffold(
        body: NoPointsDialog(
          requiredPoints: 2,
          onWatchAd: () async {},
          onTypeItIn: () => typed = true,
          loadPlans: () async => PaywallPlan.previews,
        ),
      ),
    );
    expect(find.text("You're out of free scans"), findsOneWidget);
    expect(_textContaining('A scan uses 2 points'), findsOneWidget);
    expect(find.text(r'Go Pro · from $2.08 a month'), findsOneWidget);
    expect(find.text('Watch a short ad for points'), findsOneWidget);
    await tester.tap(find.text('Type it in instead'));
    await tester.pumpAndSettle();
    expect(typed, isTrue);
  });

  testWidgets('out-of-points sheet words voice differently from scans', (
    tester,
  ) async {
    await _mount(
      tester,
      Scaffold(
        body: NoPointsDialog(
          requiredPoints: 2,
          feature: NoPointsFeature.voice,
          onWatchAd: () async {},
          loadPlans: () async => PaywallPlan.previews,
        ),
      ),
    );
    expect(find.text("You're out of free scans"), findsNothing);
    expect(find.text("You're out of free voice commands"), findsOneWidget);
    expect(_textContaining('A voice command uses 2 points'), findsOneWidget);
    expect(find.text('Assign by tapping instead'), findsOneWidget);
    expect(find.text('Watch a short ad for points'), findsOneWidget);
  });

  testWidgets('ad explainer is optional', (tester) async {
    await _mount(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => AdModal.show(context, onWatchAd: () {}),
            child: const Text('open'),
          ),
        ),
      ),
      mode: ThemeMode.dark,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Watch a short ad'), findsOneWidget);
    expect(_textContaining('No ads ever interrupt a bill.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ad-not-now')));
    await tester.pumpAndSettle();
    expect(find.text('Watch a short ad'), findsNothing);
  });

  testWidgets('subscription screen: Pro yearly status', (tester) async {
    await _mount(
      tester,
      SubscriptionScreen(
        userStream: Stream.value({
          'isPremium': true,
          'premiumProductId': 'splitbill_pro_yearly',
          'premiumExpiresAt': '2099-11-05T12:00:00Z',
          'premiumWillRenew': true,
          'premiumStore': 'APP_STORE',
        }),
      ),
    );
    expect(find.text('PRO YEARLY'), findsOneWidget);
    expect(find.text('Pro yearly'), findsOneWidget);
    expect(_textContaining('Renews Nov 5, 2099 · App Store'), findsOneWidget);
    expect(find.text('Unlimited'), findsNWidgets(2));
    expect(find.byKey(const ValueKey('subscription-manage')), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
  });

  testWidgets('subscription screen: free plan in dark mode', (tester) async {
    await _mount(
      tester,
      SubscriptionScreen(userStream: Stream.value({'points': 5})),
      mode: ThemeMode.dark,
    );
    expect(find.text('Free plan'), findsOneWidget);
    expect(_textContaining('5 points left'), findsOneWidget);
    expect(find.text('See Pro plans'), findsOneWidget);
    expect(find.byKey(const ValueKey('subscription-manage')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
