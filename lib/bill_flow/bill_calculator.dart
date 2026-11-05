/// The bill flow's single source of truth for "who pays what".
///
/// Wraps the pure domain layer (`lib/domain`) with the extra rules the bill
/// screens need, all in integer minor units:
///
/// * itemized ("by item") splits via [splitItemizedBill], plus the
///   whole-bill methods equal / exact / percent / shares;
/// * a per-person breakdown whose [BreakdownLine]s always add up to the
///   person's total ("every cent accounted for");
/// * manual overrides that REBALANCE the other people instead of changing
///   the bill total (legacy bug);
/// * the discount is allocated in proportion to each person's pre-discount
///   total, so a share can never go negative (legacy bug), and a discount
///   larger than the bill is reported as an issue;
/// * unknown assignee ids are pruned, and an item left with nobody on it is
///   reported as unassigned instead of being silently dropped (legacy bug);
/// * per-unit assignments that do not add up to the quantity, in either
///   direction, are reported (legacy over-assignment bug);
/// * other charges read both `split_method` and `splitMethod` (legacy bug).
///
/// Nothing here throws for user-fixable input: problems come back as
/// [BillIssue]s so the UI can explain them with a clear next step.
library;

import 'package:split_bill_app/domain/item_split.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/domain/split_methods.dart';

/// How a bill is split. The wire name is stored as `splitMethod`.
enum SplitMethod {
  items('items'),
  equal('equal'),
  exact('exact'),
  percent('percent'),
  shares('shares');

  const SplitMethod(this.wireName);

  final String wireName;

  static SplitMethod parse(Object? raw) {
    final value = raw?.toString().trim().toLowerCase();
    for (final m in SplitMethod.values) {
      if (m.wireName == value) return m;
    }
    return SplitMethod.items;
  }
}

/// Reads an other-charge's split, accepting both legacy keys.
ChargeSplit chargeSplitOf(Map<dynamic, dynamic> charge) {
  final raw = charge['splitMethod'] ?? charge['split_method'];
  return raw?.toString().toLowerCase() == 'equal'
      ? ChargeSplit.equal
      : ChargeSplit.proportional;
}

class DraftItem {
  const DraftItem({
    required this.name,
    required this.unitPriceMinor,
    this.quantity = 1,
  });

  final String name;

  /// Price of ONE unit, in minor units.
  final int unitPriceMinor;
  final int quantity;

  int get lineTotalMinor => unitPriceMinor * quantity;
}

class DraftCharge {
  const DraftCharge({
    required this.label,
    required this.amountMinor,
    this.split = ChargeSplit.proportional,
  });

  final String label;
  final int amountMinor;
  final ChargeSplit split;
}

/// Everything needed to compute a bill. Immutable; use [copyWith].
class BillDraft {
  const BillDraft({
    required this.currency,
    required this.items,
    required this.participantIds,
    this.itemAssignments = const {},
    this.quantityAssignments = const {},
    this.taxMinor = 0,
    this.serviceMinor = 0,
    this.tipMinor = 0,
    this.deliveryMinor = 0,
    this.discountMinor = 0,
    this.otherCharges = const [],
    this.method = SplitMethod.items,
    this.exactAmounts = const {},
    this.percentages = const {},
    this.shares = const {},
    this.overrides = const {},
    this.rouletteWinnerId,
  });

  final String currency;
  final List<DraftItem> items;
  final List<String> participantIds;

  /// Item index -> people sharing the whole line equally.
  final Map<int, List<String>> itemAssignments;

  /// Item index -> units per person (used when quantity > 1).
  final Map<int, Map<String, int>> quantityAssignments;

  final int taxMinor;
  final int serviceMinor;
  final int tipMinor;
  final int deliveryMinor;
  final int discountMinor;
  final List<DraftCharge> otherCharges;

  final SplitMethod method;
  final Map<String, int> exactAmounts;
  final Map<String, num> percentages;
  final Map<String, num> shares;

  /// Manual final shares; everybody else is rebalanced around them.
  final Map<String, int> overrides;

