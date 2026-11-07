import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/new_onboarding_screen.dart';
import 'package:split_bill_app/payments/browse_all_sheet.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_content.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_dialogs.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/payment_settings_screen.dart';

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

class _Settings extends AppSettingsProvider {
  @override
  String get currencyCode => 'USD';
}

Future<void> _mount(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(402, 874);
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
      child: ChangeNotifierProvider<AppSettingsProvider>(
        create: (_) => _Settings(),
        child: Builder(
          builder: (context) => MaterialApp(
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: AppTheme.lightTheme,
            home: home,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _view = ProfileViewData(
  name: 'Omar',
  appearanceLabel: 'System',
  languageLabel: 'English',
  currencyCode: 'USD',
  remindersSummary: 'Off',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppMotion.debugReduceMotionOverride = true;
    await EasyLocalization.ensureInitialized();
  });
  tearDown(() => AppMotion.debugReduceMotionOverride = null);

  testWidgets('Log out asks first, then signs out only on confirm', (
    tester,
  ) async {
    var signedOut = 0;
    await _mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => ProfileDialogs.showLogout(
              context,
              signOut: () async => signedOut++,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Log out of Evens?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(signedOut, 0);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pump();
    await tester.pump();
    expect(signedOut, 1);
  });

  testWidgets('You page: log out row, danger zone, footer links', (
    tester,
  ) async {
    final actions = <ProfileAction>[];
    final opened = <String>[];
    await _mount(
      tester,
      Scaffold(
        body: ProfileContent(
          data: _view,
          onAction: actions.add,
          onHapticsChanged: (_) {},
          onOpenLink: opened.add,
        ),
      ),
    );
    expect(find.text('Try 7 days free'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-logout')),
      200,
    );
    await tester.tap(find.byKey(const ValueKey('profile-logout')));
    final delete = find.byKey(const ValueKey('profile-delete-account'));
    await tester.scrollUntilVisible(delete, 300);
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    expect(actions.last, ProfileAction.deleteAccount);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('footer-website')),
      300,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    for (final k in ['privacy', 'terms', 'support', 'website']) {
      await tester.tap(find.byKey(ValueKey('footer-$k')));
    }
    expect(opened, [
      'https://omarmali.net/split-bill/privacy/',
      'https://omarmali.net/split-bill/terms/',
      'mailto:support@omarmali.net',
      'https://omarmali.net/split-bill/',
    ]);
  });

  testWidgets('delete account needs the typed word', (tester) async {
    await _mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => ProfileDialogs.showDeleteAccount(context),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    FilledButton button() => tester.widget<FilledButton>(
      find.byKey(const ValueKey('confirm-delete-account')),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-delete-account')),
    );
    expect(button().onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'delete',
    );
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  test('browse-all lists more than the grid and filters by search', () {
    final all = groupMethods(browsableMethods());
    final total = all.fold<int>(0, (n, g) => n + g.methods.length);
    expect(
      total,
      greaterThan(suggestedMethodsToAdd(const [], const []).length),
    );
    expect(browsableMethods().length, greaterThan(60));
    final byName = groupMethods(browsableMethods(), query: 'pix');
    expect(byName.expand((g) => g.methods).any((t) => t.id == 'pix'), isTrue);
    final byCountry = groupMethods(browsableMethods(), query: 'egypt');
    final ids = byCountry.expand((g) => g.methods).map((t) => t.id);
    expect(ids, contains('instapay'));
    expect(ids, isNot(contains('venmo')));
    final c = paymentCoverage();
    expect(c.apps, browsableMethods().length);
    expect(c.countries, greaterThan(30));
  });

  testWidgets('Browse all payment methods sheet searches', (tester) async {
    await _mount(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showBrowseAllMethods(context),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('All payment methods'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('pm-browse-search')),
      'zzzz',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching payment methods'), findsOneWidget);
  });

  testWidgets('onboarding preselects the device region currency', (
    tester,
  ) async {
    await _mount(tester, const NewOnboardingScreen(debugLocaleTag: 'ar-EG'));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('onboarding-suggested')), findsOneWidget);
    expect(find.textContaining('Continue with'), findsOneWidget);
    expect(find.textContaining('EGP'), findsWidgets);
    expect(find.byKey(const ValueKey('onboarding-pop-USD')), findsOneWidget);
    expect(currencyForRegion('DE'), 'EUR');
  });
}
