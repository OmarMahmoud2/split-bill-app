/// Pure ledger maths over [BillRecord]s and [PaymentRecord]s: group
/// balances, who-pays-whom, per-friend balances and the user's net.
///
/// Built on `lib/domain/settlement.dart`. Everything is integer minor
/// units, per currency, with no FX conversion.
library;

import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/domain/settlement.dart';

/// Expenses and settlement payments for a set of bills and payments.
(List<Expense>, List<SettlementPayment>) ledgerEntries(
  Iterable<BillRecord> bills,
  Iterable<PaymentRecord> payments,
) {
  final expenses = <Expense>[];
  final settlements = <SettlementPayment>[];
  final seen = <String>{};
  for (final b in bills) {
    if (!seen.add('bill:${b.id}')) continue;
    final e = b.toExpense();
    if (e != null) expenses.add(e);
  }
  for (final p in payments) {
    if (!seen.add('p:${p.id}')) continue;
    final e = p.toExpense();
    if (e != null) expenses.add(e);
    final s = p.toSettlement();
    if (s != null) settlements.add(s);
  }
  return (expenses, settlements);
}

/// Who owes whom without simplification: every bill keeps its own
/// debtor -> host edge, and payments/IOUs net against the same pair.
Map<String, List<Transfer>> pairwiseTransfers(
  Iterable<Expense> expenses, {
  Iterable<SettlementPayment> payments = const [],
}) {
  // currency -> "a\u0000b" (a < b) -> amount a owes b (negative: b owes a).
  final net = <String, Map<String, int>>{};
  void owe(String currency, String debtor, String creditor, int amount) {
    if (debtor == creditor || amount == 0) return;
    final ordered = debtor.compareTo(creditor) < 0;
    final key = ordered ? '$debtor\u0000$creditor' : '$creditor\u0000$debtor';
    final m = net.putIfAbsent(currency, () => {});
    m[key] = (m[key] ?? 0) + (ordered ? amount : -amount);
  }

  for (final e in expenses) {
    if (e.paidBy.length == 1) {
      final payer = e.paidBy.keys.first;
      e.owedBy.forEach((who, v) => owe(e.currency, who, payer, v));
    } else {
      // Several payers: settle that one expense with the fewest edges.
      final b = computeBalances([e]);
      for (final t in simplifyDebts(b).values.expand((l) => l)) {
        owe(t.currency, t.from, t.to, t.amount);
      }
    }
  }
  for (final p in payments) {
    // A payment from -> to cancels debt from owes to.
    owe(normalizeCurrency(p.currency), p.from, p.to, -p.amount);
  }

  final result = <String, List<Transfer>>{};
  net.forEach((currency, pairs) {
    final list = <Transfer>[];
    pairs.forEach((key, amount) {
      if (amount == 0) return;
      final i = key.indexOf('\u0000');
      final a = key.substring(0, i);
      final b = key.substring(i + 1);
      list.add(
        amount > 0
            ? Transfer(currency: currency, from: a, to: b, amount: amount)
            : Transfer(currency: currency, from: b, to: a, amount: -amount),
      );
    });
    list.sort(_byAmountDesc);
    if (list.isNotEmpty) result[currency] = list;
  });
  return result;
}

int _byAmountDesc(Transfer a, Transfer b) {
  final c = b.amount.compareTo(a.amount);
  if (c != 0) return c;
  final f = a.from.compareTo(b.from);
  return f != 0 ? f : a.to.compareTo(b.to);
}

/// A computed ledger for one group (or any set of bills and payments).
class LedgerView {
  const LedgerView._({
    required this.balances,
    required this.transfers,
    required this.unsimplifiedCount,
  });

  factory LedgerView.build({
    required Iterable<BillRecord> bills,
    Iterable<PaymentRecord> payments = const [],
    bool simplify = true,
  }) {
    final (expenses, settlements) = ledgerEntries(bills, payments);
    final balances = computeBalances(expenses, payments: settlements);
    final pairwise = pairwiseTransfers(expenses, payments: settlements);
    final transfers = simplify
        ? simplifyDebts(balances).map(
            (c, l) => MapEntry(c, [...l]..sort(_byAmountDesc)),
          )
        : pairwise;
    return LedgerView._(
      balances: balances,
      transfers: transfers,
      unsimplifiedCount: pairwise.values.fold(0, (a, l) => a + l.length),
    );
  }

  static const empty = LedgerView._(
    balances: {},
    transfers: {},
    unsimplifiedCount: 0,
  );