  /// Bill roulette: this person pays everything.
  final String? rouletteWinnerId;

  int get itemsSubtotalMinor =>
      items.fold(0, (sum, item) => sum + item.lineTotalMinor);

  int get otherChargesMinor =>
      otherCharges.fold(0, (sum, c) => sum + c.amountMinor);

  /// Items + every charge - discount.
  int get grandTotalMinor =>
      itemsSubtotalMinor +
      taxMinor +
      serviceMinor +
      tipMinor +
      deliveryMinor +
      otherChargesMinor -
      discountMinor;

  BillDraft copyWith({
    String? currency,
    List<DraftItem>? items,
    List<String>? participantIds,
    Map<int, List<String>>? itemAssignments,
    Map<int, Map<String, int>>? quantityAssignments,
    int? taxMinor,
    int? serviceMinor,
    int? tipMinor,
    int? deliveryMinor,
    int? discountMinor,
    List<DraftCharge>? otherCharges,
    SplitMethod? method,
    Map<String, int>? exactAmounts,
    Map<String, num>? percentages,
    Map<String, num>? shares,
    Map<String, int>? overrides,
    String? rouletteWinnerId,
    bool clearRoulette = false,
  }) {
    return BillDraft(
      currency: currency ?? this.currency,
      items: items ?? this.items,
      participantIds: participantIds ?? this.participantIds,
      itemAssignments: itemAssignments ?? this.itemAssignments,
      quantityAssignments: quantityAssignments ?? this.quantityAssignments,
      taxMinor: taxMinor ?? this.taxMinor,
      serviceMinor: serviceMinor ?? this.serviceMinor,
      tipMinor: tipMinor ?? this.tipMinor,
      deliveryMinor: deliveryMinor ?? this.deliveryMinor,
      discountMinor: discountMinor ?? this.discountMinor,
      otherCharges: otherCharges ?? this.otherCharges,
      method: method ?? this.method,
      exactAmounts: exactAmounts ?? this.exactAmounts,
      percentages: percentages ?? this.percentages,
      shares: shares ?? this.shares,
      overrides: overrides ?? this.overrides,
      rouletteWinnerId: clearRoulette
          ? null
          : (rouletteWinnerId ?? this.rouletteWinnerId),
    );
  }

  /// Assignment state of item [index] after pruning unknown ids.
  ItemAssignmentState assignmentOf(int index) {
    final item = items[index];
    final known = participantIds.toSet();
    final units = <String, int>{};
    (quantityAssignments[index] ?? const {}).forEach((id, n) {
      if (known.contains(id) && n > 0) units[id] = n;
    });
    if (item.quantity > 1 && units.isNotEmpty) {
      final assigned = units.values.fold(0, (a, b) => a + b);
      return ItemAssignmentState(
        index: index,
        quantity: item.quantity,
        assignedUnits: assigned,
        people: units.keys.toList(),
        unitAssignments: units,
      );
    }
    final people = <String>{
      for (final id in itemAssignments[index] ?? const <String>[])
        if (known.contains(id)) id,
    }.toList();
    return ItemAssignmentState(
      index: index,
      quantity: item.quantity,
      assignedUnits: people.isEmpty ? 0 : item.quantity,
      people: people,
      unitAssignments: const {},
    );
  }
}

class ItemAssignmentState {
  const ItemAssignmentState({
    required this.index,
    required this.quantity,
    required this.assignedUnits,
    required this.people,
    required this.unitAssignments,
  });

  final int index;
  final int quantity;
  final int assignedUnits;
  final List<String> people;

  /// Non-empty only for per-unit assignments.
  final Map<String, int> unitAssignments;

  bool get isComplete => assignedUnits == quantity;
  bool get isOver => assignedUnits > quantity;
  bool get isEmpty => assignedUnits == 0;
}

/// A problem the user has to fix before the bill can be saved.
sealed class BillIssue {
  const BillIssue();
}

class NoParticipantsIssue extends BillIssue {
  const NoParticipantsIssue();
}

