import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/payments/emv_qr.dart';

void main() {
  group('crc16Ccitt', () {
    test('CRC-16/CCITT-FALSE check value', () {
      // Standard check value for "123456789".
      expect(crc16Ccitt('123456789'), '29B1');
    });
  });

  group('Pix BR Code', () {
    test('matches the Banco Central do Brasil manual example', () {
      // Manual de Padrões para Iniciação do Pix, static BR Code example.
      const expected =
          '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-42665544'
          '00005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***'
          '63041D3D';
      final payload = buildPixPayload(
        key: '123e4567-e12b-12d1-a456-426655440000',
        merchantName: 'Fulano de Tal',
        merchantCity: 'Brasilia',
      );
      expect(payload, expected);
      expect(hasValidEmvCrc(payload), isTrue);
    });

    test('adds amount and description, folds accents, keeps CRC valid', () {
      final payload = buildPixPayload(
        key: 'omar@example.com',
        merchantName: 'João Conceição',
        merchantCity: 'São Paulo',
        amount: '16.38',
        description: 'Sea Breeze Grill',
      );
      final fields = parseEmvFields(payload);
      expect(fields['54'], '16.38');
      expect(fields['59'], 'Joao Conceicao');
      expect(fields['60'], 'SAO PAULO');
      final account = parseEmvFields(fields['26']!);
      expect(account['00'], 'br.gov.bcb.pix');
      expect(account['01'], 'omar@example.com');
      expect(account['02'], 'Sea Breeze Grill');
      expect(parseEmvFields(fields['62']!)['05'], '***');
      expect(hasValidEmvCrc(payload), isTrue);
    });

    test('truncates long names to the BR Code limits', () {
      final fields = parseEmvFields(
        buildPixPayload(
          key: '12345678901',
          merchantName: 'A' * 40,
          merchantCity: 'B' * 30,
        ),
      );
      expect(fields['59']!.length, 25);
      expect(fields['60']!.length, 15);
    });

    test('a tampered payload fails the CRC check', () {
      final payload = buildPixPayload(
        key: '12345678901',
        merchantName: 'A',
        merchantCity: 'B',
        amount: '10.00',
      );
      expect(hasValidEmvCrc(payload.replaceFirst('10.00', '99.00')), isFalse);
    });
  });

  group('PromptPay', () {
    // Vectors from the reference implementation dtinth/promptpay-qr.
    test('mobile number without amount', () {
      expect(
        buildPromptPayPayload(id: '000-000-0000'),
        '00020101021129370016A000000677010111011300660000000005802TH53037646304'
        '8956',
      );
    });

    test('mobile number with amount', () {
      expect(
        buildPromptPayPayload(id: '0000000000', amount: '4.22'),
        '00020101021229370016A000000677010111011300660000000005802TH53037645404'
        '4.226304E469',
      );
    });

    test('national id', () {
      expect(
        buildPromptPayPayload(id: '1111111111111'),
        '00020101021129370016A000000677010111021311111111111115802TH53037646304'
        '7B5A',
      );
    });

    test('e-wallet id uses sub-tag 03', () {
      final fields = parseEmvFields(
        buildPromptPayPayload(id: '123456789012345'),
      );
      expect(parseEmvFields(fields['29']!)['03'], '123456789012345');
    });

    test('rejects ids of the wrong length', () {
      expect(() => buildPromptPayPayload(id: '1234'), throwsArgumentError);
      expect(promptPayProxyFor('0812345678'), PromptPayProxy.mobile);
    });
  });

  group('PayNow', () {
    test('mobile proxy with fixed amount', () {
      final payload = buildPayNowPayload(
        proxy: '9123 4567',
        merchantName: 'Omar',
        amount: '12.50',
        reference: 'Dinner #1',
      );
      final fields = parseEmvFields(payload);
      expect(fields['01'], '12');
      expect(fields['53'], '702');
      expect(fields['54'], '12.50');
      expect(fields['58'], 'SG');
      final merchant = parseEmvFields(fields['26']!);
      expect(merchant, {
        '00': 'SG.PAYNOW',
        '01': '0',
        '02': '+6591234567',
        '03': '0',
      });
      expect(parseEmvFields(fields['62']!)['01'], 'Dinner 1');
      expect(hasValidEmvCrc(payload), isTrue);
    });

    test('UEN proxy, open amount is editable', () {
      final fields = parseEmvFields(
        buildPayNowPayload(proxy: '201403121W', merchantName: 'Shop'),
      );
      final merchant = parseEmvFields(fields['26']!);
      expect(merchant['01'], '2');
      expect(merchant['02'], '201403121W');
      expect(merchant['03'], '1');
      expect(fields.containsKey('54'), isFalse);
    });
  });

  group('VietQR', () {
    test('account transfer with amount and message', () {
      final payload = buildVietQrPayload(
        bankBin: '970436',
        accountNumber: '0011001932418',
        amount: '150000',
        message: 'Tien an toi',
      );
      final fields = parseEmvFields(payload);
      expect(fields['53'], '704');
      expect(fields['54'], '150000');
      final merchant = parseEmvFields(fields['38']!);
      expect(merchant['00'], 'A000000727');
      expect(merchant['02'], 'QRIBFTTA');
      expect(parseEmvFields(merchant['01']!), {
        '00': '970436',
        '01': '0011001932418',
      });
      expect(parseEmvFields(fields['62']!)['08'], 'Tien an toi');
      expect(hasValidEmvCrc(payload), isTrue);
    });
  });

  test('emvField rejects values over 99 characters', () {
    expect(() => emvField('01', 'x' * 100), throwsArgumentError);
    expect(emvField('01', 'abc'), '0103abc');
  });
}
