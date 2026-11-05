import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/payments/bank_formats.dart';

void main() {
  group('IBAN', () {
    test('accepts valid IBANs with spaces and lower case', () {
      expect(isValidIban('DE89 3704 0044 0532 0130 00'), isTrue);
      expect(isValidIban('gb29nwbk60161331926819'), isTrue);
      expect(isValidIban('EG380019000500000000263180002'), isTrue);
      expect(isValidIban('SA0380000000608010167519'), isTrue);
    });

    test('rejects bad checksum or length', () {
      expect(isValidIban('DE89370400440532013001'), isFalse);
      expect(isValidIban('DE8937040044053201300'), isFalse);
      expect(isValidIban('not an iban'), isFalse);
    });
  });

  group('EPC QR (GiroCode)', () {
    test('builds version 002 with amount and remittance text', () {
      final payload = buildEpcQrPayload(
        name: 'Franz Mustermänn',
        iban: 'DE89 3704 0044 0532 0130 00',
        amountEur: '12.30',
        remittance: 'Sea Breeze Grill',
      );
      expect(
        payload,
        'BCD\n002\n1\nSCT\n\nFranz Mustermänn\nDE89370400440532013000\n'
        'EUR12.3\n\n\nSea Breeze Grill',
      );
    });

    test('matches the EPC069-12 example layout with BIC and purpose', () {
      final payload = buildEpcQrPayload(
        name: 'Red Cross',
        iban: 'BE72000000001616',
        bic: 'BPOTBEB1',
        amountEur: '1',
        purpose: 'char',
      );
      expect(
        payload,
        'BCD\n002\n1\nSCT\nBPOTBEB1\nRed Cross\nBE72000000001616\nEUR1\nCHAR',
      );
    });

    test('open amount and invalid input', () {
      expect(
        buildEpcQrPayload(name: 'A', iban: 'DE89370400440532013000'),
        'BCD\n002\n1\nSCT\n\nA\nDE89370400440532013000',
      );
      expect(
        () => buildEpcQrPayload(name: 'A', iban: 'DE00370400440532013000'),
        throwsArgumentError,
      );
      expect(
        () => buildEpcQrPayload(
          name: 'A',
          iban: 'DE89370400440532013000',
          amountEur: '0',
        ),
        throwsArgumentError,
      );
    });
  });

  group('SPAYD (QR Platba)', () {
    test('matches the ČBA standard example', () {
      expect(
        buildSpaydPayload(
          iban: 'CZ5855000000001265098001',
          amount: '480.5',
          message: 'Platba za elektrinu',
        ),
        'SPD*1.0*ACC:CZ5855000000001265098001*AM:480.50*CC:CZK'
        '*MSG:Platba za elektrinu',
      );
    });

    test('escapes asterisks', () {
      expect(
        buildSpaydPayload(iban: 'CZ5855000000001265098001', message: 'a*b'),
        'SPD*1.0*ACC:CZ5855000000001265098001*CC:CZK*MSG:a%2Ab',
      );
    });
  });

  group('CLABE', () {
    test('validates the check digit', () {
      expect(isValidClabe('002010077777777771'), isTrue);
      expect(isValidClabe('002 010 07777777777 1'), isTrue);
      expect(isValidClabe('002010077777777772'), isFalse);
      expect(isValidClabe('12345'), isFalse);
    });
  });

  group('UPI', () {
    test('builds the NPCI pay intent', () {
      expect(
        buildUpiUri(
          vpa: 'omar@okhdfcbank',
          payeeName: 'Omar M',
          amount: '250',
          note: 'Dinner & drinks',
        ).toString(),
        'upi://pay?pa=omar@okhdfcbank&pn=Omar%20M&am=250.00&cu=INR'
        '&tn=Dinner%20%26%20drinks',
      );
    });

    test('omits empty optional fields', () {
      expect(
        buildUpiUri(vpa: 'a.b@ybl').toString(),
        'upi://pay?pa=a.b@ybl&cu=INR',
      );
      expect(upiVpaPattern.hasMatch('omar@upi'), isTrue);
      expect(upiVpaPattern.hasMatch('omar.upi'), isFalse);
    });
  });
}
