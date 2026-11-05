import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/domain/domain_errors.dart';
import 'package:split_bill_app/domain/item_split.dart';
import 'package:split_bill_app/domain/money.dart';

/// Verbatim double-precision port of
/// `_BillSummaryConfirmScreenState._calculateFinalShares`
/// (lib/bill_summary_confirm_screen.dart) without roulette/manual overrides.
/// Used as an oracle: the domain result must match it to within rounding.
Map<String, double> legacyShares({
  required List<String> participants,
  required List<Map<String, dynamic>> items,
  required Map<int, List<String>> itemAssignments,
  required Map<int, Map<String, int>> quantityAssignments,
  double tax = 0,
  double service = 0,
  double tip = 0,
  double discount = 0,
  double delivery = 0,
  List<Map<String, dynamic>> otherCharges = const [],
}) {
  final shares = <String, double>{for (final p in participants) p: 0.0};
  for (var i = 0; i < items.length; i++) {
    final price = (items[i]['price'] as num).toDouble();
    final qty = (items[i]['qty'] as num?)?.toInt() ?? 1;
    if (qty > 1 &&
        quantityAssignments.containsKey(i) &&
        quantityAssignments[i]!.isNotEmpty) {
      quantityAssignments[i]!.forEach((uid, assignedQty) {
        if (shares.containsKey(uid)) shares[uid] = shares[uid]! + price * assignedQty;
      });
    } else {
      final ids = itemAssignments[i];
      if (ids != null && ids.isNotEmpty) {
        final split = price * qty / ids.length;
        for (final uid in ids) {
          if (shares.containsKey(uid)) shares[uid] = shares[uid]! + split;
        }
      }
    }
  }
  var totalItemsCost = shares.values.fold(0.0, (a, b) => a + b);
  if (totalItemsCost == 0) totalItemsCost = 1;
  final count = participants.isEmpty ? 1 : participants.length;
  final propOther = otherCharges
      .where((c) => c['split_method'] != 'equal')
      .fold(0.0, (a, c) => a + (c['amount'] as num).toDouble());
  final equalOther = otherCharges
      .where((c) => c['split_method'] == 'equal')
      .fold(0.0, (a, c) => a + (c['amount'] as num).toDouble());
  return shares.map((uid, amount) {
    final p = amount / totalItemsCost;
    return MapEntry(
      uid,
      amount +
          tax * p +
          service * p +
          tip * p +
          delivery / count +
          propOther * p +
          equalOther / count -
          discount * p,
    );
  });
}

int _sum(Iterable<int> v) => v.fold(0, (a, b) => a + b);

