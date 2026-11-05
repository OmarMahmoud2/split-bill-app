import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/payments/payments.dart';

void main() {
  final english =
      jsonDecode(File('assets/translations/en.json').readAsStringSync())
          as Map<String, dynamic>;

  test('every registry description and handle label is translated', () {
    for (final type in paymentMethodRegistry) {
      expect(english, contains(type.descriptionKey), reason: type.id);
    }
    for (final kind in HandleKind.values) {
      expect(english, contains(kind.labelKey), reason: kind.name);
    }
  });

  test('every instruction key produced by a launch is translated', () {
    final keys = <String>{};
    for (final type in paymentMethodRegistry) {
      for (final handle in ['omar', '+15551234567', 'https://x.example/p']) {
        final launch = type.buildLaunch(
          PaymentRequest(handle: handle, amount: Money(100, 'USD')),
        );
        keys.add(launch.instructionKey);
        if (launch is DeepLinkLaunch) keys.add(launch.fallback.instructionKey);
      }
    }
    for (final key in keys) {
      expect(english, contains(key));
      // Placeholders used in English must be ones the launch provides.
      final placeholders = RegExp(
        r'\{(\w+)\}',
      ).allMatches(english[key] as String).map((m) => m.group(1));
      expect(
        placeholders.every((p) => {'app', 'amount', 'handle'}.contains(p)),
        isTrue,
        reason: key,
      );
    }
  });
}
