import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/auth_wrapper.dart';
import 'package:split_bill_app/login_screen.dart';
import 'package:split_bill_app/phone_input_screen.dart';
import 'package:split_bill_app/widgets/sign_up_modal.dart';

import 'account_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('isAccountSetupComplete', () {
    test('phone or "Not now" completes setup', () {
      expect(isAccountSetupComplete(null), isFalse);
      expect(isAccountSetupComplete({'phoneNumber': ''}), isFalse);
      expect(isAccountSetupComplete({'phoneNumber': '+201012345678'}), isTrue);
      expect(
        isAccountSetupComplete({'phonePromptSkippedAt': DateTime(2026)}),
        isTrue,
      );
    });
  });

  group('authErrorMessageKey', () {
    test('maps AuthService messages to friendly keys', () {
      expect(
        authErrorMessageKey('The email address is badly formatted.'),
        'acct_err_invalid_email',
      );
      expect(
        authErrorMessageKey('Incorrect password.'),
        'acct_err_wrong_credentials',
      );
      expect(
        authErrorMessageKey('No user found with this email.'),
        'acct_err_wrong_credentials',
      );
      expect(
        authErrorMessageKey(
          'The email address is already in use by another account.',
        ),
        'acct_err_email_in_use',
      );
      expect(
        authErrorMessageKey('Network error. Check your connection.'),
        'acct_err_network',
      );
      expect(
        authErrorMessageKey('Unable to sign in with Apple right now.'),
        'acct_err_apple',
      );
      expect(authErrorMessageKey(StateError('boom')), 'acct_err_generic');
    });
  });

  test('sign-up validation', () {
    expect(SignUpModal.validateField('name', ' '), 'required');
    expect(SignUpModal.validateField('email', 'a@b'), 'acct_err_invalid_email');
    expect(SignUpModal.validateField('email', 'a@b.co'), isNull);
    expect(
      SignUpModal.validateField('password', '12345'),
      'acct_err_weak_password',
    );
    expect(SignUpModal.validateField('password', '123456'), isNull);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('login shows providers, email and legal links ($mode)', (
      tester,
    ) async {
      await pumpAccount(
        tester,
        const LoginScreen(showAppleOverride: true),
        themeMode: mode,
      );
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byKey(const ValueKey('login-email')), findsOneWidget);
      expect(find.byKey(const ValueKey('login-password')), findsOneWidget);
      final legal = find.byType(AuthLegalFooter);
      expect(legal, findsOneWidget);
      final text = tester
          .widget<Text>(find.descendant(of: legal, matching: find.byType(Text)))
          .textSpan!
          .toPlainText();
      expect(text, contains('Terms'));
      expect(text, contains('Privacy Policy'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone step offers "Not now" ($mode)', (tester) async {
      var skipped = 0;
      await pumpAccount(
        tester,
        PhoneInputScreen(onSkip: () async => skipped++),
        themeMode: mode,
      );
      expect(find.text('Let friends find you'), findsOneWidget);
      expect(find.text('Save number'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('phone-not-now')));
      await tester.pumpAndSettle();
      expect(skipped, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('login fits a small phone in Arabic', (tester) async {
    await pumpAccount(
      tester,
      const LoginScreen(showAppleOverride: false),
      locale: 'ar',
      size: const Size(320, 568),
    );
    expect(find.text('Continue with Apple'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
