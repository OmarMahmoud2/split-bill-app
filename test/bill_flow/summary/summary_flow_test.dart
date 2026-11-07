import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_summary_confirm_screen.dart';
import 'package:split_bill_app/screens/split_bill/bill_roulette_screen.dart';
import 'package:split_bill_app/screens/split_bill/bill_share_screen.dart';
import 'package:split_bill_app/screens/split_bill/split_method_screen.dart';
import 'package:split_bill_app/theme/theme.dart';

Widget _app(Widget home, {bool dark = false, TextDirection? dir}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: dir == null ? c! : Directionality(textDirection: dir, child: c!),
      ),
      home: home,
    );

const _people = [
  {'id': 'omar', 'name': 'Omar', 'isHost': true},
  {'id': 'sara', 'name': 'Sara', 'phoneNumber': '+201000'},
  {'id': 'ali', 'name': 'Ali'},
  {'id': 'mona', 'name': 'Mona Adel', 'isGuest': true},
];

const _draft = BillDraft(
  currency: 'EGP',
  items: [DraftItem(name: 'Platter', unitPriceMinor: 6450)],
  participantIds: ['omar', 'sara', 'ali', 'mona'],
  itemAssignments: {
    0: ['omar', 'sara', 'ali', 'mona'],
  },
  taxMinor: 903,
  serviceMinor: 774,
);

Map<String, dynamic> _receipt() => {
  'restaurant_name': 'Sea Breeze Grill',
  'currency_code': 'EGP',
  'items': [
    {'name': 'Burger', 'price': 14.0, 'qty': 1},
    {'name': 'Mint', 'price': 3.0, 'qty': 3},
  ],
};

