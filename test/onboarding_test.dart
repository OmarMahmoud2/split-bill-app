import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/new_onboarding_screen.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/utils/app_theme.dart';
import 'package:split_bill_app/widgets/currency_selection_sheet.dart';

class _TestSettings extends AppSettingsProvider {
  @override
  String get currencyCode => 'USD';
}

class _Translations extends AssetLoader {
  const _Translations();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync())
          as Map<String, dynamic>;
}

Future<void> _mount(
  WidgetTester tester, {
  Size size = const Size(402, 874),
  double scale = 1,
  String locale = 'en',
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(locale),
      saveLocale: false,
      path: 'assets/translations',
      assetLoader: const _Translations(),
      child: ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => _TestSettings(),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const NewOnboardingScreen(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('onboarding-next')));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0, locale: 'en'),
    (size: const Size(402, 874), scale: 2.0, locale: 'en'),
    (size: const Size(402, 874), scale: 1.0, locale: 'ar'),
    (size: const Size(1024, 1366), scale: 1.0, locale: 'en'),
  ]) {
    testWidgets(
      'four-page onboarding fits ${scenario.size} ${scenario.scale} ${scenario.locale}',
      (tester) async {
        await _mount(
          tester,
          size: scenario.size,
          scale: scenario.scale,
          locale: scenario.locale,
        );
        expect(tester.takeException(), isNull);
        await _next(tester);
        await _next(tester);
        await _next(tester);
        expect(
          find.byKey(const ValueKey('onboarding-currency')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('onboarding-back')), findsOneWidget);
        expect(find.text('Add payment methods if you want'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('onboarding-back')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('onboarding renders all pages in dark mode', (tester) async {
    await _mount(tester, themeMode: ThemeMode.dark);
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(NewOnboardingScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
    await _next(tester);
    await _next(tester);
    await _next(tester);
    expect(find.byKey(const ValueKey('onboarding-currency')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'currency opens shared sheet and selection stays after going back',
    (tester) async {
      await _mount(tester);
      await _next(tester);
      await _next(tester);
      await _next(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-currency')),
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-currency')));
      await tester.pumpAndSettle();
      expect(find.byType(CurrencySelectionSheet), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('currency-search')),
        'EGP',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('currency-USD')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('currency-EGP')));
      await tester.pumpAndSettle();
      expect(find.byType(CurrencySelectionSheet), findsNothing);
      expect(find.text('EGP'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-back')));
      await tester.pumpAndSettle();
      await _next(tester);
      expect(find.text('EGP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom currency rejects short code then accepts a normalized code',
    (tester) async {
      await _mount(tester);
      await _next(tester);
      await _next(tester);
      await _next(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('onboarding-currency')),
      );
      await tester.tap(find.byKey(const ValueKey('onboarding-currency')));
      await tester.pumpAndSettle();
      final custom = find.byKey(const ValueKey('currency-custom'));
      await tester.enterText(custom, 'AA');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.text('Use 3 to 6 letters for the currency code.'),
        findsOneWidget,
      );
      await tester.enterText(custom, 'sdgx');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('SDGX'), findsNWidgets(2));
      expect(find.byType(CurrencySelectionSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
