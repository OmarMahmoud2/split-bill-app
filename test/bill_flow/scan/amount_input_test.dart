import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/scan_receipt/amount_input.dart';

void main() {
  group('parseMinorInput', () {
    test('plain and decimal input in USD', () {
      expect(parseMinorInput('12', 'USD'), 1200);
      expect(parseMinorInput('12.5', 'USD'), 1250);
      expect(parseMinorInput('12,50', 'USD'), 1250);
      expect(parseMinorInput('0.1', 'USD'), 10);
      expect(parseMinorInput('.5', 'USD'), 50);
      expect(parseMinorInput('12.', 'USD'), 1200);
    });

    test('grouping separators', () {
      expect(parseMinorInput('1,234', 'USD'), 123400);
      expect(parseMinorInput('1,234.50', 'USD'), 123450);
      expect(parseMinorInput('1.234,50', 'EUR'), 123450);
      expect(parseMinorInput('1 234,5', 'EUR'), 123450);
      expect(parseMinorInput('1,234,567', 'USD'), 123456700);
      // Three digits after a lone separator read as grouping in USD.
      expect(parseMinorInput('12.345', 'USD'), 1234500);
    });

    test('currency decimals', () {
      expect(parseMinorInput('500', 'JPY'), 500);
      expect(parseMinorInput('1,500', 'JPY'), 1500);
      expect(parseMinorInput('12.5', 'JPY'), 13);
      expect(parseMinorInput('1.500', 'KWD'), 1500);
      expect(parseMinorInput('1.5', 'KWD'), 1500);
      expect(parseMinorInput('1.005', 'KWD'), 1005);
    });

    test('symbols, Arabic digits and separators', () {
      expect(parseMinorInput(r'$12.40', 'USD'), 1240);
      expect(parseMinorInput('EGP 81.27', 'EGP'), 8127);
      expect(parseMinorInput('٨١٫٢٧', 'EGP'), 8127);
      expect(parseMinorInput('۱۲', 'PKR'), 1200);
    });

    test('invalid input', () {
      expect(parseMinorInput('', 'USD'), isNull);
      expect(parseMinorInput('abc', 'USD'), isNull);
      expect(parseMinorInput('-5', 'USD'), isNull);
      expect(parseMinorInput('1.2.3,4,5', 'USD'), isNull);
    });
  });

  group('minorToInputText', () {
    test('uses the currency decimals', () {
      expect(minorToInputText(1250, 'USD'), '12.50');
      expect(minorToInputText(5, 'USD'), '0.05');
      expect(minorToInputText(500, 'JPY'), '500');
      expect(minorToInputText(1500, 'KWD'), '1.500');
      expect(minorToInputText(0, 'USD'), '0.00');
    });

    test('round-trips through parseMinorInput', () {
      for (final c in ['USD', 'JPY', 'KWD', 'EGP']) {
        for (final m in [0, 1, 99, 1234, 987654]) {
          expect(parseMinorInput(minorToInputText(m, c), c), m, reason: c);
        }
      }
    });
  });

  group('parseQuantityInput', () {
    test('whole numbers of at least one', () {
      expect(parseQuantityInput('3'), 3);
      expect(parseQuantityInput(' 2 '), 2);
      expect(parseQuantityInput('2.0'), 2);
      expect(parseQuantityInput('٣'), 3);
      expect(parseQuantityInput('0'), isNull);
      expect(parseQuantityInput(''), isNull);
      expect(parseQuantityInput('x'), isNull);
    });
  });
}
