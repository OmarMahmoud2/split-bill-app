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

Future<void> _tapPlan(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
}

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

      expect(find.text('Every bill, no limits'), findsOneWidget);
      for (final perk in [
        'AI receipt scans',
        'Voice assigning',
        'Recurring bills',
        'PDF and CSV export',
        'Ads',
      ]) {
        expect(find.text(perk), findsOneWidget);
      }
      expect(find.text('Trips with several currencies'), findsNothing);
      for (final k in ['yearly', 'monthly', 'lifetime']) {
        expect(find.byKey(ValueKey('paywall-plan-$k')), findsOneWidget);
      }
      expect(find.text('7 days free'), findsOneWidget);
      expect(find.text(r'$2.08 a month'), findsOneWidget);

      // Yearly is the default, with the store's trial.
      expect(find.text('Start 7-day free trial'), findsOneWidget);
      expect(_textContaining('Renews automatically'), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.byKey(const ValueKey('paywall-restore')), findsOneWidget);

      await _tapPlan(tester, 'paywall-plan-monthly');
      await tester.pumpAndSettle();
      expect(find.text('Continue with Monthly'), findsOneWidget);
      expect(_textContaining(r'Renews every month at $2.99'), findsOneWidget);

      await _tapPlan(tester, 'paywall-plan-lifetime');
      await tester.pumpAndSettle();
      expect(find.text('Get Lifetime'), findsOneWidget);
      expect(_textContaining('One payment, no renewal.'), findsOneWidget);
      expect(_textContaining('Renews every'), findsNothing);
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
    await tester.tap(find.text('Type it in instead (free)'));
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
    expect(find.text('Assign by tapping instead (free)'), findsOneWidget);
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
