import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/auth_wrapper.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/utils/app_theme.dart';

Widget _app(Widget home) =>
    MaterialApp(theme: AppTheme.lightTheme, home: home);

void main() {
  group('accountGateFor', () {
    test('a failed read is a load error, never a new user', () {
      expect(
        accountGateFor(error: Exception('unavailable')),
        AccountGate.loadError,
      );
    });

    test('suspended accounts are blocked, even when set up', () {
      expect(
        accountGateFor(data: {'phoneNumber': '+1', 'suspended': true}),
        AccountGate.suspended,
      );
    });

    test('missing doc needs setup; set up account is ready', () {
      expect(accountGateFor(data: null), AccountGate.needsSetup);
      expect(
        accountGateFor(data: {'phonePromptSkippedAt': 1}),
        AccountGate.ready,
      );
    });
  });

  testWidgets('load error offers retry and sign out', (tester) async {
    var retried = 0, signedOut = 0;
    await tester.pumpWidget(
      _app(
        AccountLoadErrorScreen(
          onRetry: () => retried++,
          onSignOut: () => signedOut++,
        ),
      ),
    );
    await tester.tap(find.text('feedback_try_again'));
    await tester.tap(find.text('prof_sign_out'));
    expect(retried, 1);
    expect(signedOut, 1);
  });

  testWidgets('suspended screen explains and signs out', (tester) async {
    var signedOut = 0;
    await tester.pumpWidget(
      _app(SuspendedAccountScreen(onSignOut: () => signedOut++)),
    );
    expect(find.text('account_suspended_title'), findsOneWidget);
    expect(AppLinks.supportEmail, isNotEmpty);
    await tester.tap(find.text('prof_sign_out'));
    expect(signedOut, 1);
  });

  testWidgets('AuthFlow.backToRoot pops to the root and asks AuthWrapper to reload', (
    tester,
  ) async {
    final before = AuthFlow.refresh.value;
    late BuildContext inner;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (c) {
                  inner = c;
                  return const Text('pushed');
                },
              ),
            ),
            child: const Text('root'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsOneWidget);
    AuthFlow.backToRoot(inner);
    await tester.pumpAndSettle();
    expect(find.text('pushed'), findsNothing);
    expect(find.text('root'), findsOneWidget);
    expect(AuthFlow.refresh.value, before + 1);
  });
}