class UnassignedItemIssue extends BillIssue {
  const UnassignedItemIssue(this.index, this.assignedUnits, this.quantity);
  final int index;
  final int assignedUnits;
  final int quantity;
}

class OverAssignedItemIssue extends BillIssue {
  const OverAssignedItemIssue(this.index, this.assignedUnits, this.quantity);
  final int index;
  final int assignedUnits;
  final int quantity;
}

class ExactMismatchIssue extends BillIssue {
  /// Positive: amounts are short of the total; negative: over.
  const ExactMismatchIssue(this.remainingMinor);
  final int remainingMinor;
}

class PercentMismatchIssue extends BillIssue {
  const PercentMismatchIssue(this.sum);
  final num sum;
}

class NoSharesIssue extends BillIssue {
  const NoSharesIssue();
}

class DiscountTooLargeIssue extends BillIssue {
  const DiscountTooLargeIssue(this.discountMinor, this.beforeDiscountMinor);
  final int discountMinor;
  final int beforeDiscountMinor;
}

class OverrideExceedsTotalIssue extends BillIssue {
  const OverrideExceedsTotalIssue(this.overrideMinor, this.totalMinor);
  final int overrideMinor;
  final int totalMinor;
}

class OverrideMismatchIssue extends BillIssue {
  const OverrideMismatchIssue(this.overrideMinor, this.totalMinor);
  final int overrideMinor;
  final int totalMinor;
}

enum BreakdownKind {
  item,
  tax,
  service,
  tip,
  delivery,
  other,
  discount,
  methodShare,
  roulette,
  manual,
  adjustment,
}

/// One line of a person's breakdown. Lines always sum to the total.
class BreakdownLine {
  const BreakdownLine({
    required this.kind,
    required this.amountMinor,
    this.label,
    this.units,
    this.quantity,
    this.sharedWith,
    this.baseMinor,
  });

  final BreakdownKind kind;

  /// Signed: the discount line is negative.
  final int amountMinor;

  /// Item name or other-charge label.
  final String? label;

  /// Per-unit item assignment: took [units] of [quantity].
  final int? units;
  final int? quantity;

  /// Item shared equally between this many people (incl. this person).
  final int? sharedWith;

  /// The amount this line was taken from (charge total, bill total).
  final int? baseMinor;
}

class PersonBreakdown {
  const PersonBreakdown({required this.id, required this.lines});

  final String id;
  final List<BreakdownLine> lines;

  int get totalMinor => lines.fold(0, (sum, l) => sum + l.amountMinor);

  int _sum(BreakdownKind kind) => lines
      .where((l) => l.kind == kind)
      .fold(0, (sum, l) => sum + l.amountMinor);

  int get itemsMinor => _sum(BreakdownKind.item);
  int get taxMinor => _sum(BreakdownKind.tax);
  int get serviceMinor => _sum(BreakdownKind.service);
  int get tipMinor => _sum(BreakdownKind.tip);
  int get deliveryMinor => _sum(BreakdownKind.delivery);
  int get otherMinor => _sum(BreakdownKind.other);

  /// Positive amount taken off.
  int get discountMinor => -_sum(BreakdownKind.discount);

  /// Everything that is not an item line (charges, method, adjustments).
  int get nonItemMinor => totalMinor - itemsMinor;
}

class BillComputation {
  const BillComputation({
    required this.draft,
    required this.people,
    required this.issues,
  });

  final BillDraft draft;

  /// Per participant, in participant order.
  final Map<String, PersonBreakdown> people;
  final List<BillIssue> issues;

  bool get isValid => issues.isEmpty;
  int get grandTotalMinor => draft.grandTotalMinor;

  Map<String, int> get totals =>
      people.map((id, p) => MapEntry(id, p.totalMinor));

  int get allocatedMinor => people.values.fold(0, (s, p) => s + p.totalMinor);

  /// Money not yet on anybody (unassigned items in a preview).
  int get unallocatedMinor => grandTotalMinor - allocatedMinor;