  /// currency -> person -> balance (positive: is owed).
  final Map<String, Map<String, int>> balances;

  /// currency -> suggested payments.
  final Map<String, List<Transfer>> transfers;

  /// Payments needed if everyone paid back each bill separately.
  final int unsimplifiedCount;

  bool get isSettled => balances.isEmpty;

  List<Transfer> get allTransfers =>
      transfers.values.expand((l) => l).toList();

  int get transferCount => allTransfers.length;

  /// [person]'s balance per currency (positive: is owed).
  Map<String, int> balanceOf(String person) => {
    for (final e in balances.entries)
      if ((e.value[person] ?? 0) != 0) e.key: e.value[person]!,
  };

  List<Transfer> transfersInvolving(String person) => allTransfers
      .where((t) => t.from == person || t.to == person)
      .toList();
}

/// Where a friend balance comes from: a group, or bills/IOUs outside groups.
class BalanceContext {
  BalanceContext({required this.groupId, required this.label});

  /// Null for bills and IOUs outside any group.
  final String? groupId;
  final String label;

  /// currency -> amount (positive: they owe the user).
  final Map<String, int> net = {};
  int billCount = 0;
  String? lastBillTitle;
}

/// Everything between the user and one other person.
class Counterparty {
  Counterparty({required this.id, required this.name, this.photoUrl});

  final String id;
  String name;
  String? photoUrl;

  /// currency -> amount (positive: they owe the user; negative: the user
  /// owes them).
  final Map<String, int> net = {};
  final List<BalanceContext> contexts = [];

  bool get isSettled => net.values.every((v) => v == 0);

  /// The largest absolute amount, for sorting.
  int get magnitude => net.values.fold(0, (a, v) => a > v.abs() ? a : v.abs());

  /// The amount to show first: [preferred] if non-zero, else the largest.
  MapEntry<String, int>? primary(String preferred) {
    final code = normalizeCurrency(preferred);
    final v = net[code];
    if (v != null && v != 0) return MapEntry(code, v);
    MapEntry<String, int>? best;
    for (final e in net.entries) {
      if (e.value == 0) continue;
      if (best == null || e.value.abs() > best.value.abs()) best = e;
    }
    return best;
  }

  BalanceContext _context(String? groupId, String label) {
    for (final c in contexts) {
      if (c.groupId == groupId) return c;
    }
    final c = BalanceContext(groupId: groupId, label: label);
    contexts.add(c);
    return c;
  }
}

/// A group with its bills and payments, ready for [buildCounterparties].
class GroupLedgerInput {
  const GroupLedgerInput({
    required this.group,
    required this.bills,
    required this.payments,
  });

  final LedgerGroup group;
  final List<BillRecord> bills;
  final List<PaymentRecord> payments;

  LedgerView get view => LedgerView.build(
    bills: bills,
    payments: payments,
    simplify: group.simplifyDebts,
  );
}

/// The user's position across every ledger.
class BalanceSummary {
  BalanceSummary({required this.me, required this.people});

  final String me;

  /// Everyone the user has an open balance (or history) with, largest first.
  final List<Counterparty> people;

  /// currency -> net (positive: the user is owed overall).
  Map<String, int> get net {
    final m = <String, int>{};
    for (final p in people) {
      p.net.forEach((c, v) => m[c] = (m[c] ?? 0) + v);
    }
    m.removeWhere((_, v) => v == 0);
    return m;
  }

  /// currency -> total others owe the user.
  Map<String, int> get owedToMe => _sum((v) => v > 0);

  /// currency -> total the user owes (as a positive number).
  Map<String, int> get iOwe => _sum((v) => v < 0, negate: true);

  Map<String, int> _sum(bool Function(int) test, {bool negate = false}) {
    final m = <String, int>{};
    for (final p in people) {
      p.net.forEach((c, v) {
        if (test(v)) m[c] = (m[c] ?? 0) + (negate ? -v : v);
      });
    }
    return m;
  }

  List<Counterparty> get open => people.where((p) => !p.isSettled).toList();

