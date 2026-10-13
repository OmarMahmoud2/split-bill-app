import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/login_screen.dart';
import 'package:split_bill_app/main.dart' as app;
import 'package:split_bill_app/widgets/currency_selection_sheet.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    bool settle = true,
  }) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (finder.evaluate().isNotEmpty) {
        if (settle) {
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
        } else {
          // The auth background and floating logo animate continuously.
          await tester.pump(const Duration(milliseconds: 1500));
        }
        return;
      }
    }
    expect(finder, findsWidgets);
  }

  testWidgets(
    'native startup, onboarding, currency, login and contacts registration',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('onboarding_complete');
      await prefs.remove('onboarding_complete_v2');
      await prefs.setString('currencyCode', 'USD');
      await app.main();
      final next = find.byKey(const ValueKey('onboarding-next'));
      await waitFor(tester, next);
      await binding.takeScreenshot('01-welcome');
      for (var page = 1; page <= 3; page++) {
        await tester.tap(next);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        await binding.takeScreenshot('0${page + 1}-onboarding');
      }
      final currency = find.byKey(const ValueKey('onboarding-currency'));
      await tester.ensureVisible(currency);
      await tester.tap(currency);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(CurrencySelectionSheet), findsOneWidget);
      await binding.takeScreenshot('05-currency-sheet');
      await tester.enterText(
        find.byKey(const ValueKey('currency-search')),
        'EGP',
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('currency-EGP')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('EGP'), findsOneWidget);
      await tester.tap(next);
      await waitFor(tester, find.byType(LoginScreen), settle: false);
      expect(prefs.getString('currencyCode'), 'EGP');
      expect(prefs.getBool('onboarding_complete_v2'), isTrue);
      expect(find.byKey(const ValueKey('sign-in-google')), findsOneWidget);
      expect(find.byKey(const ValueKey('sign-in-apple')), findsOneWidget);
      await binding.takeScreenshot('06-login');
      await tester.tap(find.text('sign_in'.tr()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('please_enter_email_and_password'.tr()), findsOneWidget);
      // Calling the native contacts API also verifies that the new plugin registered.
      await FlutterContacts.permissions.check(PermissionType.read);
      expect(tester.takeException(), isNull);
    },
  );
}
