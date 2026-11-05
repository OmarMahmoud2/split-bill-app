import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/payments/country_methods.dart';
import 'package:split_bill_app/payments/payment_method_type.dart';
import 'package:split_bill_app/payments/payment_models.dart';

List<String> _ids(List<PaymentMethodType> l) => l.map((t) => t.id).toList();

void main() {
  const priorityCountries = [
    'US',
    'GB',
    'CA',
    'AU',
    'NZ',
    'IE',
    'DE',
    'AT',
    'CH',
    'FR',
    'BE',
    'NL',
    'LU',
    'ES',
    'PT',
    'IT',
    'SE',
    'NO',
    'DK',
    'FI',
    'IS',
    'PL',
    'CZ',
    'TR',
    'RU',
    'UA',
    'EG',
    'SA',
    'AE',
    'KW',
    'QA',
    'BH',
    'OM',
    'JO',
    'LB',
    'MA',
    'TN',
    'DZ',
    'IQ',
    'PK',
    'IN',
    'BD',
    'ID',
    'MY',
    'SG',
    'PH',
    'TH',
    'VN',
    'JP',
    'KR',
    'CN',
    'HK',
    'TW',
    'BR',
    'MX',
    'AR',
    'CO',
    'CL',
    'PE',
    'NG',
    'KE',
    'ZA',
    'GH',
  ];

  test('every priority country has at least one local method', () {
    for (final cc in priorityCountries) {
      expect(countryPaymentMethodIds[cc], isNotEmpty, reason: cc);
    }
  });

  test('every mapped id exists in the registry', () {
    for (final entry in countryPaymentMethodIds.entries) {
      for (final id in entry.value) {
        expect(paymentMethodById(id), isNotNull, reason: '${entry.key}: $id');
      }
    }
    for (final id in globalPaymentMethodIds) {
      expect(paymentMethodById(id), isNotNull);
    }
  });

  test('local methods come first, then global ones, no duplicates', () {
    expect(_ids(methodsForCountry('us')), [
      'venmo',
      'zelle',
      'cash_app',
      'apple_cash',
      'paypal',
      'revolut',
      'wise',
      'bank_transfer',
      'other',
    ]);
    final de = _ids(methodsForCountry('DE'));
    expect(de.take(3), ['paypal', 'sepa_qr', 'wero']);
    expect(de.where((id) => id == 'paypal').length, 1);
    expect(_ids(methodsForCountry('BR')).first, 'pix');
    expect(_ids(methodsForCountry('IN')).first, 'upi');
    expect(_ids(methodsForCountry('SE')).first, 'swish');
    expect(_ids(methodsForCountry('EG')).take(2), [
      'instapay',
      'vodafone_cash',
    ]);
  });

  test('unknown countries get the global list; other euro countries SEPA', () {
    expect(_ids(methodsForCountry(null)), globalPaymentMethodIds);
    expect(_ids(methodsForCountry('ZZ')), globalPaymentMethodIds);
    expect(_ids(methodsForCountry('EE')).take(2), ['sepa_qr', 'wero']);
  });

  test('platform filter drops Apple Cash off iOS', () {
    expect(
      _ids(methodsForCountry('US', platform: PaymentPlatform.android)),
      isNot(contains('apple_cash')),
    );
    expect(
      _ids(methodsForCountry('US', platform: PaymentPlatform.ios)),
      contains('apple_cash'),
    );
  });

  group('detection', () {
    test('locale region wins', () {
      expect(detectPaymentCountry(localeTag: 'en_US'), 'US');
      expect(detectPaymentCountry(localeTag: 'pt-BR', currency: 'EUR'), 'BR');
      expect(detectPaymentCountry(localeTag: 'zh_Hant_TW'), 'TW');
      expect(detectPaymentCountry(localeTag: 'SE'), 'SE');
    });

    test('falls back to the currency home country', () {
      expect(detectPaymentCountry(localeTag: 'ar', currency: 'egp'), 'EG');
      expect(detectPaymentCountry(currency: 'INR'), 'IN');
      expect(detectPaymentCountry(currency: 'EUR'), isNull);
      expect(detectPaymentCountry(), isNull);
    });

    test('recommendedPaymentMethods handles euro without a region', () {
      expect(
        _ids(recommendedPaymentMethods(localeTag: 'de', currency: 'EUR')).first,
        'sepa_qr',
      );
      expect(
        _ids(
          recommendedPaymentMethods(localeTag: 'th_TH', currency: 'THB'),
        ).first,
        'promptpay',
      );
      expect(_ids(methodsForCurrency('SEK')).first, 'swish');
    });
  });
}
