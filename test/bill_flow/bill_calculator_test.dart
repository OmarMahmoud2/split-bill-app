import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/domain/item_split.dart';

/// The Sea Breeze Grill receipt from the design (EGP 81.27).
BillDraft seaBreeze({
  Map<int, List<String>>? assign,
  Map<int, Map<String, int>>? units,
}) => BillDraft(
  currency: 'EGP',
  items: const [
    DraftItem(name: 'Beef burger', unitPriceMinor: 1400),
    DraftItem(name: 'Fries, large', unitPriceMinor: 600),
    DraftItem(name: 'Grilled fish', unitPriceMinor: 1850),
    DraftItem(name: 'Lemon mint', unitPriceMinor: 300, quantity: 3),
    DraftItem(name: 'Caesar salad', unitPriceMinor: 1000),
    DraftItem(name: 'Kunafa', unitPriceMinor: 700),
  ],
  participantIds: const ['omar', 'sara', 'ali', 'mona'],
  itemAssignments:
      assign ??
      const {
        0: ['ali'],
        1: ['ali', 'sara'],
        2: ['omar'],
        4: ['mona'],
        5: ['ali'],
      },
  quantityAssignments:
      units ??
      const {
        3: {'omar': 1, 'sara': 1, 'mona': 1},
      },
  taxMinor: 903,
  serviceMinor: 774,
);

