import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/domain_errors.dart';
import 'package:split_bill_app/domain/money.dart';

void main() {
  group('currencyDecimals', () {
    test('defaults to 2 for common currencies', () {
      expect(currencyDecimals('USD'), 2);
      expect(currencyDecimals('EGP'), 2);
      expect(currencyDecimals('EUR'), 2);
    });

    test('zero-decimal currencies', () {
      expect(currencyDecimals('JPY'), 0);
      expect(currencyDecimals('KRW'), 0);
      expect(currencyDecimals('VND'), 0);
      expect(currencyDecimals('CLP'), 0);
      expect(currencyDecimals('UGX'), 0);
    });

    test('three-decimal currencies', () {
      expect(currencyDecimals('KWD'), 3);
      expect(currencyDecimals('BHD'), 3);
      expect(currencyDecimals('OMR'), 3);
      expect(currencyDecimals('TND'), 3);
      expect(currencyDecimals('JOD'), 3);
    });

    test('is case and whitespace insensitive', () {
      expect(currencyDecimals(' jpy '), 0);
      expect(currencyDecimals('kwd'), 3);
    });

    test('unknown/custom currency codes fall back to 2', () {
      expect(currencyDecimals('ABCD'), 2);
    });
  });

  group('toMinorUnits', () {
    test('converts whole and fractional amounts', () {
      expect(toMinorUnits(12.34, 'USD'), 1234);
      expect(toMinorUnits(0, 'USD'), 0);
      expect(toMinorUnits(1500, 'JPY'), 1500);
      expect(toMinorUnits(1.234, 'KWD'), 1234);
    });

    test('rounds half away from zero on the decimal value the user typed', () {
      // 1.005 is 1.00499999... in binary; naive (x*100).round() gives 100.
      expect(toMinorUnits(1.005, 'USD'), 101);
      expect(toMinorUnits(2.675, 'USD'), 268);
      expect(toMinorUnits(0.125, 'USD'), 13);
      expect(toMinorUnits(1.0005, 'KWD'), 1001);
      expect(toMinorUnits(99.5, 'JPY'), 100);
    });

    test('rounds below half down', () {
      expect(toMinorUnits(1.004, 'USD'), 100);
      expect(toMinorUnits(99.4, 'JPY'), 99);
    });

    test('handles floating point sums like 0.1 + 0.2', () {
      expect(toMinorUnits(0.1 + 0.2, 'USD'), 30);
    });

    test('negative amounts round symmetrically', () {
      expect(toMinorUnits(-1.005, 'USD'), -101);
      expect(toMinorUnits(-12.34, 'USD'), -1234);
    });

    test('handles exponent notation', () {
      expect(toMinorUnits(1e-7, 'USD'), 0);
      expect(toMinorUnits(1e15, 'JPY'), 1000000000000000);
    });

    test('rejects NaN and infinity', () {
      expect(() => toMinorUnits(double.nan, 'USD'),
          throwsA(isA<InvalidAmountError>()));
      expect(() => toMinorUnits(double.infinity, 'USD'),
          throwsA(isA<InvalidAmountError>()));
    });
  });

  group('fromMinorUnits', () {
    test('converts back to a double', () {
      expect(fromMinorUnits(1234, 'USD'), 12.34);
      expect(fromMinorUnits(1500, 'JPY'), 1500.0);
      expect(fromMinorUnits(1234, 'KWD'), 1.234);
      expect(fromMinorUnits(-5, 'USD'), -0.05);
    });

    test('round-trips', () {
      for (final v in [0.01, 0.1, 19.99, 1234.56, 0.07]) {
        expect(fromMinorUnits(toMinorUnits(v, 'USD'), 'USD'), v);
      }
    });
  });

  group('Money', () {
    test('fromDouble normalises currency and converts', () {
      final m = Money.fromDouble(12.345, 'usd');
      expect(m.currency, 'USD');
      expect(m.minor, 1235);
      expect(m.toDouble(), 12.35);
    });

    test('value equality', () {
      expect(const Money(100, 'USD'), const Money(100, 'USD'));
      expect(const Money(100, 'USD') == const Money(100, 'EUR'), isFalse);
      expect(const Money(100, 'USD').hashCode,
          const Money(100, 'USD').hashCode);
    });

    test('arithmetic in same currency', () {
      const a = Money(150, 'USD');
      const b = Money(50, 'USD');
      expect(a + b, const Money(200, 'USD'));
      expect(a - b, const Money(100, 'USD'));
      expect(-a, const Money(-150, 'USD'));
      expect(a.isZero, isFalse);
      expect(const Money(0, 'USD').isZero, isTrue);
      expect((b - a).isNegative, isTrue);
    });

    test('arithmetic across currencies throws', () {
      expect(() => const Money(1, 'USD') + const Money(1, 'EUR'),
          throwsA(isA<CurrencyMismatchError>()));
    });

    test('toString uses currency decimals', () {
      expect(const Money(1234, 'USD').toString(), '12.34 USD');
      expect(const Money(1500, 'JPY').toString(), '1500 JPY');
      expect(const Money(1005, 'KWD').toString(), '1.005 KWD');
      expect(const Money(-5, 'USD').toString(), '-0.05 USD');
    });
  });
}
