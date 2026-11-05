import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/config/supported_preferences.dart';

/// Active ISO 4217 currencies (fund and precious-metal codes excluded).
const _activeIsoCodes = '''
AED AFN ALL AMD AOA ARS AUD AWG AZN BAM BBD BDT BHD BIF BMD BND BOB BRL BSD
BTN BWP BYN BZD CAD CDF CHF CLP CNY COP CRC CUP CVE CZK DJF DKK DOP DZD EGP
ERN ETB EUR FJD FKP GBP GEL GHS GIP GMD GNF GTQ GYD HKD HNL HTG HUF IDR ILS
INR IQD IRR ISK JMD JOD JPY KES KGS KHR KMF KPW KRW KWD KYD KZT LAK LBP LKR
LRD LSL LYD MAD MDL MGA MKD MMK MNT MOP MRU MUR MVR MWK MXN MYR MZN NAD NGN
NIO NOK NPR NZD OMR PAB PEN PGK PHP PKR PLN PYG QAR RON RSD RUB RWF SAR SBD
SCR SDG SEK SGD SHP SLE SOS SRD SSP STN SVC SYP SZL THB TJS TMT TND TOP TRY
TTD TWD TZS UAH UGX USD UYU UZS VED VES VND VUV WST XAF XCD XCG XOF XPF YER
ZAR ZMW ZWG
''';

void main() {
  final byCode = {for (final c in supportedCurrencyOptions) c.code: c};

  test('currency codes are unique and valid', () {
    expect(byCode.length, supportedCurrencyOptions.length);
    for (final code in byCode.keys) {
      expect(sanitizeCurrencyCode(code), code);
    }
  });

  test('covers every active ISO 4217 currency', () {
    final iso = _activeIsoCodes
        .split(RegExp(r'\s+'))
        .where((c) => c.isNotEmpty);
    final missing = iso.where((c) => !byCode.containsKey(c));
    expect(missing, isEmpty);
  });

  test('uses ISO 4217 minor units', () {
    const zero = [
      'BIF', 'CLP', 'DJF', 'GNF', 'ISK', 'JPY', 'KMF', 'KRW', //
      'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF',
    ];
    const three = ['BHD', 'IQD', 'JOD', 'KWD', 'LYD', 'OMR', 'TND'];
    for (final option in supportedCurrencyOptions) {
      final expected = zero.contains(option.code)
          ? 0
          : three.contains(option.code)
          ? 3
          : 2;
      expect(option.decimalDigits, expected, reason: option.code);
    }
    expect(currencyDecimalDigits('jpy'), 0);
    expect(currencyDecimalDigits('KWD'), 3);
    expect(currencyDecimalDigits('SDGX'), 2);
  });

  test('keeps popular currencies first, then the rest alphabetically', () {
    final codes = supportedCurrencyOptions.map((c) => c.code).toList();
    expect(codes.take(3), ['USD', 'EUR', 'GBP']);
    final tail = codes.sublist(codes.indexOf('MXN') + 1);
    expect(tail, [...tail]..sort());
  });

  test('every currency has a name, symbol and region', () {
    for (final option in supportedCurrencyOptions) {
      expect(option.name, isNotEmpty, reason: option.code);
      expect(option.symbol, isNotEmpty, reason: option.code);
      expect(option.region, isNotEmpty, reason: option.code);
    }
  });
}