void main() {
  group('split method note', () {
    test('equal leftover is reported', () {
      final c = computeBill(_draft.copyWith(method: SplitMethod.equal));
      expect(splitLeftoverMinor(c), 8127 % 4);
      final (key, args) = splitMethodNote(c);
      expect(key, 'bf_split_adds_up_leftover');
      expect(args['amount'], isNotEmpty);
    });

    test('shares leftover as in the design', () {
      final c = computeBill(
        _draft.copyWith(
          method: SplitMethod.shares,
          shares: {'omar': 1, 'sara': 2, 'ali': 2, 'mona': 1},
        ),
      );
      expect(splitLeftoverMinor(c), 1);
    });

    test('exact short and over', () {
      final short = computeBill(
        _draft.copyWith(method: SplitMethod.exact, exactAmounts: {'omar': 27}),
      );
      expect(splitMethodNote(short).$1, 'bf_split_exact_left');
      final over = computeBill(
        _draft.copyWith(
          method: SplitMethod.exact,
          exactAmounts: {'omar': 9000},
        ),
      );
      expect(splitMethodNote(over).$1, 'bf_split_exact_over');
    });

    test('percent left', () {
      final c = computeBill(
        _draft.copyWith(method: SplitMethod.percent, percentages: {'omar': 40}),
      );
      final (key, args) = splitMethodNote(c);
      expect(key, 'bf_split_percent_left');
      expect(args['percent'], '60');
    });
  });

  group('SplitMethodScreen', () {
    testWidgets('shares stepper updates totals and pops the draft', (
      tester,
    ) async {
      BillDraft? popped;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  popped = await SplitMethodScreen.open(
                    context,
                    draft: _draft,
                    participants: _people,
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('split_seg_shares')));
      await tester.pumpAndSettle();
      final plus = find.bySemanticsLabel('bf_split_more_shares');
      expect(plus, findsNWidgets(4));
      await tester.tap(plus.at(1));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('split_method_confirm')));
      await tester.pumpAndSettle();
      expect(popped?.method, SplitMethod.shares);
      expect(popped?.shares['sara'], 2);
      expect(computeBill(popped!).allocatedMinor, 8127);
    });

    testWidgets('renders in dark and RTL without overflow', (tester) async {
      await tester.pumpWidget(
        _app(
          const SplitMethodScreen(draft: _draft, participants: _people),
          dark: true,
          dir: TextDirection.rtl,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('split_seg_exact')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });

  group('share texts', () {
    String tr(String k, Map<String, String> a) =>
        '$k|${a.entries.map((e) => '${e.key}=${e.value}').join(',')}';

    test('personal text has first name, exact amount and p link', () {
      final text = personalShareText(
        target: const ShareTarget(
          id: 'mona',
          name: 'Mona Adel',
          shareMinor: 1638,
        ),
        billId: 'b1',
        currency: 'EGP',
        store: 'Sea Breeze',
        tr: tr,
      );
      expect(text, contains('name=Mona,'));
      expect(text, contains('16.38'));
      expect(text, contains('/bill/b1?p=mona'));
    });

    test('group text skips the host', () {
      final text = groupShareText(
        targets: const [
          ShareTarget(id: 'h', name: 'Omar', shareMinor: 100, isHost: true),
          ShareTarget(id: 's', name: 'Sara', shareMinor: 756),
        ],
        billId: 'b1',
        currency: 'EGP',
        store: 'X',
        tr: tr,
      );
      expect(text.split('\n'), hasLength(2));
      expect(text, isNot(contains('Omar')));
      expect(text, contains('7.56'));
    });
  });

  testWidgets('BillShareScreen lists everyone but the host', (tester) async {
    await tester.pumpWidget(
      _app(
        const BillShareScreen(
          billId: 'b1',
          storeName: 'Sea Breeze',
          currency: 'EGP',
          targets: [
            ShareTarget(id: 'h', name: 'Omar', shareMinor: 2709, isHost: true),
            ShareTarget(
              id: 's',
              name: 'Sara',
              shareMinor: 756,
              phoneNumber: '+20100',
            ),
            ShareTarget(id: 'm', name: 'Mona', shareMinor: 1638),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ShareTargetRow), findsNWidgets(2));
    expect(find.text('bf_share_whatsapp'), findsOneWidget);
    expect(find.text('bf_share_message'), findsOneWidget);
    expect(find.byKey(const ValueKey('share_qr_card')), findsOneWidget);
  });

  testWidgets('roulette picks and confirms a winner', (tester) async {
    String? winner;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                winner = await Navigator.of(context).push<String>(
                  MaterialPageRoute(
                    builder: (_) => BillRouletteScreen(
                      participants: _people,
                      totalMinor: 8127,
                      currency: 'EGP',
                      random: math.Random(1),
                    ),
                  ),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('roulette_spin')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('roulette_confirm')));
    await tester.pumpAndSettle();
    expect(_people.map((p) => p['id']), contains(winner));
  });

  group('BillSummaryConfirmScreen', () {
    Widget summary(Future<String> Function(Map<String, dynamic>) save) => _app(
      BillSummaryConfirmScreen(
        receiptData: _receipt(),
        participants: const [
          {'id': 'host', 'name': 'Omar', 'isHost': true},
          {'id': 'b', 'name': 'Mona', 'isGuest': true},
        ],
        itemAssignments: const {
          0: ['b'],
        },
        quantityAssignments: const {
          1: {'host': 2, 'b': 1},
        },
        taxAmount: 2.31,
        serviceChargeAmount: 0,
        tipAmount: 0,
        debugSave: save,
      ),
    );

    testWidgets('saves the data contract and shows the success moment', (
      tester,
    ) async {
      Map<String, dynamic>? saved;
      await tester.pumpWidget(
        summary((data) async {
          saved = data;
          return 'bill1';
        }),
      );
      await tester.pumpAndSettle();
      // Expand Mona's breakdown.
      await tester.tap(find.byKey(const ValueKey('summary_person_b')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('summary_edit_b')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('summary_save')));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!['totalMinor'], 1400 + 900 + 231);
      expect(saved!['currency'], 'EGP');
      expect(saved!['splitMethod'], 'items');
      final ps = saved!['participants'] as List;
      expect(
        ps.fold<int>(0, (s, p) => s + (p['shareMinor'] as int)),
        saved!['totalMinor'],
      );
      expect((saved!['history'] as List).single['change'], 'created');
      expect(((saved!['items'] as List)[1] as Map)['unitAssignments'], {
        'host': 2,
        'b': 1,
      });
      expect(find.text('bf_share_title'), findsOneWidget);
    });

    testWidgets('save failure shows a friendly error, no raw text', (
      tester,
    ) async {
      await tester.pumpWidget(summary((_) async => throw Exception('boom')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('summary_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('boom'), findsNothing);
      expect(find.text('bf_summary_save_failed'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('unassigned item blocks saving with an issue banner', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        _app(
          BillSummaryConfirmScreen(
            receiptData: _receipt(),
            participants: const [
              {'id': 'host', 'name': 'Omar', 'isHost': true},
            ],
            itemAssignments: const {
              0: ['host'],
            },
            quantityAssignments: const {},
            taxAmount: 0,
            serviceChargeAmount: 0,
            tipAmount: 0,
            debugSave: (_) async {
              called = true;
              return 'x';
            },
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('summary_issue')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('summary_save')));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(called, isFalse);
    });
  });
}
