import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/payments.dart';

void main() {
  test('screens hand Apple Cash a localized message, not the English default', () {
    final request = localizedPaymentRequest(
      handle: '+15551234567',
      amount: Money(1638, 'USD'),
      note: 'Sea Breeze',
    );
    // Without translations loaded tr() returns the key: proof it goes through
    // the translation layer.
    expect(request.message, 'payment_apple_cash_message');
    final launch =
        paymentMethodById('apple_cash')!.buildLaunch(request) as DeepLinkLaunch;
    expect(launch.uri.toString(), isNot(contains('Paying')));
    expect(launch.uri.toString(), contains('payment_apple_cash_message'));
  });

  test('no note uses the plain wording', () {
    final request = localizedPaymentRequest(
      handle: 'x',
      amount: Money(500, 'USD'),
    );
    expect(request.message, 'payment_apple_cash_message_plain');
  });
}