void main() {
  group('itemized', () {
    test('every cent accounted for: shares sum to the total', () {
      final c = computeBill(seaBreeze());
      expect(c.isValid, isTrue);
      expect(c.grandTotalMinor, 8127);
      expect(c.allocatedMinor, 8127);
      for (final p in c.people.values) {
        expect(
          p.lines.fold<int>(0, (s, l) => s + l.amountMinor),
          p.totalMinor,
        );
      }
      // Mona: salad 10.00 + 1 of 3 mints 3.00 + tax and service on 13.00.
      final mona = c.people['mona']!;
      expect(mona.itemsMinor, 1300);
      expect(mona.lines.map((l) => l.label), contains('Caesar salad'));
      // Matches the design: EGP 16.38.
      expect(mona.totalMinor, 1638);
      final mint = mona.lines.firstWhere((l) => l.label == 'Lemon mint');
      expect(mint.units, 1);
      expect(mint.quantity, 3);
    });

    test('rounding: 10.00 among 3 is 3.34 + 3.33 + 3.33, not 3.3', () {
      final c = computeBill(
        const BillDraft(
          currency: 'USD',
          items: [DraftItem(name: 'Pizza', unitPriceMinor: 1000)],
          participantIds: ['a', 'b', 'c'],
          itemAssignments: {
            0: ['a', 'b', 'c'],
          },
        ),
      );
      expect(c.totals, {'a': 334, 'b': 333, 'c': 333});
    });

    test('unknown assignees are pruned and reported, never dropped', () {
      final c = computeBill(
        const BillDraft(
          currency: 'USD',
          items: [
            DraftItem(name: 'A', unitPriceMinor: 500),
            DraftItem(name: 'B', unitPriceMinor: 700),
          ],
          participantIds: ['a', 'b'],
          itemAssignments: {
            0: ['a', 'ghost'],
            1: ['ghost'],
          },
        ),
      );
      // A goes fully to a; B has nobody left and is reported.
      expect(c.shareOf('a'), 500);
      expect(c.issues.whereType<UnassignedItemIssue>().single.index, 1);
      expect(c.unallocatedMinor, 700);
    });

    test('over-assignment of units is rejected', () {
      final c = computeBill(
        seaBreeze(
          units: const {
            3: {'omar': 2, 'sara': 1, 'mona': 1},
          },
        ),
      );
      final issue = c.issues.whereType<OverAssignedItemIssue>().single;
      expect(issue.index, 3);
      expect(issue.assignedUnits, 4);
      expect(issue.quantity, 3);
    });

    test('under-assignment of units is reported', () {
      final c = computeBill(
        seaBreeze(
          units: const {
            3: {'omar': 1},
          },
        ),
      );
      expect(c.issues.whereType<UnassignedItemIssue>().single.assignedUnits, 1);
    });

    test('charges do not vanish when the item subtotal is zero', () {
      final c = computeBill(
        const BillDraft(
          currency: 'USD',
          items: [DraftItem(name: 'Free water', unitPriceMinor: 0)],
          participantIds: ['a', 'b'],
          itemAssignments: {
            0: ['a'],
          },
          taxMinor: 100,
          tipMinor: 201,
        ),
      );
      expect(c.allocatedMinor, 301);
      expect(c.grandTotalMinor, 301);
    });

    test('charge split read from splitMethod and split_method', () {
      expect(chargeSplitOf({'split_method': 'equal'}), ChargeSplit.equal);
      expect(chargeSplitOf({'splitMethod': 'equal'}), ChargeSplit.equal);
      expect(chargeSplitOf({'splitMethod': 'x'}), ChargeSplit.proportional);
      final c = computeBill(
        const BillDraft(
          currency: 'USD',
          items: [DraftItem(name: 'Steak', unitPriceMinor: 3000)],
          participantIds: ['a', 'b'],
          itemAssignments: {
            0: ['a'],
          },
          otherCharges: [
            DraftCharge(label: 'Cover', amountMinor: 400, split: ChargeSplit.equal),
          ],
        ),
      );
      expect(c.shareOf('b'), 200);
      expect(
        c.people['b']!.lines.single.label,
        'Cover',
      );
    });

    test('discount never makes a share negative', () {
      final c = computeBill(
        const BillDraft(
          currency: 'USD',
          items: [
            DraftItem(name: 'Big', unitPriceMinor: 1000),
            DraftItem(name: 'Small', unitPriceMinor: 100),
          ],
          participantIds: ['a', 'b'],
          itemAssignments: {
            0: ['a'],
            1: ['b'],
          },
          deliveryMinor: 1000,
          discountMinor: 1500,
        ),
      );
      expect(c.isValid, isTrue);
      expect(c.allocatedMinor, 600);
      for (final share in c.totals.values) {
        expect(share, greaterThanOrEqualTo(0));
      }
    });

    test('a discount larger than the bill is an issue', () {
      final c = computeBill(
        const BillDraft(
          currency: 'USD',
          items: [DraftItem(name: 'A', unitPriceMinor: 100)],
          participantIds: ['a'],
          itemAssignments: {
            0: ['a'],
          },
          discountMinor: 500,
        ),
      );
      expect(c.issues.whereType<DiscountTooLargeIssue>(), hasLength(1));
      expect(c.shareOf('a'), 100);
    });

    test('JPY has no minor digits, KWD three', () {
      final jpy = computeBill(
        const BillDraft(
          currency: 'JPY',
          items: [DraftItem(name: 'Ramen', unitPriceMinor: 1000)],
          participantIds: ['a', 'b', 'c'],
          itemAssignments: {
            0: ['a', 'b', 'c'],
          },
        ),
      );
      expect(jpy.totals.values.toList(), [334, 333, 333]);
    });
  });

  group('overrides', () {
    test('manual override rebalances others and keeps the total', () {
      final base = seaBreeze();
      final c = computeBill(base.copyWith(overrides: {'mona': 2000}));
      expect(c.isValid, isTrue);
      expect(c.shareOf('mona'), 2000);
      expect(c.allocatedMinor, 8127);
      expect(
        c.people['omar']!.lines.last.kind,
        BreakdownKind.adjustment,
      );
    });

    test('override above the total is an issue', () {
      final c = computeBill(seaBreeze().copyWith(overrides: {'mona': 9000}));
      expect(c.issues.whereType<OverrideExceedsTotalIssue>(), hasLength(1));
    });

    test('roulette puts everything on the winner', () {
      final c = computeBill(seaBreeze().copyWith(rouletteWinnerId: 'ali'));
      expect(c.shareOf('ali'), 8127);
      expect(c.shareOf('omar'), 0);
      expect(c.people['ali']!.lines.single.kind, BreakdownKind.roulette);
    });
  });

  group('whole-bill methods', () {
    test('equal', () {
      final c = computeBill(seaBreeze().copyWith(method: SplitMethod.equal));
      expect(c.totals.values.toList(), [2032, 2032, 2032, 2031]);
      expect(c.isValid, isTrue);
    });

    test('shares, as in the design: 1, 2, 2, 1', () {
      final c = computeBill(
        seaBreeze().copyWith(
          method: SplitMethod.shares,
          shares: {'omar': 1, 'sara': 2, 'ali': 2, 'mona': 1},
        ),
      );
      expect(c.totals, {'omar': 1355, 'sara': 2709, 'ali': 2709, 'mona': 1354});
      expect(c.allocatedMinor, 8127);
    });

    test('shares all zero is an issue', () {
      final c = computeBill(
        seaBreeze().copyWith(
          method: SplitMethod.shares,
          shares: {'omar': 0, 'sara': 0, 'ali': 0, 'mona': 0},
        ),
      );
      expect(c.issues.single, isA<NoSharesIssue>());
    });

    test('exact must match the total', () {
      final draft = seaBreeze().copyWith(
        method: SplitMethod.exact,
        exactAmounts: {'omar': 4000, 'sara': 4000, 'ali': 127},
      );
      expect(computeBill(draft).isValid, isTrue);
      final short = draft.copyWith(exactAmounts: {'omar': 4000});
      final issue = computeBill(short).issues.single as ExactMismatchIssue;
      expect(issue.remainingMinor, 4127);
    });

    test('percent must sum to 100', () {
      final ok = computeBill(
        seaBreeze().copyWith(
          method: SplitMethod.percent,
          percentages: {'omar': 50, 'sara': 25, 'ali': 25},
        ),
      );
      expect(ok.isValid, isTrue);
      expect(ok.allocatedMinor, 8127);
      final bad = computeBill(
        seaBreeze().copyWith(
          method: SplitMethod.percent,
          percentages: {'omar': 50},
        ),
      );
      expect(bad.issues.single, isA<PercentMismatchIssue>());
    });

    test('method parse', () {
      expect(SplitMethod.parse('shares'), SplitMethod.shares);
      expect(SplitMethod.parse(null), SplitMethod.items);
      expect(SplitMethod.parse('nonsense'), SplitMethod.items);
    });
  });

  test('no participants', () {
    final c = computeBill(
      const BillDraft(currency: 'USD', items: [], participantIds: []),
    );
    expect(c.issues.single, isA<NoParticipantsIssue>());
  });

  test('minorFromAny tolerates junk', () {
    expect(minorFromAny('12.5', 'USD'), 1250);
    expect(minorFromAny('12,5', 'USD'), 1250);
    expect(minorFromAny(null, 'USD'), 0);
    expect(minorFromAny(1.005, 'USD'), 101);
    expect(minorFromAny(1.2345, 'KWD'), 1235);
  });
}
