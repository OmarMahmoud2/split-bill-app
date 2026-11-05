import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/emv_qr.dart';
import 'package:split_bill_app/payments/payment_method_type.dart';
import 'package:split_bill_app/payments/payment_models.dart';

PaymentMethodType _t(String id) => paymentMethodById(id)!;

PaymentRequest _req(
  String handle, {
  int? minor,
  String currency = 'USD',
  String? note,
  String? name,
}) => PaymentRequest(
  handle: handle,
  amount: minor == null ? null : Money(minor, currency),
  note: note,
  recipientName: name,
);

DeepLinkLaunch _deep(PaymentLaunch l) => l as DeepLinkLaunch;
CopyInstruction _copy(PaymentLaunch l) => l as CopyInstruction;

void main() {
  group('registry', () {
    test('ids are unique and lower snake case', () {
      final ids = paymentMethodRegistry.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id), isTrue, reason: id);
      }
    });

    test('every method has a handle kind, description and initials', () {
      for (final t in paymentMethodRegistry) {
        expect(t.handleKinds, isNotEmpty, reason: t.id);
        expect(t.descriptionKey, startsWith('payment_desc_'));
        expect(t.initials, isNotEmpty);
      }
    });

    test('Apple Cash is iOS-only and US-only', () {
      final apple = _t('apple_cash');
      expect(apple.isAvailableOn(PaymentPlatform.ios), isTrue);
      expect(apple.isAvailableOn(PaymentPlatform.android), isFalse);
      expect(apple.isAvailableOn(PaymentPlatform.macos), isFalse);
      expect(apple.countries, {'US'});
    });
  });

  group('PaymentRequest', () {
    test('formats amounts with the currency decimals', () {
      expect(_req('x', minor: 1638, currency: 'EGP').amountString, '16.38');
      expect(_req('x', minor: 5, currency: 'USD').amountString, '0.05');
      expect(_req('x', minor: 1200, currency: 'JPY').amountString, '1200');
      expect(_req('x', minor: 1500, currency: 'KWD').amountString, '1.500');
      expect(
        _req('x', minor: 1638, currency: 'EGP').displayAmount,
        'EGP 16.38',
      );
      expect(_req('x').amountString, isNull);
    });
  });

  group('PayPal', () {
    test('prefills amount and currency in a PayPal.me link', () {
      final l = _deep(
        _t('paypal').buildLaunch(_req('@omar', minor: 1638, currency: 'EUR')),
      );
      expect(l.uri.toString(), 'https://paypal.me/omar/16.38EUR');
      expect(l.prefillsAmount, isTrue);
      expect(l.instructionKey, 'payment_instruction_opens_prefilled');
    });

    test('parses a stored PayPal.me link', () {
      final l = _deep(
        _t(
          'paypal',
        ).buildLaunch(_req('https://www.paypal.me/OmarM/5', minor: 500)),
      );
      expect(l.uri.toString(), 'https://paypal.me/OmarM/5.00USD');
    });

    test('omits the amount for currencies PayPal.me does not take', () {
      final l = _deep(
        _t('paypal').buildLaunch(_req('omar', minor: 1638, currency: 'EGP')),
      );
      expect(l.uri.toString(), 'https://paypal.me/omar');
      expect(l.prefillsAmount, isFalse);
      expect(l.clipboardText, '16.38');
    });

    test('emails are copied', () {
      final l = _copy(
        _t('paypal').buildLaunch(_req('Omar@Example.com', minor: 100)),
      );
      expect(l.text, 'omar@example.com');
    });
  });

  group('Venmo', () {
    test('app link with web fallback', () {
      final l = _deep(
        _t(
          'venmo',
        ).buildLaunch(_req('@omar-m', minor: 1250, note: 'Sea Breeze Grill')),
      );
      expect(
        l.uri.toString(),
        'venmo://paycharge?txn=pay&recipients=omar-m&amount=12.50'
        '&note=Sea%20Breeze%20Grill',
      );
      expect(
        l.webFallback.toString(),
        'https://venmo.com/?txn=pay&recipients=omar-m&amount=12.50'
        '&note=Sea%20Breeze%20Grill',
      );
      expect(l.prefillsAmount, isTrue);
    });

    test('venmo.com/u/<user> links are understood', () {
      expect(
        _t('venmo').normalizeHandle('https://venmo.com/u/Omar-M'),
        'Omar-M',
      );
    });
  });

  group('Cash App', () {
    test('cashtag with amount', () {
      final l = _deep(_t('cash_app').buildLaunch(_req('OmarM', minor: 2000)));
      expect(l.uri.toString(), r'https://cash.app/$OmarM/20.00');
    });

    test('validates cashtags', () {
      expect(_t('cash_app').validateHandle(r'$Omar_1'), isTrue);
      expect(_t('cash_app').validateHandle(r'$1234'), isFalse);
    });
  });

  test('Monzo prefills GBP amount and note', () {
    final l = _deep(
      _t(
        'monzo',
      ).buildLaunch(_req('omar', minor: 1050, currency: 'GBP', note: 'Pizza')),
    );
    expect(l.uri.toString(), 'https://monzo.me/omar/10.50?d=Pizza');
  });

  group('recipient-only links', () {
    test('Revolut opens revolut.me and copies the amount', () {
      final l = _deep(
        _t('revolut').buildLaunch(_req('@omarm', minor: 990, currency: 'EUR')),
      );
      expect(l.uri.toString(), 'https://revolut.me/omarm');
      expect(l.prefillsAmount, isFalse);
      expect(l.clipboardText, '9.90');
      expect(l.instructionKey, 'payment_instruction_opens_enter_amount');
    });

    test('Toss opens toss.me', () {
      final l = _deep(
        _t('toss').buildLaunch(_req('omar', minor: 10000, currency: 'KRW')),
      );
      expect(l.uri.toString(), 'https://toss.me/omar');
    });

    test('a pasted provider link we cannot rebuild is opened as-is', () {
      final l = _deep(
        _t('instapay').buildLaunch(
          _req(
            'https://ipn.eg/S/omar/instapay/ABC123',
            minor: 1638,
            currency: 'EGP',
          ),
        ),
      );
      expect(l.uri.toString(), 'https://ipn.eg/S/omar/instapay/ABC123');
      expect(l.clipboardText, '16.38');
    });
  });

  group('UPI', () {
    test('deep link and QR share the same intent string', () {
      final r = _req(
        'omar@okaxis',
        minor: 25000,
        currency: 'INR',
        note: 'Dinner',
        name: 'Omar',
      );
      final l = _deep(_t('upi').buildLaunch(r));
      expect(
        l.uri.toString(),
        'upi://pay?pa=omar@okaxis&pn=Omar&am=250.00&cu=INR&tn=Dinner',
      );
      expect(_t('upi').qrPayload(r), l.uri.toString());
    });

    test('non-INR bills leave the amount open', () {
      final l = _deep(_t('upi').buildLaunch(_req('omar@okaxis', minor: 100)));
      expect(l.uri.queryParameters.containsKey('am'), isFalse);
      expect(l.prefillsAmount, isFalse);
    });
  });

  test('Swish builds the prefilled app-switch payload', () {
    final l = _deep(
      _t('swish').buildLaunch(
        _req('+46 70 123 45 67', minor: 15000, currency: 'SEK', note: 'Fika'),
      ),
    );
    expect(l.uri.scheme, 'swish');
    final data = jsonDecode(l.uri.queryParameters['data']!) as Map;
    expect(data['version'], 1);
    expect(data['payee'], {'value': '0701234567', 'editable': false});
    expect(data['amount'], {'value': 150.0, 'editable': false});
    expect(data['message'], {'value': 'Fika', 'editable': true});
    expect(l.fallback.text, '+46701234567');
  });

  group('Apple Cash', () {
    test('opens Messages with a prefilled note', () {
      final l = _deep(
        _t('apple_cash').buildLaunch(
          _req('+1 (555) 123-4567', minor: 1638, note: 'Sea Breeze Grill'),
        ),
      );
      expect(
        l.uri.toString(),
        'sms:+15551234567&body=Paying%20you%20USD%2016.38%20for%20'
        'Sea%20Breeze%20Grill%20via%20Apple%20Cash',
      );
      expect(l.instructionKey, 'payment_instruction_apple_cash');
      expect(l.prefillsAmount, isFalse);
    });

    test('uses a localized message when given and supports emails', () {
      final l = _deep(
        _t('apple_cash').buildLaunch(
          PaymentRequest(
            handle: 'omar@icloud.com',
            amount: Money(500, 'USD'),
            message: 'Hola',
          ),
        ),
      );
      expect(l.uri.toString(), 'sms:omar@icloud.com&body=Hola');
    });
  });

  test('Zelle copies the email/phone with bank-app instructions', () {
    final l = _copy(_t('zelle').buildLaunch(_req('omar@bank.com', minor: 100)));
    expect(l.text, 'omar@bank.com');
    expect(l.instructionKey, 'payment_instruction_zelle');
    expect(l.instructionArgs['amount'], 'USD 1.00');
  });

  group('copy-only wallets', () {
    for (final id in [
      'bizum',
      'mb_way',
      'twint',
      'vipps',
      'mobilepay',
      'blik',
      'mpesa',
      'vodafone_cash',
      'gcash',
      'bkash',
    ]) {
      test('$id copies the normalized phone', () {
        final l = _copy(
          _t(
            id,
          ).buildLaunch(_req('+34 612 34 56 78', minor: 100, currency: 'EUR')),
        );
        expect(l.text, '+34612345678');
        expect(l.instructionKey, 'payment_instruction_copy_handle');
        expect(l.instructionArgs['app'], _t(id).displayName);
      });
    }
  });

  group('QR methods', () {
    test('Pix copies the BR Code and shows it as QR', () {
      final r = _req(
        '123.456.789-01',
        minor: 1638,
        currency: 'BRL',
        name: 'Omar',
        note: 'Jantar',
      );
      final l = _copy(_t('pix').buildLaunch(r));
      expect(l.instructionKey, 'payment_instruction_copy_code');
      expect(l.text, _t('pix').qrPayload(r));
      final fields = parseEmvFields(l.text);
      expect(parseEmvFields(fields['26']!)['01'], '12345678901');
      expect(fields['54'], '16.38');
      expect(hasValidEmvCrc(l.text), isTrue);
    });

    test('PromptPay QR carries THB amount', () {
      final r = _req('081-234-5678', minor: 10050, currency: 'THB');
      final l = _copy(_t('promptpay').buildLaunch(r));
      expect(l.instructionKey, 'payment_instruction_scan_qr');
      expect(l.text, '0812345678');
      final fields = parseEmvFields(_t('promptpay').qrPayload(r)!);
      expect(fields['54'], '100.50');
      expect(parseEmvFields(fields['29']!)['01'], '0066812345678');
    });

    test('PayNow and VietQR produce payloads', () {
      expect(
        _t('paynow').qrPayload(_req('91234567', minor: 1000, currency: 'SGD')),
        isNotNull,
      );
      final viet = _t(
        'vietqr',
      ).qrPayload(_req('970436 0011001932418', minor: 50000, currency: 'VND'));
      expect(parseEmvFields(viet!)['54'], '50000');
    });

    test('SEPA EPC QR only for EUR', () {
      final eur = _t('sepa_qr').qrPayload(
        _req(
          'DE89370400440532013000',
          minor: 1230,
          currency: 'EUR',
          name: 'Omar',
        ),
      );
      expect(
        eur,
        startsWith('BCD\n002\n1\nSCT\n\nOmar\nDE89370400440532013000\nEUR12.3'),
      );
      expect(
        _t('sepa_qr').qrPayload(
          _req('DE89370400440532013000', minor: 1230, currency: 'USD'),
        ),
        isNull,
      );
      expect(
        _t('bank_transfer').qrPayload(
          _req('DE89370400440532013000', minor: 1230, currency: 'EUR'),
        ),
        isNotNull,
      );
      expect(
        _t('bank_transfer').qrPayload(
          _req('Acc 1234 sort 00-00-00', minor: 1230, currency: 'EUR'),
        ),
        isNull,
      );
    });

    test('Czech QR Platba', () {
      expect(
        _t('cz_qr_platba').qrPayload(
          _req('CZ5855000000001265098001', minor: 48050, currency: 'CZK'),
        ),
        'SPD*1.0*ACC:CZ5855000000001265098001*AM:480.50*CC:CZK',
      );
    });

    test('invalid handles give no QR', () {
      expect(
        _t('pix').qrPayload(_req('nope', minor: 1, currency: 'BRL')),
        isNull,
      );
      expect(
        _t('promptpay').qrPayload(_req('12', minor: 1, currency: 'THB')),
        isNull,
      );
    });
  });

  group('validation', () {
    final cases = <String, Map<String, bool>>{
      'phone': {'+20 101 234 5678': true, '12': false, 'abc': false},
      'email': {'a@b.co': true, 'a@b': false},
      'iban': {'DE89370400440532013000': true, 'DE00': false},
      'upi': {'omar@okaxis': true, 'omar': false},
      'pix': {
        '123.456.789-01': true,
        '12.345.678/0001-95': true,
        '+5511987654321': true,
        'a@b.co': true,
        '123e4567-e12b-12d1-a456-426655440000': true,
        '12345': false,
      },
      'promptpay': {'0812345678': true, '1111111111111': true, '123': false},
      'paynow': {'+65 9123 4567': true, '201403121W': true, '12345': false},
      'clabe': {'002010077777777771': true, '002010077777777770': false},
      'vietqr': {'970436 0011001932418': true, '0011001932418': false},
      'url': {'https://tikkie.me/pay/abc': true, 'tikkie': false},
    };
    final kinds = {
      'phone': HandleKind.phone,
      'email': HandleKind.email,
      'iban': HandleKind.iban,
      'upi': HandleKind.upiVpa,
      'pix': HandleKind.pixKey,
      'promptpay': HandleKind.promptPayId,
      'paynow': HandleKind.payNowProxy,
      'clabe': HandleKind.clabe,
      'vietqr': HandleKind.vietQrAccount,
      'url': HandleKind.url,
    };
    cases.forEach((name, samples) {
      test(name, () {
        samples.forEach((value, valid) {
          expect(kinds[name]!.validate(value), valid, reason: value);
        });
      });
    });

    test('every kind has a label key', () {
      for (final kind in HandleKind.values) {
        expect(kind.labelKey, startsWith('payment_handle_'));
      }
    });
  });
}
