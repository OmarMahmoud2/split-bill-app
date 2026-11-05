import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/payments/legacy_payment_adapter.dart';

String _id(String name, String value, {String? type}) =>
    adaptLegacyPaymentMethod(name, value, typeId: type).type.id;

void main() {
  group('name matching (1.x presets and free text)', () {
    final presets = {
      'InstaPay': 'instapay',
      'Vodafone Cash': 'vodafone_cash',
      'PayPal': 'paypal',
      'Venmo': 'venmo',
      'Cash App': 'cash_app',
      'Zelle': 'zelle',
      'Apple Cash': 'apple_cash',
      'Revolut': 'revolut',
      'Wise': 'wise',
      'M-Pesa': 'mpesa',
      'Bank Transfer': 'bank_transfer',
      'Other': 'other',
    };
    presets.forEach((name, id) {
      test('preset "$name" -> $id', () => expect(_id(name, 'x'), id));
    });

    test('pre-1.0 upper-cased map keys', () {
      expect(_id('INSTAPAY', 'omar@instapay'), 'instapay');
      expect(_id('VODAFONE', '01012345678'), 'vodafone_cash');
      expect(_id('PAYPAL', 'omar'), 'paypal');
    });

    test('free-text names', () {
      expect(_id('My PayPal', 'x'), 'paypal');
      expect(_id('UPI ID', 'omar@okaxis'), 'upi');
      expect(_id('Chave Pix', '12345678901'), 'pix');
      expect(_id('MBWay', '912345678'), 'mb_way');
      expect(_id('Swish', '0701234567'), 'swish');
    });

    test('short aliases need a whole word', () {
      // "Stripe link" must not match an alias hidden inside a word.
      expect(_id('Stripe link', 'https://buy.stripe.com/x'), 'other');
      expect(_id('Bankak', '123'), 'bank_transfer');
    });
  });

  group('value matching when the name is unknown', () {
    test('provider links and formats', () {
      expect(_id('Other', 'https://paypal.me/omar'), 'paypal');
      expect(_id('Link', 'revolut.me/omar'), 'revolut');
      expect(_id('Pay me', r'$OmarM'), 'cash_app');
      expect(_id('Pay me', 'https://ipn.eg/S/omar/instapay/1'), 'instapay');
      expect(_id('Pay me', 'DE89 3704 0044 0532 0130 00'), 'bank_transfer');
      expect(_id('Pay me', 'whatever'), 'other');
    });
  });

  test('explicit type wins and unknown type falls back', () {
    expect(_id('Anything', 'x', type: 'swish'), 'swish');
    expect(_id('PayPal', 'x', type: 'removed_type'), 'paypal');
  });

  test('labels keep user text but prettify upper-cased keys', () {
    expect(adaptLegacyPaymentMethod('INSTAPAY', 'a').label, 'InstaPay');
    expect(adaptLegacyPaymentMethod('My PayPal', 'a').label, 'My PayPal');
    expect(adaptLegacyPaymentMethod('', 'a').label, 'Other');
  });

  group('documents', () {
    test('customPaymentMethods list is preferred and empty values dropped', () {
      final methods = parseStoredPaymentMethods({
        'customPaymentMethods': [
          {'name': 'PayPal', 'value': 'paypal.me/omar'},
          {'name': 'Zelle', 'value': '  '},
          {'name': 'Swish', 'value': '0701234567', 'type': 'swish'},
          'garbage',
        ],
        'paymentMethods': {'venmo': 'ignored'},
      });
      expect(methods.map((m) => m.type.id), ['paypal', 'swish']);
      expect(methods.first.handle, 'omar');
      expect(methods.first.isValid, isTrue);
    });

    test('falls back to the legacy paymentMethods map', () {
      final methods = parseStoredPaymentMethods({
        'paymentMethods': {'instapay': 'omar@instapay', 'vodafone': ''},
      });
      expect(methods.single.type.id, 'instapay');
    });

    test('bill paymentMethods map', () {
      final methods = parseBillPaymentMethods({
        'Venmo': '@omar',
        'Bank Transfer': 'DE89370400440532013000',
      });
      expect(methods.map((m) => m.type.id), ['venmo', 'bank_transfer']);
      expect(parseStoredPaymentMethods(null), isEmpty);
      expect(parseBillPaymentMethods(null), isEmpty);
    });

    test('toStorage keeps name/value and adds type', () {
      final m = adaptLegacyPaymentMethod('Cash App', r'$Omar');
      expect(m.toStorage(), {
        'name': 'Cash App',
        'value': r'$Omar',
        'type': 'cash_app',
      });
      expect(toStoredPaymentMethodList([m]).single['type'], 'cash_app');
    });
  });
}
