import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/screens/guest_bill/guest_bill_model.dart';
import 'package:split_bill_app/screens/guest_bill/widgets/guest_pay_panel.dart';

GuestBill billWith(Map<String, String> methods, {String currency = 'USD'}) =>
    GuestBill.fromMap('b1', {
      'hostId': 'h',
      'hostName': 'Omar',
      'storeName': 'Cafe',
      'currencyCode': currency,
      'participants': [
        {'id': 'h', 'name': 'Omar', 'status': 'PAID'},
        {'id': 'm', 'name': 'Mona', 'share': 16.38, 'status': 'PENDING'},
      ],
      'paymentMethods': methods,
    });

void main() {
  test('Apple Cash only in iOS Safari on the web', () {
    final bill = billWith({'Apple Cash': '+12025550123', 'Venmo': '@omar'});
    final names = guestPayOptions(
      bill,
      1638,
      web: true,
      iosSafari: false,
    ).map((o) => o.method.type.id);
    expect(names, isNot(contains('apple_cash')));
    expect(names, contains('venmo'));

    final safari = guestPayOptions(bill, 1638, web: true, iosSafari: true);
    expect(safari.map((o) => o.method.type.id), contains('apple_cash'));
  });

  test('app-only links fall back to copying the handle on the web', () {
    final bill = billWith({'UPI': 'omar@okaxis'}, currency: 'INR');
    final upi = guestPayOptions(
      bill,
      50000,
      web: true,
      iosSafari: false,
    ).single;
    expect(upi.launch, isA<CopyInstruction>());
    expect((upi.launch as CopyInstruction).text, 'omar@okaxis');
    // The QR still carries the amount.
    expect(upi.qrPayload, contains('am=500.00'));
  });

  test('prefill links say they open with the amount', () {
    final bill = billWith({'PayPal': 'paypal.me/omar'});
    final paypal = guestPayOptions(
      bill,
      1638,
      web: true,
      iosSafari: false,
    ).single;
    expect(paypal.opens, isTrue);
    expect(paypal.request.amount!.minor, 1638);
  });

  test('empty methods give no options', () {
    expect(
      guestPayOptions(billWith({}), 100, web: true, iosSafari: false),
      isEmpty,
    );
  });
}