  int shareOf(String id) => people[id]?.totalMinor ?? 0;

  List<int> get unassignedItemIndexes => [
    for (final i in issues)
      if (i is UnassignedItemIssue) i.index,
    for (final i in issues)
      if (i is OverAssignedItemIssue) i.index,
  ];
}

/// Computes [draft]. Always returns per-person numbers (a best-effort
/// preview when there are issues, e.g. unassigned items are left out) so
/// the assignment screen can show live totals.
BillComputation computeBill(BillDraft draft) {
  final ids = <String>[];
  for (final id in draft.participantIds) {
    if (!ids.contains(id)) ids.add(id);
  }
  if (ids.isEmpty) {
    return BillComputation(
      draft: draft,
      people: const {},
      issues: const [NoParticipantsIssue()],
    );
  }

  final issues = <BillIssue>[];
  Map<String, List<BreakdownLine>> lines;

  final beforeDiscount = draft.grandTotalMinor + draft.discountMinor;
  final discountOk = draft.discountMinor <= beforeDiscount;
  if (!discountOk) {
    issues.add(DiscountTooLargeIssue(draft.discountMinor, beforeDiscount));
  }

  if (draft.method == SplitMethod.items) {
    lines = _itemizedLines(draft, ids, issues, applyDiscount: discountOk);
  } else {
    lines = _methodLines(
      draft,
      ids,
      issues,
      total: discountOk ? draft.grandTotalMinor : beforeDiscount,
    );
  }

  final winner = draft.rouletteWinnerId;
  if (winner != null && ids.contains(winner)) {
    final total = lines.values
        .expand((l) => l)
        .fold(0, (s, l) => s + l.amountMinor);
    lines = {
      for (final id in ids)
        id: id == winner
            ? [
                BreakdownLine(
                  kind: BreakdownKind.roulette,
                  amountMinor: total,
                  baseMinor: total,
                ),
              ]
            : const <BreakdownLine>[],
    };
  } else if (draft.overrides.isNotEmpty) {
    lines = _applyOverrides(draft, ids, lines, issues);
  }

  return BillComputation(
    draft: draft,
    people: {
      for (final id in ids) id: PersonBreakdown(id: id, lines: lines[id]!),
    },
    issues: issues,
  );
}

