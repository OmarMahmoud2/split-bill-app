import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/utils/money_format.dart';

void main() {
  const nbsp = '\u00A0';

  group('decimals per currency', () {
    test('USD uses 2', () {
      expect(formatMoneyMinor(6240, 'USD', locale: 'en'), r'$62.40');
      expect(formatMoneyMinor(5, 'USD', locale: 'en'), r'$0.05');
      expect(formatMoneyMinor(128450, 'USD', locale: 'en'), r'$1,284.50');
    });

    test('JPY uses 0', () {
      expect(formatMoneyMinor(1500, 'JPY', locale: 'en'), '¥1,500');
    });

    test('KWD uses 3 and an Arabic symbol after the number', () {
      expect(formatMoneyMinor(1500, 'KWD', locale: 'en'), '1.500$nbspد.ك');
      expect(formatMoneyMinor(1, 'KWD', locale: 'en'), '0.001$nbspد.ك');
    });

    test('EGP uses 2', () {
      expect(formatMoneyMinor(8127, 'EGP', locale: 'en'), 'E£81.27');
    });

    test('custom codes show the code with 2 decimals', () {
      expect(formatMoneyMinor(100, 'abc', locale: 'en'), 'ABC${nbsp}1.00');
    });
  });

  group('sign', () {
    test('always: + for positive, U+2212 for negative, none for zero', () {
      expect(
        formatMoneyMinor(6240, 'USD', sign: MoneySign.always, locale: 'en'),
        r'+$62.40',
      );
      expect(
        formatMoneyMinor(-6240, 'USD', sign: MoneySign.always, locale: 'en'),
        '$kMinusSign\$62.40',
      );
      expect(
        formatMoneyMinor(0, 'USD', sign: MoneySign.always, locale: 'en'),
        r'$0.00',
      );
    });

    test('negativeOnly and none', () {
      expect(formatMoneyMinor(6240, 'USD', locale: 'en'), r'$62.40');
      expect(formatMoneyMinor(-1500, 'JPY', locale: 'en'), '$kMinusSign¥1,500');
      expect(
        formatMoneyMinor(-1500, 'KWD', sign: MoneySign.none, locale: 'en'),
        '1.500$nbspد.ك',
      );
    });
  });

  test('locale separators, Latin digits', () {
    expect(formatMoneyMinor(128450, 'EUR', locale: 'de'), '€1.284,50');
    expect(formatMoneyMinor(128450, 'USD', locale: 'ar'), r'$1,284.50');
  });

  test('formatMoney takes a domain Money', () {
    expect(
      formatMoney(Money.fromDouble(-12.5, 'egp'), locale: 'en'),
      '${kMinusSign}E£12.50',
    );
  });

  test('showSymbol false gives the bare number', () {
    expect(
      formatMoneyMinor(123456, 'KWD', showSymbol: false, locale: 'en'),
      '123.456',
    );
  });
}
