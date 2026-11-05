import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/domain_errors.dart';
import 'package:split_bill_app/domain/item_split.dart';
import 'package:split_bill_app/domain/settlement.dart';
import 'package:split_bill_app/domain/split_methods.dart';

Expense _equal(String id, String payer, int amount, List<String> people,
        {String currency = 'USD'}) =>
    Expense.singlePayer(
      id: id,
      currency: currency,
      payer: payer,
      shares: splitEqually(amount, people),
    );

/// Applies transfers to balances and returns the result (zeros removed).
Map<String, int> _apply(Map<String, int> balances, List<Transfer> transfers) {
  final out = {...balances};
  for (final t in transfers) {
    out[t.from] = (out[t.from] ?? 0) + t.amount;
    out[t.to] = (out[t.to] ?? 0) - t.amount;
  }
  out.removeWhere((_, v) => v == 0);
  return out;
}

void main() {
  group('computeBalances', () {
    test('single payer, equal split', () {
      final b = computeBalances([_equal('e1', 'a', 3000, ['a', 'b', 'c'])]);
      expect(b, {
        'USD': {'a': 2000, 'b': -1000, 'c': -1000},
      });
    });

    test('single person paying for themselves nets to nothing', () {
      expect(computeBalances([_equal('e1', 'me', 1234, ['me'])]), isEmpty);
    });

    test('all even: everyone paid their own share', () {
      final b = computeBalances([
        _equal('e1', 'a', 900, ['a', 'b', 'c']),
        _equal('e2', 'b', 900, ['a', 'b', 'c']),
        _equal('e3', 'c', 900, ['a', 'b', 'c']),
      ]);
      expect(b, isEmpty);
      expect(simplifyDebts(b), isEmpty);
    });

    test('zero-amount bill has no effect', () {
      final b = computeBalances([
        _equal('e0', 'a', 0, ['a', 'b']),
        _equal('e1', 'a', 1000, ['a', 'b']),
      ]);
      expect(b, {
        'USD': {'a': 500, 'b': -500},
      });
    });

    test('multiple payers on one expense', () {
      final b = computeBalances([
        Expense(
          id: 'e1',
          currency: 'EUR',
          paidBy: const {'a': 6000, 'b': 4000},
          owedBy: const {'a': 2500, 'b': 2500, 'c': 2500, 'd': 2500},
        ),
      ]);
      expect(b, {
        'EUR': {'a': 3500, 'b': 1500, 'c': -2500, 'd': -2500},
      });
    });

    test('mixed currencies are kept separate (no FX)', () {
      final b = computeBalances([
        _equal('e1', 'a', 1000, ['a', 'b']),
        _equal('e2', 'b', 3000, ['a', 'b'], currency: 'JPY'),
        _equal('e3', 'b', 500, ['a', 'b'], currency: 'usd'),
      ]);
      expect(b, {
        'USD': {'a': 250, 'b': -250},
        'JPY': {'a': -1500, 'b': 1500},
      });
    });

    test('payments reduce balances', () {
      final b = computeBalances(
        [_equal('e1', 'a', 3000, ['a', 'b', 'c'])],
        payments: const [
          SettlementPayment(id: 'p1', currency: 'USD', from: 'b', to: 'a', amount: 400),
        ],
      );
      expect(b, {
        'USD': {'a': 1600, 'b': -600, 'c': -1000},
      });
    });
  });

  group('simplifyDebts', () {
    test('rounding remainders: 10.00 paid by a, split three ways', () {
      final b = computeBalances([_equal('e1', 'a', 1000, ['a', 'b', 'c'])]);
      // a's own share is 334, so a is owed 666.
      expect(simplifyDebts(b), {
        'USD': const [
          Transfer(currency: 'USD', from: 'b', to: 'a', amount: 333),
          Transfer(currency: 'USD', from: 'c', to: 'a', amount: 333),
        ],
      });
    });

    test('collapses a debt chain into one transfer', () {
      final b = computeBalances([
        Expense.singlePayer(id: 'e1', currency: 'USD', payer: 'b', shares: const {'a': 1000}),
        Expense.singlePayer(id: 'e2', currency: 'USD', payer: 'c', shares: const {'b': 1000}),
      ]);
      expect(simplifyDebts(b)['USD'], const [
        Transfer(currency: 'USD', from: 'a', to: 'c', amount: 1000),
      ]);
    });

    test('matches largest creditor with largest debtor', () {
      final t = simplifyCurrency('USD', const {
        'a': 700,
        'b': 300,
        'c': -600,
        'd': -400,
      });
      expect(t, const [
        Transfer(currency: 'USD', from: 'c', to: 'a', amount: 600),
        // a now has 100 left, so b (300) is the largest creditor.
        Transfer(currency: 'USD', from: 'd', to: 'b', amount: 300),
        Transfer(currency: 'USD', from: 'd', to: 'a', amount: 100),
      ]);
    });

    test('ties are broken by participant id for determinism', () {
      final t1 = simplifyCurrency('USD', const {'y': 100, 'x': 100, 'q': -100, 'p': -100});
      final t2 = simplifyCurrency('USD', const {'p': -100, 'q': -100, 'x': 100, 'y': 100});
      expect(t1, t2);
      expect(t1.first, const Transfer(currency: 'USD', from: 'p', to: 'x', amount: 100));
    });

    test('balances that do not net to zero are rejected', () {
      expect(() => simplifyCurrency('USD', const {'a': 100, 'b': -99}),
          throwsA(isA<UnbalancedBalancesError>()));
    });

    test('many participants: at most n-1 transfers that settle everyone', () {
      final people = List.generate(25, (i) => 'p${i.toString().padLeft(2, '0')}');
      final expenses = <Expense>[
        for (var i = 0; i < 60; i++)
          _equal(
            'e$i',
            people[(i * 7) % people.length],
            1000 + i * 137,
            {for (var j = 0; j < 2 + i % 9; j++) people[(i + j * 3) % people.length]}
                .toList(),
          ),
      ];
      final balances = computeBalances(expenses)['USD']!;
      final transfers = simplifyCurrency('USD', balances);
      expect(transfers.length, lessThanOrEqualTo(balances.length - 1));
      expect(transfers.every((t) => t.amount > 0), isTrue);
      expect(_apply(balances, transfers), isEmpty);
      // Greedy never makes anyone both send and receive.
      final senders = transfers.map((t) => t.from).toSet();
      final receivers = transfers.map((t) => t.to).toSet();
      expect(senders.intersection(receivers), isEmpty);
    });
  });

  group('Ledger', () {
    test('suggests transfers and records a settlement payment', () {
      var ledger = Ledger.empty().recordExpense(_equal('e1', 'a', 3000, ['a', 'b', 'c']));
      expect(ledger.suggestedTransfers()['USD']!.length, 2);

      ledger = ledger.recordPayment(const SettlementPayment(
          id: 'p1', currency: 'USD', from: 'b', to: 'a', amount: 1000));
      expect(ledger.balances(), {
        'USD': {'a': 1000, 'c': -1000},
      });
      expect(ledger.suggestedTransfers(), {
        'USD': const [Transfer(currency: 'USD', from: 'c', to: 'a', amount: 1000)],
      });
    });

    test('settleAll zeroes every currency', () {
      final ledger = Ledger.empty()
          .recordExpense(_equal('e1', 'a', 1000, ['a', 'b', 'c']))
          .recordExpense(_equal('e2', 'c', 999, ['a', 'b', 'c'], currency: 'KWD'))
          .settleAll();
      expect(ledger.balances(), isEmpty);
      expect(ledger.suggestedTransfers(), isEmpty);
      expect(ledger.payments.length, 4);
    });

    test('settling twice is idempotent', () {
      final once = Ledger.empty()
          .recordExpense(_equal('e1', 'a', 1000, ['a', 'b', 'c']))
          .settleAll();
      final twice = once.settleAll();
      expect(twice.payments, once.payments);
      expect(twice.balances(), isEmpty);
    });

    test('recording the same payment or expense twice is a no-op', () {
      const payment = SettlementPayment(id: 'p1', currency: 'USD', from: 'b', to: 'a', amount: 500);
      final expense = _equal('e1', 'a', 1000, ['a', 'b']);
      final ledger = Ledger.empty()
          .recordExpense(expense)
          .recordExpense(_equal('e1', 'a', 1000, ['a', 'b']))
          .recordPayment(payment)
          .recordPayment(payment);
      expect(ledger.expenses.length, 1);
      expect(ledger.payments.length, 1);
      expect(ledger.balances(), isEmpty);
    });

    test('reusing an id with different content throws', () {
      final ledger = Ledger.empty().recordPayment(const SettlementPayment(
          id: 'p1', currency: 'USD', from: 'b', to: 'a', amount: 500));
      expect(
        () => ledger.recordPayment(const SettlementPayment(
            id: 'p1', currency: 'USD', from: 'b', to: 'a', amount: 600)),
        throwsA(isA<ConflictingRecordError>()),
      );
    });

    test('ledger is immutable', () {
      final empty = Ledger.empty();
      empty.recordExpense(_equal('e1', 'a', 1000, ['a', 'b']));
      expect(empty.expenses, isEmpty);
      expect(() => empty.expenses.add(_equal('x', 'a', 1, ['a'])), throwsUnsupportedError);
    });

    test('works with an itemized split', () {
      final split = splitItemizedBill(
        participants: ['host', 'b', 'c'],
        items: const [
          BillItem(name: 'Pizza', unitPrice: 1800, assignees: ['host', 'b', 'c']),
          BillItem(name: 'Wine', unitPrice: 3000, assignees: ['b', 'c']),
        ],
        charges: const BillCharges(tax: 480),
      );
      final ledger = Ledger.empty().recordExpense(Expense.singlePayer(
        id: 'bill1',
        currency: 'USD',
        payer: 'host',
        shares: split.totals,
      ));
      final transfers = ledger.suggestedTransfers()['USD']!;
      expect(transfers.map((t) => t.to).toSet(), {'host'});
      expect(transfers.fold(0, (a, t) => a + t.amount),
          split.grandTotal - split.totals['host']!);
    });
  });

  group('validation', () {
    test('expense paid and owed totals must match', () {
      expect(
        () => Expense(id: 'e', currency: 'USD', paidBy: const {'a': 100}, owedBy: const {'b': 90}),
        throwsA(isA<UnbalancedExpenseError>()),
      );
    });

    test('negative expense amounts throw', () {
      expect(
        () => Expense(
            id: 'e', currency: 'USD', paidBy: const {'a': 100}, owedBy: const {'b': 150, 'c': -50}),
        throwsA(isA<NegativeAmountError>()),
      );
    });

    test('payments must be positive and between two people', () {
      expect(
        () => SettlementPayment.validated(id: 'p', currency: 'USD', from: 'a', to: 'a', amount: 1),
        throwsA(isA<SelfPaymentError>()),
      );
      expect(
        () => SettlementPayment.validated(id: 'p', currency: 'USD', from: 'a', to: 'b', amount: 0),
        throwsA(isA<InvalidAmountError>()),
      );
      expect(
        () => Ledger.empty().recordPayment(
            const SettlementPayment(id: 'p', currency: 'USD', from: 'a', to: 'b', amount: -5)),
        throwsA(isA<NegativeAmountError>()),
      );
    });
  });
}
