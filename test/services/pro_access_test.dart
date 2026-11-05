import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/pro_access.dart';

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(home: Builder(builder: (c) => (ctx = c, const SizedBox()).$2)),
  );
  return ctx;
}

void main() {
  testWidgets('Pro users pass without the paywall', (tester) async {
    var shown = 0;
    final access = ProAccess(
      loadUser: () async => {'isPremium': true},
      showPaywall: (_) async => (shown++, null).$2,
    );
    expect(await access.ensure(await _context(tester)), isTrue);
    expect(shown, 0);
  });

  testWidgets('free users see the paywall and pass only if they buy', (
    tester,
  ) async {
    var shown = 0;
    final declined = ProAccess(
      loadUser: () async => {'isPremium': false},
      showPaywall: (_) async => (shown++, false).$2,
    );
    expect(await declined.ensure(await _context(tester)), isFalse);
    expect(shown, 1);

    final bought = ProAccess(
      loadUser: () async => null,
      showPaywall: (_) async => true,
    );
    expect(await bought.ensure(await _context(tester)), isTrue);
  });

  testWidgets('expired Pro counts as free', (tester) async {
    final access = ProAccess(
      loadUser: () async => {
        'isPremium': true,
        'premiumExpiresAt': '2000-01-01T00:00:00Z',
      },
      showPaywall: (_) async => false,
    );
    expect(await access.ensure(await _context(tester)), isFalse);
  });
}
