import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/data/ledger_math.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/domain/settlement.dart';

import 'fixtures.dart';

void main() {
  group('BillRecord', () {
    test('reads minor fields and falls back to legacy doubles', () {
      final b = BillRecord.fromMap('b1', {
        'hostId': 'h',
        'storeName': 'Cafe',
        'currencyCode': 'kwd',
        'total': 3.5,
        'date': Timestamp.fromDate(DateTime(2026, 1, 2)),
        'participants': [
          {'id': 'h', 'name': 'Host', 'share': 1.25, 'status': 'PAID'},
          {'id': 'f', 'name': 'Friend', 'share': 2.25, 'status': 'PENDING'},
          {'name': 'no id'},
        ],
      });
      expect(b.currency, 'KWD');
      expect(b.totalMinor, 3500);
      expect(b.participants.map((p) => p.shareMinor), [1250, 2250]);
      expect(b.unpaidShares, {'f': 2250});
      expect(b.isOpen, isTrue);
      expect(b.date, DateTime(2026, 1, 2));

      final m = BillRecord.fromMap('b2', {
        'hostId': 'h',
        'currency': 'JPY',
        'currencyCode': 'USD',
        'totalMinor': 1200,
        'total': 99.0,
        'groupId': 'g1',
        'participants': [
          {'id': 'f', 'shareMinor': 600, 'share': 1.0, 'isPaid': true},
        ],
      });
      expect(m.currency, 'JPY');
      expect(m.totalMinor, 1200);
      expect(m.participants.single.shareMinor, 600);
      expect(m.participants.single.isPaid, isTrue);
      expect(m.groupId, 'g1');
      expect(m.isOpen, isFalse);
      expect(m.toExpense(), isNull);
    });

    test('uses the fallback currency and ignores drafts', () {
      final b = BillRecord.fromMap('b', {
        'hostId': 'h',
        'status': 'UNATTEMPTED',
        'participants': [
          {'id': 'f', 'share': 5, 'status': 'PENDING'},
        ],
      }, fallbackCurrency: 'egp');
      expect(b.currency, 'EGP');
      expect(b.totalMinor, 500);
      expect(b.isDraft, isTrue);
      expect(b.isOpen, isFalse);
      expect(b.toExpense(), isNull);
    });
  });

  group('PaymentRecord', () {
    test('round-trips its create map', () {
      final p = pay('p1', 'a', 'b', 1500, groupId: 'g');
      final map = p.toCreateMap(participantUids: ['a', 'b'], createdAtValue: 1);
      expect(map['amountMinor'], 1500);
      expect(map['kind'], 'payment');
      expect(map['participants_uids'], ['a', 'b']);
      final back = PaymentRecord.fromMap('p1', map);
      expect(back.from, 'a');
      expect(back.groupId, 'g');
      expect(back.toSettlement()!.amount, 1500);
      expect(back.toExpense(), isNull);
    });

    test('an IOU is an expense the creditor paid for the debtor', () {
      final iou = pay('i', 'ali', 'me', 2000, kind: PaymentKind.iou);
      final e = iou.toExpense()!;
      expect(e.paidBy, {'me': 2000});
      expect(e.owedBy, {'ali': 2000});
      expect(iou.toSettlement(), isNull);
    });
  });

  group('LedgerView', () {
    test('simplifies to the fewest payments and counts the naive ones', () {
      // Three bills, each with its own debtor->host edges.
      final bills = [
        bill('1', 'o', {'o': 1000, 's': 1000, 'a': 1000, 'm': 1000}),
        bill('2', 's', {'o': 500, 's': 500, 'a': 500, 'm': 500}),
        bill('3', 'a', {'o': 200, 's': 200, 'a': 200}),
      ];
      final view = LedgerView.build(bills: bills);
      final raw = LedgerView.build(bills: bills, simplify: false);
      expect(view.unsimplifiedCount, raw.transferCount);
      expect(view.transferCount, lessThan(raw.transferCount));
      // Sum of balances is zero and transfers clear them.
      final balances = view.balances['USD']!;
      expect(balances.values.fold(0, (a, b) => a + b), 0);
      for (final t in view.allTransfers) {
        balances[t.from] = balances[t.from]! + t.amount;
        balances[t.to] = balances[t.to]! - t.amount;
      }
      expect(balances.values.every((v) => v == 0), isTrue);
    });

    test('payments reduce balances until the group is settled', () {
      final bills = [bill('1', 'o', {'o': 1000, 'a': 1000})];
      final open = LedgerView.build(bills: bills);
      expect(open.balanceOf('a'), {'USD': -1000});
      expect(open.isSettled, isFalse);
      final settled = LedgerView.build(
        bills: bills,
        payments: [pay('p', 'a', 'o', 1000)],
      );
      expect(settled.isSettled, isTrue);
      expect(settled.transferCount, 0);
    });

    test('keeps currencies apart', () {
      final view = LedgerView.build(
        bills: [
          bill('1', 'o', {'o': 1000, 'a': 1000}),
          bill('2', 'a', {'o': 5000, 'a': 0}, currency: 'EGP'),
        ],
      );
      expect(view.balanceOf('o'), {'USD': 1000, 'EGP': -5000});
      expect(view.transfers.keys.toSet(), {'USD', 'EGP'});
    });
  });

  group('pairwiseTransfers', () {
    test('nets opposite debts between the same two people', () {
      final e1 = Expense.singlePayer(id: '1', currency: 'USD', payer: 'a', shares: {'b': 700});
      final e2 = Expense.singlePayer(id: '2', currency: 'USD', payer: 'b', shares: {'a': 200});
      final t = pairwiseTransfers([e1, e2]);
      expect(t['USD'], [const Transfer(currency: 'USD', from: 'b', to: 'a', amount: 500)]);
    });

    test('a payment beyond the debt flips the direction', () {
      final e = Expense.singlePayer(id: '1', currency: 'USD', payer: 'a', shares: {'b': 100});
      final t = pairwiseTransfers([e], payments: [
        const SettlementPayment(id: 'p', currency: 'USD', from: 'b', to: 'a', amount: 150),
      ]);
      expect(t['USD'], [const Transfer(currency: 'USD', from: 'a', to: 'b', amount: 50)]);
    });
  });

  group('buildCounterparties', () {
    test('combines groups, loose bills and IOUs per person', () {
      final g = ledgerGroup('g', ['me', 'sara', 'ali']);
      final summary = buildCounterparties(
        me: 'me',
        looseLabel: 'Direct',
        groups: [
          GroupLedgerInput(
            group: g,
            bills: [bill('g1', 'me', {'me': 3000, 'sara': 3000, 'ali': 3000}, groupId: 'g')],
            payments: [pay('gp', 'sara', 'me', 1000, groupId: 'g')],
          ),
        ],
        looseBills: [
          bill('l1', 'mona', {'mona': 1000, 'me': 2400}),
          // A group bill seen in the recent window is not counted twice.
          bill('g1', 'me', {'me': 3000, 'sara': 3000, 'ali': 3000}, groupId: 'g'),
        ],
        directPayments: [pay('iou', 'ali', 'me', 500, kind: PaymentKind.iou)],
      );
      expect(summary.person('sara')!.net, {'USD': 2000});
      expect(summary.person('ali')!.net, {'USD': 3500});
      expect(summary.person('mona')!.net, {'USD': -2400});
      expect(summary.net, {'USD': 3100});
      expect(summary.owedToMe, {'USD': 5500});
      expect(summary.iOwe, {'USD': 2400});
      expect(summary.people.first.id, 'ali');
      final ali = summary.person('ali')!;
      expect(ali.contexts.map((c) => c.label), containsAll(['Group g', 'Direct']));
      expect(ali.name, 'ALI');
      expect(summary.person('me'), isNull);
    });

    test('simplified group debts show up against the right person', () {
      // a owes o 10 and s owes a 10 -> simplified: s pays o directly.
      final g = ledgerGroup('g', ['o', 'a', 's']);
      final input = GroupLedgerInput(
        group: g,
        bills: [
          bill('1', 'o', {'a': 1000}, groupId: 'g'),
          bill('2', 'a', {'s': 1000}, groupId: 'g'),
        ],
        payments: const [],
      );
      final summary = buildCounterparties(me: 'o', groups: [input]);
      expect(summary.person('s')!.net, {'USD': 1000});
      expect(summary.person('a')?.net ?? {}, isEmpty);

      final raw = buildCounterparties(
        me: 'o',
        groups: [
          GroupLedgerInput(group: ledgerGroup('g', ['o', 'a', 's'], simplify: false), bills: input.bills, payments: const []),
        ],
      );
      expect(raw.person('a')!.net, {'USD': 1000});
    });

    test('settled people stay listed but are not open', () {
      final summary = buildCounterparties(
        me: 'me',
        looseBills: [bill('1', 'me', {'me': 100, 'x': 100}, paid: {'x'})],
      );
      expect(summary.people.single.isSettled, isTrue);
      expect(summary.open, isEmpty);
      expect(summary.net, isEmpty);
    });
  });

  test('headlineAmount prefers the given currency, else the largest', () {
    expect(headlineAmount({'USD': 5, 'EGP': -900}, 'usd')!.value, 5);
    expect(headlineAmount({'USD': 5, 'EGP': -900}, 'EUR')!.key, 'EGP');
    expect(headlineAmount({}, 'EUR'), isNull);
  });

  test('Counterparty.primary picks the preferred currency first', () {
    final c = Counterparty(id: 'x', name: 'X')..net.addAll({'USD': 10, 'EGP': -500});
    expect(c.primary('USD')!.value, 10);
    expect(c.primary('JPY')!.key, 'EGP');
  });
}
