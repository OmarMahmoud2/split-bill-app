/// Monthly insights computed on the device from bills and payments.
library;

import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/domain/money.dart';

class InsightSlice {
  const InsightSlice({required this.key, required this.amountMinor});

  /// Category name, or a group id / '' (no group) when [byCategory] is off.
  final String key;
  final int amountMinor;
}

class PaybackStat {
  const PaybackStat({
    required this.personId,
    required this.name,
    required this.days,
  });
  final String personId;
  final String name;
  final double days;
}

class MonthlyInsights {
  const MonthlyInsights({
    required this.month,
    required this.currency,
    required this.totalMinor,
    required this.billCount,
    required this.previousTotalMinor,
    required this.weekly,
    required this.slices,
    required this.byCategory,
    required this.paybackDays,
    required this.slowestPayer,
    required this.otherCurrencies,
  });

  final DateTime month;
  final String currency;

  /// The user's share of shared spending this month, in [currency].
  final int totalMinor;
  final int billCount;
  final int previousTotalMinor;

  /// Week of month (1..5) -> share.
  final List<int> weekly;
  final List<InsightSlice> slices;

  /// True when bills carry categories; otherwise [slices] are by group.
  final bool byCategory;

  /// Median days from a bill to the payment back, when known.
  final double? paybackDays;
  final PaybackStat? slowestPayer;

  /// Other currencies with spending this month (not converted).
  final Set<String> otherCurrencies;

  /// Change vs last month (-0.12 = 12% less); null without a baseline.
  double? get changeVsPrevious => previousTotalMinor <= 0
      ? null
      : (totalMinor - previousTotalMinor) / previousTotalMinor;

  int get peakWeek {
    var best = 0;
    for (var i = 1; i < weekly.length; i++) {
      if (weekly[i] > weekly[best]) best = i;
    }
    return best;
  }
}

double? _median(List<double> v) {
  if (v.isEmpty) return null;
  final s = [...v]..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/// Computes [month]'s insights for [me] in [currency].
MonthlyInsights computeInsights({
  required String me,
  required DateTime month,
  required String currency,
  required Iterable<BillRecord> bills,
  Iterable<PaymentRecord> payments = const [],
}) {
  final code = normalizeCurrency(currency);
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  final prevStart = DateTime(month.year, month.month - 1);

  var total = 0, prev = 0, count = 0;
  final weekly = List<int>.filled(5, 0);
  final slices = <String, int>{};
  final others = <String>{};
  final inMonth = <BillRecord>[];

  for (final b in bills) {
    final date = b.date;
    final share = b.share(me);
    if (date == null || share == null || b.isDraft) continue;
    if (b.currency != code) {
      if (!date.isBefore(start) && date.isBefore(end) && share.shareMinor > 0) {
        others.add(b.currency);
      }
      continue;
    }
    if (!date.isBefore(start) && date.isBefore(end)) {
      inMonth.add(b);
      total += share.shareMinor;
      count++;
      final week = ((date.day - 1) ~/ 7).clamp(0, 4);
      weekly[week] += share.shareMinor;
    } else if (!date.isBefore(prevStart) && date.isBefore(start)) {
      prev += share.shareMinor;
    }
  }

  final byCategory = inMonth.any((b) => b.category != null);
  for (final b in inMonth) {
    final key = byCategory ? (b.category ?? '') : (b.groupId ?? '');
    slices[key] = (slices[key] ?? 0) + b.share(me)!.shareMinor;
  }
  final sliceList = [
    for (final e in slices.entries)
      if (e.value > 0) InsightSlice(key: e.key, amountMinor: e.value),
  ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

  // Payback: payments to me that reference one of my bills.
  final billById = {for (final b in bills) b.id: b};
  final all = <double>[];
  final perPerson = <String, List<double>>{};
  final names = <String, String>{};
  for (final p in payments) {
    if (p.kind != PaymentKind.payment || p.to != me) continue;
    final bill = p.billId == null ? null : billById[p.billId];
    final paidAt = p.createdAt;
    final billDate = bill?.date;
    if (bill == null || paidAt == null || billDate == null) continue;
    final days = paidAt.difference(billDate).inMinutes / (60 * 24);
    if (days < 0) continue;
    all.add(days);
    perPerson.putIfAbsent(p.from, () => []).add(days);
    names[p.from] = p.fromName ?? bill.nameOf(p.from);
  }
  PaybackStat? slowest;
  perPerson.forEach((id, list) {
    final m = _median(list)!;
    if (slowest == null || m > slowest!.days) {
      slowest = PaybackStat(personId: id, name: names[id] ?? '', days: m);
    }
  });

  return MonthlyInsights(
    month: start,
    currency: code,
    totalMinor: total,
    billCount: count,
    previousTotalMinor: prev,
    weekly: weekly,
    slices: sliceList,
    byCategory: byCategory,
    paybackDays: _median(all),
    slowestPayer: perPerson.length > 1 ? slowest : null,
    otherCurrencies: others,
  );
}

/// Per-currency totals of bills (original amounts, no conversion).
Map<String, int> totalsByCurrency(Iterable<BillRecord> bills) {
  final m = <String, int>{};
  for (final b in bills) {
    if (b.isDraft) continue;
    m[b.currency] = (m[b.currency] ?? 0) + b.totalMinor;
  }
  return m;
}