  Counterparty? person(String id) {
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  Set<String> get currencies => {
    ...owedToMe.keys,
    ...iOwe.keys,
  };
}

/// Builds per-friend balances for [me]:
/// * each group contributes the transfers involving [me] (simplified when the
///   group has `simplifyDebts`), so what Home shows matches Settle up;
/// * bills outside groups ([looseBills]) and direct payments/IOUs
///   ([directPayments]) are netted pair by pair.
///
/// [looseLabel] names the non-group context ("Bills and IOUs").
BalanceSummary buildCounterparties({
  required String me,
  List<GroupLedgerInput> groups = const [],
  Iterable<BillRecord> looseBills = const [],
  Iterable<PaymentRecord> directPayments = const [],
  String looseLabel = '',
}) {
  final people = <String, Counterparty>{};
  final names = <String, String>{};
  final photos = <String, String>{};

  void learn(String id, String? name, [String? photo]) {
    if (name != null && name.isNotEmpty) names.putIfAbsent(id, () => name);
    if (photo != null && photo.isNotEmpty) photos.putIfAbsent(id, () => photo);
  }

  Counterparty person(String id) => people.putIfAbsent(
    id,
    () => Counterparty(id: id, name: names[id] ?? ''),
  );

  void apply(Transfer t, String? groupId, String label) {
    final String other;
    final int signed;
    if (t.to == me) {
      other = t.from;
      signed = t.amount;
    } else if (t.from == me) {
      other = t.to;
      signed = -t.amount;
    } else {
      return;
    }
    final p = person(other);
    p.net[t.currency] = (p.net[t.currency] ?? 0) + signed;
    final ctx = p._context(groupId, label);
    ctx.net[t.currency] = (ctx.net[t.currency] ?? 0) + signed;
  }

  void countBill(BillRecord b, String? groupId, String label) {
    final involvesMe = b.hostId == me || b.share(me) != null;
    if (!involvesMe || b.isDraft) return;
    for (final s in b.participants) {
      if (s.id == me) continue;
      if (b.hostId != me && s.id != b.hostId) continue;
      final p = person(s.id);
      final ctx = p._context(groupId, label);
      ctx.billCount++;
      ctx.lastBillTitle ??= b.title;
    }
    if (b.hostId != me && b.hostId.isNotEmpty) {
      final ctx = person(b.hostId)._context(groupId, label);
      ctx.billCount++;
      ctx.lastBillTitle ??= b.title;
    }
  }

  for (final g in groups) {
    for (final m in g.group.members) {
      learn(m.id, m.name, m.photoUrl);
    }
    for (final b in g.bills) {
      learn(b.hostId, b.hostName);
      for (final s in b.participants) {
        learn(s.id, s.name, s.photoUrl);
      }
    }
    for (final p in g.payments) {
      learn(p.from, p.fromName);
      learn(p.to, p.toName);
    }
  }
  for (final b in looseBills) {
    learn(b.hostId, b.hostName);
    for (final s in b.participants) {
      learn(s.id, s.name, s.photoUrl);
    }
  }
  for (final p in directPayments) {
    learn(p.from, p.fromName);
    learn(p.to, p.toName);
  }

  for (final g in groups) {
    final bills = [...g.bills]
      ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    for (final b in bills) {
      countBill(b, g.group.id, g.group.name);
    }
    for (final t in g.view.allTransfers) {
      apply(t, g.group.id, g.group.name);
    }
  }

  final groupIds = {for (final g in groups) g.group.id};
  final loose = looseBills
      .where((b) => b.groupId == null || !groupIds.contains(b.groupId))
      .toList()
    ..sort((a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
  for (final b in loose) {
    countBill(b, null, looseLabel);
  }
  final direct = directPayments.where((p) => p.groupId == null);
  final (expenses, settlements) = ledgerEntries(loose, direct);
  for (final t in pairwiseTransfers(expenses, payments: settlements).values
      .expand((l) => l)) {
    apply(t, null, looseLabel);
  }

  for (final p in people.values) {
    p.name = names[p.id] ?? p.name;
    p.photoUrl = photos[p.id];
    p.net.removeWhere((_, v) => v == 0);
    for (final c in p.contexts) {
      c.net.removeWhere((_, v) => v == 0);
    }
  }
  people.remove(me);
  final list = people.values.toList()
    ..sort((a, b) {
      final c = b.magnitude.compareTo(a.magnitude);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
  return BalanceSummary(me: me, people: list);
}

/// The amount to headline when balances span several currencies: the
/// [preferred] currency if present, else the one with the largest amount.
MapEntry<String, int>? headlineAmount(
  Map<String, int> perCurrency,
  String preferred,
) {
  final code = normalizeCurrency(preferred);
  if (perCurrency.containsKey(code)) return MapEntry(code, perCurrency[code]!);
  MapEntry<String, int>? best;
  for (final e in perCurrency.entries) {
    if (best == null || e.value.abs() > best.value.abs()) best = e;
  }
  return best;
}
