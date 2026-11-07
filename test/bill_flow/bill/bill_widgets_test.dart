import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_breakdown_card.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';
import 'package:split_bill_app/widgets/bill_details/participant_bill_view.dart';
import 'package:split_bill_app/widgets/bill_details/participant_tile.dart';
import 'package:split_bill_app/widgets/bill_details/pay_methods_list.dart';
import 'package:split_bill_app/widgets/bill_details/proof_card.dart';

import 'fixtures.dart';

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  builder: (context, c) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: c!,
  ),
  home: Scaffold(body: child),
);

String _plain(String s) => s.replaceAll(RegExp('[\u2066\u2069]'), '');

Finder _text(String value) => find.byWidgetPredicate(
  (w) => w is Text && _plain(w.data ?? w.textSpan?.toPlainText() ?? '') == value,
);

/// Text of a [Text] or a [RichText] under [finder].
String _shown(WidgetTester tester, Finder finder) {
  final texts = tester.widgetList<Text>(
    find.descendant(of: finder, matching: find.byType(Text)),
  );
  return _plain(texts.map((t) => t.data ?? '').join());
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
  });

  group('ProofCard', () {
    testWidgets('host can reject the proof', (tester) async {
      var rejected = 0;
      await tester.pumpWidget(
        _app(
          ProofCard(name: 'Ali', onConfirm: () {}, onReject: () => rejected++),
        ),
      );
      await tester.tap(find.text('bf_bill_proof_reject'));
      expect(rejected, 1);
    });

    testWidgets('no reject action when none is given', (tester) async {
      await tester.pumpWidget(_app(ProofCard(name: 'Ali', onConfirm: () {})));
      expect(find.text('bf_bill_proof_reject'), findsNothing);
    });
  });

  group('BillBreakdownCard', () {
    testWidgets('2.0 bill: unit and split lines, total = sum of lines', (
      tester,
    ) async {
      final reader = BillReader(itemizedBill());
      final sara = reader.breakdownFor('sara');
      // Sara: 1 of 3 lemonades (3.00) + half the fries (3.00) + tax share.
      expect(sara.totalMinor, reader.shareMinorFor('sara'));

      await tester.pumpWidget(
        _app(BillBreakdownCard(breakdown: sara, currency: 'EGP')),
      );
      await tester.pumpAndSettle();

      expect(find.text('bf_bill_line_item_units'), findsOneWidget);
      expect(find.text('bf_bill_line_item_split'), findsOneWidget);
      expect(find.text('bf_bill_line_tax'), findsOneWidget);
      expect(_text('3.00'), findsNWidgets(2));

      final sum = sara.lines.fold(0, (s, l) => s + l.amountMinor);
      final total = find.byKey(
        const ValueKey('bf_bill_breakdown_total_amount'),
      );
      expect(total, findsOneWidget);
      expect(_shown(tester, total), _plain(formatMoneyMinor(sum, 'EGP')));
    });

    testWidgets('every person adds up to the bill total', (tester) async {
      final reader = BillReader(itemizedBill());
      var all = 0;
      for (final id in ['omar', 'sara', 'ali', 'mona']) {
        final b = reader.breakdownFor(id);
        expect(b.totalMinor, reader.shareMinorFor(id), reason: id);
        all += b.totalMinor;
      }
      expect(all, reader.totalMinor);
    });

    testWidgets('legacy doubles-only bill shows exact cents', (tester) async {
      final reader = BillReader(legacyBill());
      final ali = reader.breakdownFor('ali');
      expect(ali.totalMinor, 1000);
      await tester.pumpWidget(
        _app(BillBreakdownCard(breakdown: ali, currency: reader.currency)),
      );
      await tester.pumpAndSettle();
      expect(find.text('bf_bill_line_item_split'), findsOneWidget);
      expect(_text('10.00'), findsOneWidget);
      final total = find.byKey(
        const ValueKey('bf_bill_breakdown_total_amount'),
      );
      expect(_shown(tester, total), _plain(formatMoneyMinor(1000, 'USD')));
    });

    testWidgets('quantity bug: 1 of 3 units is not re-split equally', (
      tester,
    ) async {
      // The old _calculateMyShare split a 3-unit line by assignedTo.length
      // (3 people) which is right here by luck; give Sara 2 units instead.
      final bill = itemizedBill();
      final item = (bill['items'] as List)[0] as Map;
      item['unitAssignments'] = {'omar': 0, 'sara': 2, 'ali': 1};
      item['assignedTo'] = ['sara', 'ali'];
      // Shares as a writer would store them (recomputed from scratch).
      for (final p in bill['participants'] as List) {
        (p as Map)
          ..remove('shareMinor')
          ..remove('share');
      }
      final computed = computeBill(BillReader(bill).toDraft());
      for (final p in bill['participants'] as List) {
        p['shareMinor'] = computed.shareOf(p['id'] as String);
      }
      bill.remove('totalMinor');
      final sara = BillReader(bill).breakdownFor('sara');
      final lemon = sara.lines.firstWhere((l) => l.label == 'Lemon mint');
      expect(lemon.amountMinor, 600);
      expect(lemon.units, 2);
    });
  });

  group('PayMethodsList', () {
    List<PayMethodEntry> entriesFor(PaymentPlatform platform) {
      final bill = itemizedBill();
      final reader = BillReader(bill);
      return buildPayMethodEntries(
        methods: payMethodsFor(bill: bill),
        shareMinor: reader.shareMinorFor('mona'),
        // PayPal only prefills currencies it supports (not EGP).
        currency: 'USD',
        note: 'Sea Breeze Grill',
        platform: platform,
      );
    }

    test('built from the bill map; Apple Cash only on iOS', () {
      final android = entriesFor(PaymentPlatform.android);
      expect(android.map((e) => e.type.id), ['instapay', 'paypal']);
      final ios = entriesFor(PaymentPlatform.ios);
      expect(ios.map((e) => e.type.id), contains('apple_cash'));
      final paypal = android.firstWhere((e) => e.type.id == 'paypal');
      expect(paypal.prefillsAmount, isTrue);
      final launch = paypal.launch as DeepLinkLaunch;
      expect(launch.uri.toString(), contains('paypal.me/omarm/'));
      expect(launch.uri.toString(), endsWith('USD'));
    });

    test('host profile methods win over the bill copy', () {
      final methods = payMethodsFor(
        hostProfile: {
          'customPaymentMethods': [
            {'name': 'Vodafone Cash', 'value': '01012345678'},
          ],
        },
        bill: itemizedBill(),
      );
      expect(methods, hasLength(1));
      expect(methods.single.type.id, 'vodafone_cash');
    });

    testWidgets('rows: initials, name, handle or "amount filled in", Open', (
      tester,
    ) async {
      final entries = entriesFor(PaymentPlatform.ios);
      final opened = <String>[];
      await tester.pumpWidget(
        _app(
          PayMethodsList(
            entries: entries,
            onOpen: (e) => opened.add(e.type.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('InstaPay'), findsOneWidget);
      expect(find.text('omar@instapay'), findsOneWidget);
      expect(find.text('PayPal'), findsOneWidget);
      expect(find.text('bf_bill_pay_amount_filled'), findsOneWidget);
      expect(find.text('Apple Cash'), findsOneWidget);
      expect(find.text('bd2_apple_cash_hint'), findsOneWidget);
      expect(find.text('bf_bill_pay_open'), findsNWidgets(entries.length));
      expect(find.text('PP'), findsOneWidget);

      await tester.tap(find.text('bf_bill_pay_open').at(1));
      expect(opened, ['paypal']);
    });

    testWidgets('loading shows skeletons, empty shows a note', (tester) async {
      await tester.pumpWidget(
        _app(PayMethodsList(entries: const [], loading: true, onOpen: (_) {})),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpWidget(
        _app(PayMethodsList(entries: const [], onOpen: (_) {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('bf_bill_pay_none'), findsOneWidget);
    });
  });

  testWidgets('status pills', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            PayStatusPill(status: PayStatus.paid),
            PayStatusPill(status: PayStatus.review),
            PayStatusPill(status: PayStatus.notYet),
          ],
        ),
        dark: true,
      ),
    );
    expect(find.text('bf_bill_status_paid'), findsOneWidget);
    expect(find.text('bf_bill_status_check_proof'), findsOneWidget);
    expect(find.text('bf_bill_status_not_yet'), findsOneWidget);
  });

  testWidgets('status pill wording: owes, sent, check proof', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            PayStatusPill(status: PayStatus.notYet, owesText: 'E£400'),
            PayStatusPill(status: PayStatus.review, hasProof: false),
            PayStatusPill(
              status: PayStatus.review,
              self: true,
              hasProof: false,
            ),
          ],
        ),
      ),
    );
    expect(find.text('bd2_status_owes'), findsOneWidget);
    // No proof attached: never "Check proof".
    expect(find.text('bd2_status_sent_confirm'), findsOneWidget);
    expect(find.text('bf_bill_status_check_proof'), findsNothing);
    expect(find.text('bf_bill_status_waiting'), findsOneWidget);
  });

  testWidgets('participant view: owe-amber hero, breakdown, pay list, CTA', (
    tester,
  ) async {
    final bill = itemizedBill();
    final reader = BillReader(bill);
    final entries = buildPayMethodEntries(
      methods: payMethodsFor(bill: bill),
      shareMinor: reader.shareMinorFor('mona'),
      currency: 'EGP',
      platform: PaymentPlatform.android,
    );
    var paid = 0;
    await tester.pumpWidget(
      _app(
        ParticipantBillView(
          hostName: 'Omar',
          storeName: 'Sea Breeze Grill',
          currency: 'EGP',
          breakdown: reader.breakdownFor('mona'),
          shareMinor: reader.shareMinorFor('mona'),
          status: PayStatus.notYet,
          payEntries: entries,
          onOpenMethod: (_) {},
          onPaid: () => paid++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('bf_bill_host_paid_store'), findsOneWidget);
    expect(find.text('bf_bill_your_share'), findsOneWidget);
    expect(find.text('Beef burger'), findsOneWidget);
    expect(find.text('InstaPay'), findsOneWidget);

    final hero = find.byKey(const ValueKey('bf_bill_your_share_amount'));
    final heroText = tester.widget<Text>(
      find.descendant(of: hero, matching: find.byType(Text)).first,
    );
    final context = tester.element(hero);
    expect(heroText.style?.color, context.palette.owe);

    await tester.tap(find.byKey(const ValueKey('bf_bill_paid_cta')));
    expect(paid, 1);
  });
}
