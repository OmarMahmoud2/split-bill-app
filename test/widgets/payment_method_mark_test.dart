import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/payment_method_mark.dart';

void main() {
  Future<void> pump(WidgetTester t, PaymentMethodType type) => t.pumpWidget(
    MaterialApp(home: Scaffold(body: PaymentMethodMark(type: type))),
  );

  PaymentMethodType byId(String id) =>
      paymentMethodRegistry.firstWhere((m) => m.id == id);

  testWidgets('brand glyph methods render an Icon, not initials', (t) async {
    for (final id in ['revolut', 'wise', 'cash_app', 'zelle', 'pix']) {
      await pump(t, byId(id));
      expect(find.byType(Icon), findsOneWidget, reason: id);
      expect(find.text(byId(id).initials), findsNothing, reason: id);
    }
  });

  testWidgets('generic types render a duotone icon', (t) async {
    for (final id in ['bank_transfer', 'other']) {
      await pump(t, byId(id));
      expect(find.byType(AppDuoIcon), findsOneWidget, reason: id);
    }
  });

  testWidgets('unknown brands keep a monogram', (t) async {
    await pump(t, byId('swish'));
    expect(find.text('SW'), findsOneWidget);
  });
}
