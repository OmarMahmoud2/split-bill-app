/// Group balances and debt simplification.
///
/// Amounts are integer minor units. Balances are kept per currency with no
/// FX conversion, so every API returns `Map<currency, ...>`.
///
/// Sign convention for balances: positive = the person is owed money
/// (creditor), negative = the person owes money (debtor). Zero balances are
/// omitted, and a currency where everybody is settled is omitted entirely.
library;

import 'domain_errors.dart';
import 'money.dart';

bool _mapEquals(Map<String, int> a, Map<String, int> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

int _mapHash(Map<String, int> m) => Object.hashAllUnordered(
      m.entries.map((e) => Object.hash(e.key, e.value)),
    );

/// A shared expense: who paid and who consumed what, in one currency.
class Expense {
  final String id;
  final String currency;

  /// Amount each payer actually paid (>= 0).
  final Map<String, int> paidBy;

  /// Amount each person owes for this expense (>= 0).
  final Map<String, int> owedBy;

  /// Validates that amounts are non-negative and that the paid total equals
  /// the owed total.
  Expense({
    required this.id,
    required String currency,
    required Map<String, int> paidBy,
    required Map<String, int> owedBy,
  })  : currency = normalizeCurrency(currency),
        paidBy = Map.unmodifiable(paidBy),
        owedBy = Map.unmodifiable(owedBy) {
    var paid = 0;
    var owed = 0;
    paidBy.forEach((who, v) {
      if (v < 0) throw NegativeAmountError('$id.paidBy.$who', v);
      paid += v;
    });
    owedBy.forEach((who, v) {
      if (v < 0) throw NegativeAmountError('$id.owedBy.$who', v);
      owed += v;
    });
    if (paid != owed) {
      throw UnbalancedExpenseError(
        expenseId: id,
        paidTotal: paid,
        owedTotal: owed,
      );
    }
  }

  /// The common case: one person paid the whole bill, [shares] says what
  /// each participant owes (e.g. `splitItemizedBill(...).totals`).
  factory Expense.singlePayer({
    required String id,
    required String currency,
    required String payer,
    required Map<String, int> shares,
  }) =>
      Expense(
        id: id,
        currency: currency,
        paidBy: {payer: shares.values.fold(0, (a, b) => a + b)},
        owedBy: shares,
      );

  @override
  bool operator ==(Object other) =>
      other is Expense &&
      other.id == id &&
      other.currency == currency &&
      _mapEquals(other.paidBy, paidBy) &&
      _mapEquals(other.owedBy, owedBy);

  @override
  int get hashCode =>
      Object.hash(id, currency, _mapHash(paidBy), _mapHash(owedBy));
}

/// A recorded payment from [from] to [to] that reduces what [from] owes.
class SettlementPayment {
  final String id;
  final String currency;
  final String from;
  final String to;

  /// Amount in minor units (> 0).
  final int amount;

  /// Unvalidated (const-friendly) constructor; validation happens when the
  /// payment is used by [computeBalances] or [Ledger.recordPayment].
  const SettlementPayment({
    required this.id,
    required this.currency,
    required this.from,
    required this.to,
    required this.amount,
  });

  /// Constructs and validates a payment.
  factory SettlementPayment.validated({
    required String id,
    required String currency,
    required String from,
    required String to,
    required int amount,
  }) =>
      SettlementPayment(
        id: id,
        currency: normalizeCurrency(currency),
        from: from,
        to: to,
        amount: amount,
      ).._validate();

  void _validate() {
    if (amount < 0) throw NegativeAmountError('$id.amount', amount);
    if (amount == 0) throw InvalidAmountError(amount);
    if (from == to) throw SelfPaymentError(from);
  }

  @override
  bool operator ==(Object other) =>
      other is SettlementPayment &&
      other.id == id &&
      normalizeCurrency(other.currency) == normalizeCurrency(currency) &&
      other.from == from &&
      other.to == to &&
      other.amount == amount;

  @override
  int get hashCode =>
      Object.hash(id, normalizeCurrency(currency), from, to, amount);
}

/// A suggested payment that would settle (part of) the balances.
class Transfer {
  final String currency;
  final String from;
  final String to;
  final int amount;

  const Transfer({
    required this.currency,
    required this.from,
    required this.to,
    required this.amount,
  });

  @override
  bool operator ==(Object other) =>
      other is Transfer &&
      other.currency == currency &&
      other.from == from &&
      other.to == to &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(currency, from, to, amount);

  @override
  String toString() => 'Transfer($from -> $to: ${Money(amount, currency)})';
}

/// Net balance per person, per currency (see library docs for the sign).
Map<String, Map<String, int>> computeBalances(
  Iterable<Expense> expenses, {
  Iterable<SettlementPayment> payments = const [],
}) {
  final result = <String, Map<String, int>>{};
  void add(String currency, String who, int delta) {
    final perCurrency = result.putIfAbsent(currency, () => <String, int>{});
    perCurrency[who] = (perCurrency[who] ?? 0) + delta;
  }

  for (final e in expenses) {
    e.paidBy.forEach((who, v) => add(e.currency, who, v));
    e.owedBy.forEach((who, v) => add(e.currency, who, -v));
  }
  for (final p in payments) {
    p._validate();
    final currency = normalizeCurrency(p.currency);
    add(currency, p.from, p.amount);
    add(currency, p.to, -p.amount);
  }

  for (final perCurrency in result.values) {
    perCurrency.removeWhere((_, v) => v == 0);
  }
  result.removeWhere((_, perCurrency) => perCurrency.isEmpty);
  return result;
}

/// Greedy min-cash-flow for one currency: repeatedly match the largest
/// creditor with the largest debtor (ties broken by participant id) and
/// transfer the smaller of the two amounts.
///
/// Each step settles at least one person, so for n people with non-zero
/// balances at most n-1 transfers are produced, and nobody both sends and
/// receives money.
List<Transfer> simplifyCurrency(String currency, Map<String, int> balances) {
  final code = normalizeCurrency(currency);
  final sum = balances.values.fold(0, (a, b) => a + b);
  if (sum != 0) throw UnbalancedBalancesError(code, sum);

  final creditors = <String, int>{};
  final debtors = <String, int>{};
  balances.forEach((who, v) {
    if (v > 0) creditors[who] = v;
    if (v < 0) debtors[who] = -v;
  });

  String largest(Map<String, int> m) {
    String? best;
    for (final entry in m.entries) {
      if (best == null ||
          entry.value > m[best]! ||
          (entry.value == m[best]! && entry.key.compareTo(best) < 0)) {
        best = entry.key;
      }
    }
    return best!;
  }

  final transfers = <Transfer>[];
  while (creditors.isNotEmpty && debtors.isNotEmpty) {
    final creditor = largest(creditors);
    final debtor = largest(debtors);
    final credit = creditors[creditor]!;
    final debt = debtors[debtor]!;
    final amount = credit < debt ? credit : debt;
    transfers.add(
      Transfer(currency: code, from: debtor, to: creditor, amount: amount),
    );
    if (credit == amount) {
      creditors.remove(creditor);
    } else {
      creditors[creditor] = credit - amount;
    }
    if (debt == amount) {
      debtors.remove(debtor);
    } else {
      debtors[debtor] = debt - amount;
    }
  }
  return transfers;
}

/// [simplifyCurrency] for every currency in [balances].
Map<String, List<Transfer>> simplifyDebts(
  Map<String, Map<String, int>> balances,
) {
  final result = <String, List<Transfer>>{};
  balances.forEach((currency, perCurrency) {
    final transfers = simplifyCurrency(currency, perCurrency);
    if (transfers.isNotEmpty) result[normalizeCurrency(currency)] = transfers;
  });
  return result;
}

/// Immutable record of a group's expenses and settlement payments.
///
/// Recording is idempotent by id: recording an identical expense/payment
/// again returns an equivalent ledger, while reusing an id for different
/// content throws [ConflictingRecordError].
class Ledger {
  final List<Expense> expenses;
  final List<SettlementPayment> payments;

  const Ledger._(this.expenses, this.payments);

  factory Ledger.empty() => const Ledger._([], []);

  Ledger recordExpense(Expense expense) {
    for (final e in expenses) {
      if (e.id == expense.id) {
        if (e == expense) return this;
        throw ConflictingRecordError(expense.id);
      }
    }
    return Ledger._(List.unmodifiable([...expenses, expense]), payments);
  }

  Ledger recordPayment(SettlementPayment payment) {
    final validated = SettlementPayment.validated(
      id: payment.id,
      currency: payment.currency,
      from: payment.from,
      to: payment.to,
      amount: payment.amount,
    );
    for (final p in payments) {
      if (p.id == validated.id) {
        if (p == validated) return this;
        throw ConflictingRecordError(validated.id);
      }
    }
    return Ledger._(expenses, List.unmodifiable([...payments, validated]));
  }

  Map<String, Map<String, int>> balances() =>
      computeBalances(expenses, payments: payments);

  Map<String, List<Transfer>> suggestedTransfers() =>
      simplifyDebts(balances());

  /// Records every suggested transfer as a payment. Calling it again on a
  /// settled ledger changes nothing.
  Ledger settleAll() {
    var ledger = this;
    final transfers = suggestedTransfers();
    final batch = payments.length;
    var n = 0;
    for (final entry in transfers.entries) {
      for (final t in entry.value) {
        ledger = ledger.recordPayment(SettlementPayment(
          id: 'settle-$batch-${n++}-${t.currency}-${t.from}-${t.to}',
          currency: t.currency,
          from: t.from,
          to: t.to,
          amount: t.amount,
        ));
      }
    }
    return ledger;
  }
}