Map<String, List<BreakdownLine>> _itemizedLines(
  BillDraft draft,
  List<String> ids,
  List<BillIssue> issues, {
  required bool applyDiscount,
}) {
  final lines = {for (final id in ids) id: <BreakdownLine>[]};
  final billItems = <BillItem>[];

  for (var i = 0; i < draft.items.length; i++) {
    final item = draft.items[i];
    if (item.quantity < 1) {
      issues.add(UnassignedItemIssue(i, 0, item.quantity));
      continue;
    }
    final state = draft.assignmentOf(i);
    if (state.isOver) {
      issues.add(OverAssignedItemIssue(i, state.assignedUnits, item.quantity));
      continue;
    }
    if (!state.isComplete) {
      issues.add(UnassignedItemIssue(i, state.assignedUnits, item.quantity));
      continue;
    }
    if (state.unitAssignments.isNotEmpty) {
      state.unitAssignments.forEach((id, units) {
        lines[id]!.add(
          BreakdownLine(
            kind: BreakdownKind.item,
            label: item.name,
            amountMinor: item.unitPriceMinor * units,
            units: units,
            quantity: item.quantity,
            baseMinor: item.lineTotalMinor,
          ),
        );
      });
      billItems.add(
        BillItem(
          name: item.name,
          unitPrice: item.unitPriceMinor,
          quantity: item.quantity,
          unitAssignments: state.unitAssignments,
        ),
      );
    } else {
      final parts = splitEqually(item.lineTotalMinor, state.people);
      parts.forEach((id, part) {
        lines[id]!.add(
          BreakdownLine(
            kind: BreakdownKind.item,
            label: item.name,
            amountMinor: part,
            sharedWith: state.people.length,
            quantity: item.quantity,
            baseMinor: item.lineTotalMinor,
          ),
        );
      });
      billItems.add(
        BillItem(
          name: item.name,
          unitPrice: item.unitPriceMinor,
          quantity: item.quantity,
          assignees: state.people,
        ),
      );
    }
  }

  // Charges (without discount) through the domain, so the allocation rules
  // stay in one place.
  final split = splitItemizedBill(
    participants: ids,
    items: billItems,
    charges: BillCharges(
      tax: draft.taxMinor,
      serviceCharge: draft.serviceMinor,
      tip: draft.tipMinor,
      deliveryFee: draft.deliveryMinor,
      otherCharges: [
        for (final c in draft.otherCharges)
          OtherCharge(label: c.label, amount: c.amountMinor, split: c.split),
      ],
    ),
  );

  void add(String id, BreakdownKind kind, int amount, int base) {
    if (amount == 0) return;
    lines[id]!.add(
      BreakdownLine(kind: kind, amountMinor: amount, baseMinor: base),
    );
  }

  for (final id in ids) {
    final share = split.shares[id]!;
    add(id, BreakdownKind.tax, share.tax, draft.taxMinor);
    add(id, BreakdownKind.service, share.serviceCharge, draft.serviceMinor);
    add(id, BreakdownKind.tip, share.tip, draft.tipMinor);
    add(id, BreakdownKind.delivery, share.deliveryFee, draft.deliveryMinor);
  }
  // Other charges one by one so each keeps its label.
  final assignedSubtotals = {
    for (final id in ids)
      id: lines[id]!
          .where((l) => l.kind == BreakdownKind.item)
          .fold(0, (s, l) => s + l.amountMinor),
  };
  final assignedTotal = assignedSubtotals.values.fold(0, (a, b) => a + b);
  for (final charge in draft.otherCharges) {
    if (charge.amountMinor <= 0) continue;
    final parts = charge.split == ChargeSplit.equal || assignedTotal == 0
        ? splitEqually(charge.amountMinor, ids)
        : allocateByWeights(charge.amountMinor, assignedSubtotals);
    parts.forEach((id, part) {
      if (part == 0) return;
      lines[id]!.add(
        BreakdownLine(
          kind: BreakdownKind.other,
          label: charge.label,
          amountMinor: part,
          baseMinor: charge.amountMinor,
        ),
      );
    });
  }

  if (applyDiscount && draft.discountMinor > 0) {
    _addDiscount(draft, ids, lines);
  }
  return lines;
}

void _addDiscount(
  BillDraft draft,
  List<String> ids,
  Map<String, List<BreakdownLine>> lines,
) {
  final weights = {
    for (final id in ids)
      id: lines[id]!.fold(0, (s, l) => s + l.amountMinor).clamp(0, 1 << 62),
  };
  final weightSum = weights.values.fold(0, (a, b) => a + b);
  // With nothing allocated yet (everything unassigned) there is nothing to
  // discount from; the preview just leaves it out.
  if (weightSum == 0) return;
  final amount = draft.discountMinor > weightSum
      ? weightSum
      : draft.discountMinor;
  allocateByWeights(amount, weights).forEach((id, part) {
    if (part == 0) return;
    lines[id]!.add(
      BreakdownLine(
        kind: BreakdownKind.discount,
        amountMinor: -part,
        baseMinor: draft.discountMinor,
      ),
    );
  });
}