void main() {
  group('splitItemizedBill - dinner for three (USD)', () {
    // Pizza shared by all, burger for a, salad for b, 3 sodas one each.
    final items = [
      const BillItem(name: 'Pizza', unitPrice: 1800, assignees: ['a', 'b', 'c']),
      const BillItem(name: 'Burger', unitPrice: 1250, assignees: ['a']),
      const BillItem(name: 'Salad', unitPrice: 975, assignees: ['b']),
      const BillItem(
        name: 'Soda',
        unitPrice: 250,
        quantity: 3,
        unitAssignments: {'a': 1, 'b': 1, 'c': 1},
      ),
    ];
    const charges = BillCharges(
      tax: 382,
      tip: 716,
      discount: 500,
      deliveryFee: 300,
    );
    late ItemizedSplit result;

    setUp(() {
      result = splitItemizedBill(
        participants: ['a', 'b', 'c'],
        items: items,
        charges: charges,
      );
    });

    test('item subtotals', () {
      expect(result.shares['a']!.items, 2100);
      expect(result.shares['b']!.items, 1825);
      expect(result.shares['c']!.items, 850);
      expect(result.itemsSubtotal, 4775);
    });

    test('proportional tax/tip/discount and equal delivery', () {
      final a = result.shares['a']!;
      expect(a.tax, 168);
      expect(a.tip, 315);
      expect(a.discount, 220);
      expect(a.deliveryFee, 100);
      expect(result.totals, {'a': 2463, 'b': 2154, 'c': 1056});
    });

    test('per-person totals sum exactly to the grand total', () {
      expect(result.grandTotal, 4775 + 382 + 716 + 300 - 500);
      expect(_sum(result.totals.values), result.grandTotal);
    });

    test('matches the legacy double computation to the cent', () {
      final legacy = legacyShares(
        participants: ['a', 'b', 'c'],
        items: [
          {'price': 18.0, 'qty': 1},
          {'price': 12.5, 'qty': 1},
          {'price': 9.75, 'qty': 1},
          {'price': 2.5, 'qty': 3},
        ],
        itemAssignments: {
          0: ['a', 'b', 'c'],
          1: ['a'],
          2: ['b'],
        },
        quantityAssignments: {
          3: {'a': 1, 'b': 1, 'c': 1},
        },
        tax: 3.82,
        tip: 7.16,
        discount: 5.0,
        delivery: 3.0,
      );
      for (final p in ['a', 'b', 'c']) {
        expect(
          (result.totals[p]! - toMinorUnits(legacy[p]!, 'USD')).abs(),
          lessThanOrEqualTo(1),
          reason: 'participant $p',
        );
      }
    });

    test('PersonShare.total is consistent with its components', () {
      for (final s in result.shares.values) {
        expect(
          s.total,
          s.items +
              s.tax +
              s.serviceCharge +
              s.tip +
              s.deliveryFee +
              s.otherCharges -
              s.discount,
        );
      }
    });
  });

  group('splitItemizedBill - rounding and other charges', () {
    test('10.00 item shared three ways splits 334/333/333', () {
      final r = splitItemizedBill(
        participants: ['a', 'b', 'c'],
        items: const [BillItem(name: 'Platter', unitPrice: 1000, assignees: ['a', 'b', 'c'])],
      );
      expect(r.totals, {'a': 334, 'b': 333, 'c': 333});
    });

    test('remainder for a shared item follows assignee order, not participant order', () {
      final r = splitItemizedBill(
        participants: ['a', 'b', 'c'],
        items: const [BillItem(name: 'Platter', unitPrice: 1000, assignees: ['c', 'b', 'a'])],
      );
      expect(r.totals, {'a': 333, 'b': 333, 'c': 334});
    });

    test('service charge and other charges (proportional + equal)', () {
      final r = splitItemizedBill(
        participants: ['a', 'b'],
        items: const [
          BillItem(name: 'Steak', unitPrice: 3000, assignees: ['a']),
          BillItem(name: 'Pasta', unitPrice: 1000, assignees: ['b']),
        ],
        charges: const BillCharges(
          serviceCharge: 480,
          otherCharges: [
            OtherCharge(label: 'Cover', amount: 400, split: ChargeSplit.proportional),
            OtherCharge(label: 'Parking', amount: 301, split: ChargeSplit.equal),
          ],
        ),
      );
      expect(r.shares['a']!.serviceCharge, 360);
      expect(r.shares['b']!.serviceCharge, 120);
      expect(r.shares['a']!.otherCharges, 300 + 151);
      expect(r.shares['b']!.otherCharges, 100 + 150);
      expect(_sum(r.totals.values), r.grandTotal);
      expect(r.grandTotal, 4000 + 480 + 400 + 301);
    });

    test('a participant with no items still pays equal charges (delivery)', () {
      final r = splitItemizedBill(
        participants: ['a', 'b'],
        items: const [BillItem(name: 'Coffee', unitPrice: 500, assignees: ['a'])],
        charges: const BillCharges(tax: 50, deliveryFee: 200),
      );
      expect(r.totals, {'a': 500 + 50 + 100, 'b': 100});
    });

    test('many participants with awkward numbers always sum exactly', () {
      final people = List.generate(11, (i) => 'p$i');
      final items = <BillItem>[
        for (var i = 0; i < 17; i++)
          BillItem(
            name: 'item$i',
            unitPrice: 333 + i * 97,
            quantity: 1 + i % 3,
            assignees: [for (var j = 0; j <= i % people.length; j++) people[j]],
          ),
      ];
      final r = splitItemizedBill(
        participants: people,
        items: items,
        charges: const BillCharges(
          tax: 1337,
          serviceCharge: 999,
          tip: 1001,
          deliveryFee: 777,
          discount: 1234,
          otherCharges: [OtherCharge(label: 'x', amount: 55, split: ChargeSplit.equal)],
        ),
      );
      expect(_sum(r.totals.values), r.grandTotal);
      expect(_sum(r.shares.values.map((s) => s.tax)), 1337);
      expect(_sum(r.shares.values.map((s) => s.discount)), 1234);
    });

    test('zero-decimal currency (JPY) example', () {
      // Ramen 980 x2 (one each), gyoza 600 shared, 10% tax 216.
      final r = splitItemizedBill(
        participants: ['ken', 'yui'],
        items: const [
          BillItem(name: 'Ramen', unitPrice: 980, quantity: 2, unitAssignments: {'ken': 1, 'yui': 1}),
          BillItem(name: 'Gyoza', unitPrice: 600, assignees: ['ken', 'yui']),
        ],
        charges: const BillCharges(tax: 256),
      );
      expect(r.totals, {'ken': 1408, 'yui': 1408});
    });

    test('three-decimal currency (KWD) example', () {
      final r = splitItemizedBill(
        participants: ['a', 'b', 'c'],
        items: const [BillItem(name: 'Machboos', unitPrice: 4500, assignees: ['a', 'b', 'c'])],
        charges: const BillCharges(serviceCharge: 451),
      );
      expect(r.totals, {'a': 1651, 'b': 1650, 'c': 1650});
    });
  });

  group('splitItemizedBill - legacy quantity rules', () {
    test('unit assignments are ignored when quantity is 1 (legacy fallback)', () {
      final r = splitItemizedBill(
        participants: ['a', 'b'],
        items: const [
          BillItem(name: 'Cake', unitPrice: 600, assignees: ['a', 'b'], unitAssignments: {'a': 1}),
        ],
      );
      expect(r.totals, {'a': 300, 'b': 300});
    });

    test('multi-quantity item without unit assignments is split over the line total', () {
      final r = splitItemizedBill(
        participants: ['a', 'b'],
        items: const [BillItem(name: 'Beer', unitPrice: 450, quantity: 3, assignees: ['a', 'b'])],
      );
      expect(r.totals, {'a': 675, 'b': 675});
    });
  });

  group('splitItemizedBill - zero amounts and validation', () {
    test('zero-amount bill', () {
      final r = splitItemizedBill(
        participants: ['a', 'b'],
        items: const [BillItem(name: 'Free water', unitPrice: 0, assignees: ['a', 'b'])],
      );
      expect(r.totals, {'a': 0, 'b': 0});
      expect(r.grandTotal, 0);
    });

    test('charges on a zero item subtotal are split equally instead of vanishing', () {
      final r = splitItemizedBill(
        participants: ['a', 'b'],
        items: const [BillItem(name: 'Comp', unitPrice: 0, assignees: ['a'])],
        charges: const BillCharges(tax: 101),
      );
      expect(r.totals, {'a': 51, 'b': 50});
      expect(r.grandTotal, 101);
    });

    test('single person pays everything', () {
      final r = splitItemizedBill(
        participants: ['me'],
        items: const [BillItem(name: 'Lunch', unitPrice: 1299, assignees: ['me'])],
        charges: const BillCharges(tax: 104, tip: 200, discount: 100),
      );
      expect(r.totals, {'me': 1503});
    });

    test('unassigned item throws', () {
      expect(
        () => splitItemizedBill(
          participants: ['a'],
          items: const [BillItem(name: 'Orphan', unitPrice: 100)],
        ),
        throwsA(isA<ItemAssignmentError>()),
      );
    });

    test('under- and over-assigned quantities throw', () {
      for (final assignment in [
        {'a': 1},
        {'a': 2, 'b': 2},
      ]) {
        expect(
          () => splitItemizedBill(
            participants: ['a', 'b'],
            items: [BillItem(name: 'Soda', unitPrice: 200, quantity: 3, unitAssignments: assignment)],
          ),
          throwsA(isA<ItemAssignmentError>()),
        );
      }
    });

    test('unknown assignee throws instead of silently dropping money', () {
      expect(
        () => splitItemizedBill(
          participants: ['a'],
          items: const [BillItem(name: 'Fries', unitPrice: 300, assignees: ['a', 'ghost'])],
        ),
        throwsA(isA<UnknownParticipantError>()),
      );
    });

    test('negative prices or charges throw', () {
      expect(
        () => splitItemizedBill(
          participants: ['a'],
          items: const [BillItem(name: 'Refund', unitPrice: -100, assignees: ['a'])],
        ),
        throwsA(isA<NegativeAmountError>()),
      );
      expect(
        () => splitItemizedBill(
          participants: ['a'],
          items: const [BillItem(name: 'Tea', unitPrice: 100, assignees: ['a'])],
          charges: const BillCharges(tip: -5),
        ),
        throwsA(isA<NegativeAmountError>()),
      );
    });

    test('empty or duplicate participants throw', () {
      expect(() => splitItemizedBill(participants: [], items: const []),
          throwsA(isA<EmptyParticipantsError>()));
      expect(() => splitItemizedBill(participants: ['a', 'a'], items: const []),
          throwsA(isA<DuplicateParticipantError>()));
    });
  });
}
