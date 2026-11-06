// ignore_for_file: invalid_use_of_visible_for_testing_member, deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/paywall/paywall_body.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/paywall/paywall_pricing.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
            File(
              'assets/translations/${locale.languageCode}.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
}

Future<void> _mount(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(390, 844),
  String locale = 'en',
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar'), Locale('ur')],
      startLocale: Locale(locale),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Translations(),
      child: Builder(
        builder: (context) => MaterialApp(
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: home,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
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
    AppMotion.debugReduceMotionOverride = null;
  });
  tearDown(() => AppMotion.debugReduceMotionOverride = null);

  group('trial date math', () {
    test('adds calendar days across month and year ends', () {
      expect(
        trialEndDate(DateTime(2026, 11, 6, 22, 30), 7),
        DateTime(2026, 11, 13),
      );
      expect(trialEndDate(DateTime(2026, 12, 28), 7), DateTime(2027, 1, 4));
      expect(trialEndDate(DateTime(2028, 2, 25), 7), DateTime(2028, 3, 3));
    });

    test('formats with the locale', () async {
      await initializeDateFormatting('en');
      expect(formatTrialDate(DateTime(2026, 11, 13), 'en'), 'Nov 13');
    });

    test('due today is zero in the store currency for a trial', () {
      final yearly = PaywallPlan.previews.first;
      expect(yearly.dueTodayString(locale: 'en_US'), r'$0.00');
      expect(PaywallPlan.previews[1].dueTodayString(locale: 'en_US'), r'$2.99');
      expect(
        PaywallPlan.previews[2].dueTodayString(locale: 'en_US'),
        r'$59.99',
      );
    });
  });

  testWidgets('plan switching updates CTA, due today and legal', (
    tester,
  ) async {
    await _mount(tester, const PremiumModal.preview());
    final today = DateTime.now();
    final end = formatTrialDate(trialEndDate(today, 7), 'en');

    expect(find.text('Start 7-day free trial'), findsOneWidget);
    expect(_textContaining('Due today, then \$24.99 on $end'), findsOneWidget);
    expect(find.text(r'$0.00'), findsOneWidget);
    expect(
      _textContaining(
        'Free until $end, then \$24.99 a year. Cancel before $end in your',
      ),
      findsOneWidget,
    );

    await _tapPlan(tester, 'paywall-plan-monthly');
    await tester.pumpAndSettle();
    expect(find.text('Continue with Monthly'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('paywall-due-today')),
        matching: find.text(r'$2.99'),
      ),
      findsOneWidget,
    );
    expect(_textContaining('at least 24 hours before renewal'), findsOneWidget);

    await _tapPlan(tester, 'paywall-plan-lifetime');
    await tester.pumpAndSettle();
    expect(find.text('Get Lifetime'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('paywall-due-today')),
        matching: find.text(r'$59.99'),
      ),
      findsOneWidget,
    );
    expect(
      _textContaining('One payment, no renewal. Fair use applies to AI.'),
      findsOneWidget,
    );
  });

  testWidgets('yearly without a trial charges the price today', (tester) async {
    await _mount(
      tester,
      PremiumModal.preview(
        loadPlans: () async => const [
          PaywallPlan(
            kind: PaywallPlanKind.yearly,
            price: 24.99,
            priceString: r'$24.99',
            currencyCode: 'USD',
            perMonthString: r'$2.08',
          ),
        ],
      ),
    );
    expect(find.text('Continue with Yearly'), findsOneWidget);
    expect(find.textContaining('days free'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('paywall-due-today')),
        matching: find.text(r'$24.99'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reduce motion: no running animations, everything visible', (
    tester,
  ) async {
    AppMotion.debugReduceMotionOverride = true;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/translations',
        assetLoader: const _Translations(),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: AppTheme.lightTheme,
            home: const PremiumModal.preview(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('unlimited'), findsNWidgets(2));
    final fades = tester.widgetList<FadeTransition>(
      find.byType(FadeTransition),
    );
    expect(
      fades.where((f) => f.opacity.value < 1 && f.opacity.value > 0),
      isEmpty,
    );
    final reveal = tester.widget<ClipRect>(
      find
          .ancestor(of: find.text('EVENS PRO'), matching: find.byType(ClipRect))
          .first,
    );
    expect(
      reveal.clipper!.getClip(const Size(100, 100)).height,
      greaterThan(100),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('motion on: receipt prints in, then settles', (tester) async {
    AppMotion.debugReduceMotionOverride = false;
    await _mount(tester, const PremiumModal.preview());
    expect(find.text('unlimited'), findsNWidgets(2));
    final lines = tester.widgetList<FadeTransition>(
      find.ancestor(
        of: find.text('included'),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(lines.every((f) => f.opacity.value == 1), isTrue);
  });

  for (final locale in ['ar', 'ur']) {
    testWidgets('RTL ($locale): no overflow, stubs mirrored', (tester) async {
      await _mount(tester, const PremiumModal.preview(), locale: locale);
      expect(tester.takeException(), isNull);
      final ctx = tester.element(find.byType(PaywallBody));
      expect(Directionality.of(ctx).name, 'rtl');
      // First stub (monthly) sits on the right in RTL.
      final monthly = tester.getCenter(
        find.byKey(const ValueKey('paywall-plan-monthly')),
      );
      final lifetime = tester.getCenter(
        find.byKey(const ValueKey('paywall-plan-lifetime')),
      );
      expect(monthly.dx, greaterThan(lifetime.dx));
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
      'iPhone SE at 1.3x text: no overflow (${dark ? 'dark' : 'light'})',
      (tester) async {
        await _mount(
          tester,
          const PremiumModal.preview(),
          size: const Size(375, 667),
          textScale: 1.3,
          mode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        expect(tester.takeException(), isNull);
        for (final k in ['monthly', 'yearly', 'lifetime']) {
          await _tapPlan(tester, 'paywall-plan-$k');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.byKey(const ValueKey('paywall-cta')), findsOneWidget);
      },
    );
  }

  testWidgets('stubs expose radio semantics with selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _mount(tester, const PremiumModal.preview());
    SemanticsNode node(String k) =>
        tester.getSemantics(find.byKey(ValueKey('paywall-plan-$k')));
    // Yearly is the default selection.
    expect(
      node('yearly'),
      containsSemantics(
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        isButton: true,
        hasTapAction: true,
        label: r'Yearly, $24.99, $2.08 a month, 7 days free',
      ),
    );
    expect(
      node('monthly'),
      containsSemantics(
        isSelected: false,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    await _tapPlan(tester, 'paywall-plan-monthly');
    await tester.pumpAndSettle();
    expect(
      node('monthly'),
      containsSemantics(isSelected: true, hasSelectedState: true),
    );
    expect(
      node('yearly'),
      containsSemantics(isSelected: false, hasSelectedState: true),
    );
    handle.dispose();
  });
}