Map<String, List<BreakdownLine>> _methodLines(
  BillDraft draft,
  List<String> ids,
  List<BillIssue> issues, {
  required int total,
}) {
  Map<String, int>? parts;
  switch (draft.method) {
    case SplitMethod.items:
      throw StateError('unreachable');
    case SplitMethod.equal:
      parts = splitEqually(total, ids);
    case SplitMethod.exact:
      final amounts = {for (final id in ids) id: draft.exactAmounts[id] ?? 0};
      final negative = amounts.values.any((v) => v < 0);
      final sum = amounts.values.fold(0, (a, b) => a + b);
      if (negative || sum != total) {
        issues.add(ExactMismatchIssue(total - sum));
        parts = {for (final id in ids) id: amounts[id]!.clamp(0, 1 << 62)};
      } else {
        parts = amounts;
      }
    case SplitMethod.percent:
      final pct = {for (final id in ids) id: draft.percentages[id] ?? 0};
      final sum = pct.values.fold<num>(0, (a, b) => a + b);
      if ((sum - 100).abs() > 1e-6 || pct.values.any((v) => v < 0)) {
        issues.add(PercentMismatchIssue(sum));
        parts = {for (final id in ids) id: 0};
        final positive = {
          for (final e in pct.entries)
            if (e.value > 0) e.key: e.value,
        };
        if (positive.isNotEmpty && sum > 0) {
          // Preview: what each percentage means of the total.
          for (final e in positive.entries) {
            parts[e.key] = (total * e.value / 100).round();
          }
        }
      } else {
        parts = splitByPercentages(total, pct);
      }
    case SplitMethod.shares:
      final weights = {
        for (final id in ids)
          id: (draft.shares[id] ?? 1) < 0 ? 0 : (draft.shares[id] ?? 1),
      };
      final sum = weights.values.fold<num>(0, (a, b) => a + b);
      if (sum <= 0) {
        issues.add(const NoSharesIssue());
        parts = {for (final id in ids) id: 0};
      } else {
        parts = splitByShares(total, weights);
      }
  }
  return {
    for (final id in ids)
      id: [
        if (parts[id] != 0)
          BreakdownLine(
            kind: BreakdownKind.methodShare,
            amountMinor: parts[id]!,
            baseMinor: total,
          ),
      ],
  };
}

Map<String, List<BreakdownLine>> _applyOverrides(
  BillDraft draft,
  List<String> ids,
  Map<String, List<BreakdownLine>> lines,
  List<BillIssue> issues,
) {
  final total = draft.grandTotalMinor;
  final fixed = <String, int>{
    for (final e in draft.overrides.entries)
      if (ids.contains(e.key)) e.key: e.value < 0 ? 0 : e.value,
  };
  if (fixed.isEmpty) return lines;
  final fixedSum = fixed.values.fold(0, (a, b) => a + b);
  final others = ids.where((id) => !fixed.containsKey(id)).toList();
  if (fixedSum > total) {
    issues.add(OverrideExceedsTotalIssue(fixedSum, total));
    return lines;
  }
  if (others.isEmpty && fixedSum != total) {
    issues.add(OverrideMismatchIssue(fixedSum, total));
    return lines;
  }
  int current(String id) => lines[id]!.fold(0, (s, l) => s + l.amountMinor);
  final remaining = total - fixedSum;
  final weights = {for (final id in others) id: current(id).clamp(0, 1 << 62)};
  final weightSum = weights.values.fold(0, (a, b) => a + b);
  final rebalanced = others.isEmpty
      ? const <String, int>{}
      : weightSum == 0
      ? splitEqually(remaining, others)
      : allocateByWeights(remaining, weights);

  final result = <String, List<BreakdownLine>>{};
  for (final id in ids) {
    final target = fixed[id] ?? rebalanced[id]!;
    final now = current(id);
    if (fixed.containsKey(id)) {
      result[id] = [
        BreakdownLine(
          kind: BreakdownKind.manual,
          amountMinor: target,
          baseMinor: now,
        ),
      ];
    } else {
      result[id] = [
        ...lines[id]!,
        if (target != now)
          BreakdownLine(
            kind: BreakdownKind.adjustment,
            amountMinor: target - now,
          ),
      ];
    }
  }
  return result;
}

/// Major-unit double -> minor units for [currency], tolerant of junk.
int minorFromAny(Object? value, String currency) {
  double? d;
  if (value is num) d = value.toDouble();
  if (value is String) d = double.tryParse(value.trim().replaceAll(',', '.'));
  if (d == null || d.isNaN || d.isInfinite) return 0;
  return toMinorUnits(d, currency);
}
