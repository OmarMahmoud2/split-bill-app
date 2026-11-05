import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/payment_settings_screen.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/screens/profile/export_screen.dart';
import 'package:split_bill_app/screens/recurring/recurring_bill_screen.dart';
import 'package:split_bill_app/services/recurring_bill_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

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
  WidgetTester tester,
  Widget home, {
  ThemeMode themeMode = ThemeMode.light,
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(402, 874);
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
            home: home,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lets any toast finish its timers.
Future<void> _drainToasts(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

final _paypal = paymentMethodById('paypal')!;
final _wise = paymentMethodById('wise')!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('pure helpers', () {
    test('moveMethodToDefault moves the chosen method to the front', () {
      final a = StoredPaymentMethod.create(_paypal, 'omarm');
      final b = StoredPaymentMethod.create(_wise, 'omar@example.com');
      expect(moveMethodToDefault([a, b], 1), [b, a]);
      expect(moveMethodToDefault([a, b], 0), [a, b]);
      expect(moveMethodToDefault([a, b], 5), [a, b]);
    });

    test('storage round-trips through the legacy-compatible shape', () {
      final methods = [
        StoredPaymentMethod.create(_paypal, 'omarm'),
        StoredPaymentMethod.create(
          otherPaymentMethod,
          'Cash at the office',
          label: 'Cash',
        ),
      ];
      final stored = toStoredPaymentMethodList(methods);
      expect(stored.first, {
        'name': 'PayPal',
        'value': 'omarm',
        'type': 'paypal',
      });
      final parsed = parseStoredPaymentMethods({
        'customPaymentMethods': stored,
      });
      expect(parsed.map((m) => m.type.id), ['paypal', 'other']);
      expect(parsed.last.label, 'Cash');
      // Pre-2.0 entries without `type` still resolve.
      final legacy = parseStoredPaymentMethods({
        'customPaymentMethods': [
          {'name': 'PayPal', 'value': 'paypal.me/omarm'},
        ],
      });
      expect(legacy.single.type.id, 'paypal');
    });

    test('suggestions skip saved methods and end with Other', () {
      final rec = recommendedPaymentMethods(
        localeTag: 'en-US',
        currency: 'USD',
      );
      final saved = [StoredPaymentMethod.create(rec.first, 'x')];
      final s = suggestedMethodsToAdd(rec, saved);
      expect(s.last.id, 'other');
      expect(s.where((t) => t.id == rec.first.id), isEmpty);
      expect(s.length, lessThanOrEqualTo(9));
    });

    test('Apple Cash is only suggested on iOS', () {
      final ios = recommendedPaymentMethods(
        localeTag: 'en-US',
        platform: PaymentPlatform.ios,
      );
      final android = recommendedPaymentMethods(
        localeTag: 'en-US',
        platform: PaymentPlatform.android,
      );
      expect(ios.any((t) => t.id == 'apple_cash'), isTrue);
      expect(android.any((t) => t.id == 'apple_cash'), isFalse);
    });

    test('handle validation per kind', () {
      expect(isAcceptableHandle(_paypal, 'omarm'), isTrue);
      expect(isAcceptableHandle(_paypal, 'paypal.me/omarm'), isTrue);
      expect(isAcceptableHandle(_paypal, '!!'), isFalse);
      expect(isAcceptableHandle(_paypal, '   '), isFalse);
      expect(isAcceptableHandle(otherPaymentMethod, 'Ask me for cash'), isTrue);
    });

    test('countryFlag builds regional indicators', () {
      expect(countryFlag('eg'), '🇪🇬');
      expect(countryFlag('X'), 'X');
    });
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'payment methods: default chip, make default, add (${mode.name})',
      (tester) async {
        final writes = <List<StoredPaymentMethod>>[];
        await _mount(
          tester,
          PaymentSettingsScreen(
            debugInitialMethods: [
              StoredPaymentMethod.create(_paypal, 'omarm'),
              StoredPaymentMethod.create(_wise, 'omar@example.com'),
            ],
            debugPersist: (m) async => writes.add(m),
            debugLocaleTag: 'en-US',
          ),
          themeMode: mode,
        );
        expect(find.byType(SoftChip), findsOneWidget);
        expect(find.text('omarm'), findsOneWidget);

        // Make Wise the default.
        await tester.tap(find.byKey(const ValueKey('pm3-row-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('pm3-make-default')));
        await tester.pumpAndSettle();
        expect(writes.single.map((m) => m.type.id), ['wise', 'paypal']);
        await _drainToasts(tester);

        // Add Other with a free-text handle; empty input is rejected first.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('pm3-add-other')),
          200,
        );
        await tester.tap(find.byKey(const ValueKey('pm3-add-other')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('pm3-save')));
        await tester.pumpAndSettle();
        expect(writes, hasLength(1));
        await tester.enterText(
          find.byKey(const ValueKey('pm3-value')),
          'Cash at work',
        );
        await tester.tap(find.byKey(const ValueKey('pm3-save')));
        await tester.pumpAndSettle();
        expect(writes, hasLength(2));
        expect(writes.last.last.type.id, 'other');
        await _drainToasts(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('payment methods: invalid handle shows an inline error', (
    tester,
  ) async {
    final writes = <List<StoredPaymentMethod>>[];
    await _mount(
      tester,
      PaymentSettingsScreen(
        debugInitialMethods: [StoredPaymentMethod.create(_paypal, 'omarm')],
        debugPersist: (m) async => writes.add(m),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('pm3-row-0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('pm3-value')), '!!');
    await tester.tap(find.byKey(const ValueKey('pm3-save')));
    await tester.pumpAndSettle();
    expect(writes, isEmpty);
    expect(find.textContaining('valid'), findsOneWidget);
  });

  testWidgets('payment methods: delete offers undo', (tester) async {
    final writes = <List<StoredPaymentMethod>>[];
    await _mount(
      tester,
      PaymentSettingsScreen(
        debugInitialMethods: [StoredPaymentMethod.create(_paypal, 'omarm')],
        debugPersist: (m) async => writes.add(m),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('pm3-row-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pm3-delete')));
    await tester.pumpAndSettle();
    expect(writes.single, isEmpty);
    await tester.tap(find.text('pm3_undo'.tr()));
    await tester.pumpAndSettle();
    expect(writes.last.single.type.id, 'paypal');
    await _drainToasts(tester);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('export screen renders and gates non-Pro (${mode.name})', (
      tester,
    ) async {
      await _mount(
        tester,
        const ExportScreen(
          debugIsPro: false,
          groupId: 'g',
          groupName: 'Dahab trip',
        ),
        themeMode: mode,
      );
      expect(find.byType(ProBadge), findsOneWidget);
      expect(find.byKey(const ValueKey('exp-receipts')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('exp-format-csv')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('exp-receipts')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('recurring bill validates then saves (${mode.name})', (
      tester,
    ) async {
      final saved = <(String, RecurringBillTemplate)>[];
      await _mount(
        tester,
        RecurringBillScreen(
          debugIsPro: true,
          debugGroups: const [
            RecurringGroupOption(
              id: 'g1',
              name: 'Flat 4B',
              members: {'me': 'You', 'ali': 'Ali', 'mona': 'Mona'},
            ),
          ],
          debugSave: (gid, t) async => saved.add((gid, t)),
        ),
        themeMode: mode,
      );
      await tester.tap(find.byKey(const ValueKey('rec-save')));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);

      await tester.enterText(find.byKey(const ValueKey('rec-name')), 'Rent');
      await tester.enterText(find.byKey(const ValueKey('rec-amount')), '126');
      await tester.tap(find.byKey(const ValueKey('rec-freq-weekly')));
      await tester.pumpAndSettle();
      expect(find.text('Mona'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rec-save')));
      await tester.pumpAndSettle();
      expect(saved.single.$1, 'g1');
      expect(saved.single.$2.amountMinor, 12600);
      expect(saved.single.$2.frequency, RecurringFrequency.weekly);
      expect(saved.single.$2.memberIds, ['me', 'ali', 'mona']);
      await _drainToasts(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('payment methods lay out in RTL', (tester) async {
    await _mount(
      tester,
      PaymentSettingsScreen(
        debugInitialMethods: [StoredPaymentMethod.create(_paypal, 'omarm')],
        debugPersist: (_) async {},
        debugLocaleTag: 'ar-EG',
      ),
      locale: 'ar',
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('pm3-add-instapay')), findsOneWidget);
  });
}
