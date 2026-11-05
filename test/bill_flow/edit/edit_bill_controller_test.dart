import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/screens/edit_bill/edit_bill_controller.dart';

Map<String, dynamic> bill({int hostShare = 600, int aliShare = 900}) => {
  'hostId': 'host',
  'storeName': 'Sea Breeze Grill',
  'currency': 'USD',
  'date': Timestamp.fromDate(DateTime(2026, 11, 4, 20, 30)),
  'groupId': 'g1',
  'paymentMethods': [
    {'type': 'instapay', 'value': 'x'},
  ],
  'items': [
    {
      'name': 'Kunafa',
      'priceMinor': 600,
      'price': 6.0,
      'qty': 1,
      'assignedTo': ['host', 'ali'],
    },
    {
      'name': 'Fries',
      'priceMinor': 300,
      'price': 3.0,
      'qty': 3,
      'assignedTo': ['host', 'ali'],
      'unitAssignments': {'host': 1, 'ali': 2},
    },
  ],
  'charges': {
    'minor': {'tax': 0, 'service': 0, 'tip': 0, 'delivery': 0, 'discount': 0},
  },
  'participants': [
    {
      'id': 'host',
      'name': 'Omar',
      'shareMinor': hostShare,
      'status': 'PAID',
      'isPaid': true,
    },
    {
      'id': 'ali',
      'name': 'Ali',
      'shareMinor': aliShare,
      'status': 'PENDING',
      'isPaid': false,
      'proofUrl': 'https://proof',
    },
  ],
  'totalMinor': hostShare + aliShare,
  'history': [
    {
      'by': 'host',
      'byName': 'Omar',
      'at': Timestamp.fromDate(DateTime(2026, 11, 4, 20, 30)),
      'change': 'created',
    },
  ],
};

EditBillController controller([Map<String, dynamic>? data]) =>
    EditBillController(billData: data ?? bill(), currentUid: 'host');

Map<String, dynamic> participant(Map<String, dynamic> update, String id) =>
    (update['participants'] as List).cast<Map<String, dynamic>>().firstWhere(
      (p) => p['id'] == id,
    );

final now = DateTime(2026, 11, 5, 9);

void main() {
  group('draft operations', () {
    const base = BillDraft(
      currency: 'USD',
      items: [
        DraftItem(name: 'A', unitPriceMinor: 100),
        DraftItem(name: 'B', unitPriceMinor: 200, quantity: 2),
        DraftItem(name: 'C', unitPriceMinor: 300),
      ],
      participantIds: ['x', 'y'],
      itemAssignments: {
        0: ['x'],
        2: ['y'],
      },
      quantityAssignments: {
        1: {'x': 1, 'y': 1},
      },
    );

    test('removing an item shifts the later assignments', () {
      final d = draftRemoveItem(base, 0);
      expect(d.items.map((i) => i.name), ['B', 'C']);
      expect(d.quantityAssignments, {
        0: {'x': 1, 'y': 1},
      });
      expect(d.itemAssignments, {
        1: ['y'],
      });
      expect(computeBill(d).isValid, isTrue);
    });

    test('removing a person clears them everywhere', () {
      final d = draftRemoveParticipant(
        base.copyWith(overrides: {'x': 100}),
        'x',
      );
      expect(d.participantIds, ['y']);
      expect(d.itemAssignments[0], isEmpty);
      expect(d.quantityAssignments[1], {'y': 1});
      expect(d.overrides, isEmpty);
    });

    test('per-unit assignment is kept and validated', () {
      final d = draftAssign(base, 1, units: {'x': 2, 'y': 0});
      expect(d.quantityAssignments[1], {'x': 2});
      expect(d.assignmentOf(1).isComplete, isTrue);
      final shared = draftAssign(d, 1, people: ['x', 'y']);
      expect(shared.quantityAssignments.containsKey(1), isFalse);
      expect(shared.itemAssignments[1], ['x', 'y']);
    });

    test('quantity down to 1 turns units into a shared list', () {
      final d = draftUpdateItem(
        base,
        1,
        const DraftItem(name: 'B', unitPriceMinor: 200),
      );
      expect(d.quantityAssignments.containsKey(1), isFalse);
      expect(d.itemAssignments[1], ['x', 'y']);
      expect(computeBill(d).isValid, isTrue);
    });

    test('currency change keeps the major values', () {
      final d = draftChangeCurrency(base.copyWith(taxMinor: 125), 'KWD');
      expect(d.currency, 'KWD');
      expect(d.items.first.unitPriceMinor, 1000);
      expect(d.taxMinor, 1250);
      final yen = draftChangeCurrency(base.copyWith(taxMinor: 150), 'JPY');
      expect(yen.items.first.unitPriceMinor, 1);
      expect(yen.taxMinor, 2);
    });

    test('everyone shares everything', () {
      final d = draftAssignAllToEveryone(base);
      expect(d.quantityAssignments, isEmpty);
      expect(d.itemAssignments.values.every((v) => v.length == 2), isTrue);
    });
  });

  group('money input', () {
    test('parses what people type', () {
      expect(parseMoneyInput('12.5', 'USD'), 1250);
      expect(parseMoneyInput('12,50', 'USD'), 1250);
      expect(parseMoneyInput('1,234.50', 'USD'), 123450);
      expect(parseMoneyInput(' ', 'USD'), 0);
      expect(parseMoneyInput('1.234', 'KWD'), 1234);
      expect(parseMoneyInput('abc', 'USD'), isNull);
      expect(parseMoneyInput('-3', 'USD'), isNull);
    });

    test('shows full currency decimals, never one', () {
      expect(moneyInputText(1250, 'USD'), '12.50');
      expect(moneyInputText(1205, 'KWD'), '1.205');
      expect(moneyInputText(1200, 'JPY'), '1200');
      expect(moneyInputText(0, 'USD'), '');
    });

    test('charge percent label', () {
      expect(chargePercentLabel(1400, 10000, 'USD', locale: 'en'), '14%');
      expect(chargePercentLabel(1250, 10000, 'USD', locale: 'en'), '12.5%');
      expect(chargePercentLabel(0, 10000, 'USD'), '—');
      expect(chargePercentLabel(500, 0, 'USD', locale: 'en'), r'$5.00');
    });
  });

  group('describeIssue', () {
    const d = BillDraft(
      currency: 'USD',
      items: [DraftItem(name: 'Fries', unitPriceMinor: 100, quantity: 3)],
      participantIds: ['x'],
    );
    test('friendly keys with the item name', () {
      expect(
        describeIssue(const UnassignedItemIssue(0, 0, 3), d),
        const IssueMessage('bf_edit_issue_unassigned', {'item': 'Fries'}),
      );
      expect(
        describeIssue(const UnassignedItemIssue(0, 1, 3), d),
        const IssueMessage('bf_edit_issue_units_left', {
          'item': 'Fries',
          'count': '2',
        }),
      );
      expect(
        describeIssue(const OverAssignedItemIssue(0, 4, 3), d),
        const IssueMessage('bf_edit_issue_over_assigned', {'item': 'Fries'}),
      );
      expect(
        describeIssue(const DiscountTooLargeIssue(900, 300), d, locale: 'en'),
        const IssueMessage('bf_edit_issue_discount', {'amount': r'$3.00'}),
      );
    });
  });

  group('EditBillController', () {
    test('loads the bill, unit assignments included', () {
      final c = controller();
      expect(c.name, 'Sea Breeze Grill');
      expect(c.draft.quantityAssignments[1], {'host': 1, 'ali': 2});
      expect(c.computation.totals, {'host': 600, 'ali': 900});
      expect(c.isDirty, isFalse);
      expect(c.canSave, isTrue);
    });

    test('save keeps unit assignments, status, proof and groupId', () {
      final c = controller()
        ..updateItem(0, const DraftItem(name: 'Kunafa', unitPriceMinor: 700));
      final update = c.buildUpdate(now: now, byName: 'Omar');
      final items = (update['items'] as List).cast<Map<String, dynamic>>();
      expect(items[1]['unitAssignments'], {'host': 1, 'ali': 2});
      expect(items[0]['priceMinor'], 700);
      expect(update['totalMinor'], 1600);
      expect(participant(update, 'host')['shareMinor'], 650);
      expect(participant(update, 'ali')['shareMinor'], 950);
      expect(participant(update, 'ali')['status'], 'PENDING');
      expect(participant(update, 'ali')['proofUrl'], 'https://proof');
      expect(participant(update, 'host')['isPaid'], isTrue);
      expect(update['groupId'], 'g1');
      expect(update.containsKey('hostId'), isFalse, reason: 'left untouched');
      expect(update.containsKey('paymentMethods'), isFalse);
      expect(update.containsKey('date'), isFalse, reason: 'date not changed');

      final history = (update['history'] as List).cast<Map<String, dynamic>>();
      expect(history.first['change'], 'item_price');
      expect(history.first['args'], {'item': 'Kunafa', 'from': 600, 'to': 700});
      expect(history.first['by'], 'host');
      expect(history.first['byName'], 'Omar');
      expect(history.first['at'], isA<Timestamp>());
      expect(history.last['change'], 'created');
    });

    test('stored manual shares survive an untouched save', () {
      final c = controller(bill(hostShare: 500, aliShare: 1000))
        ..setName('Sea Breeze');
      final update = c.buildUpdate(now: now);
      expect(update['totalMinor'], 1500);
      expect(participant(update, 'host')['shareMinor'], 500);
      expect(participant(update, 'ali')['shareMinor'], 1000);
      final history = (update['history'] as List).cast<Map<String, dynamic>>();
      expect(history.first['change'], 'renamed');
    });

    test('a money change resets stored manual shares, total stays exact', () {
      final c = controller(bill(hostShare: 500, aliShare: 1000));
      c.setCharges(
        taxMinor: 150,
        serviceMinor: 0,
        tipMinor: 0,
        deliveryMinor: 0,
        discountMinor: 0,
      );
      expect(c.takeOverridesResetNotice(), isTrue);
      expect(c.takeOverridesResetNotice(), isFalse);
      expect(c.computation.isValid, isTrue);
      final update = c.buildUpdate(now: now);
      expect(update['totalMinor'], 1650);
      final sum = (update['participants'] as List).fold<int>(
        0,
        (s, p) => s + (p['shareMinor'] as int),
      );
      expect(sum, 1650);
    });

    test('blocks saving with issues: unassigned item, big discount', () {
      final c = controller()
        ..addItem(const DraftItem(name: 'Tea', unitPriceMinor: 200));
      expect(c.canSave, isFalse);
      expect(
        c.issueMessages,
        contains(
          const IssueMessage('bf_edit_issue_unassigned', {'item': 'Tea'}),
        ),
      );
      c.assignItem(2, people: ['ali']);
      expect(c.canSave, isTrue);
      c.setCharges(
        taxMinor: 0,
        serviceMinor: 0,
        tipMinor: 0,
        deliveryMinor: 0,
        discountMinor: 99999,
      );
      expect(c.canSave, isFalse);
      expect(c.issueMessages.single.key, 'bf_edit_issue_discount');
    });

    test('people: add, duplicate, host cannot be removed', () {
      final c = controller();
      expect(
        c.addParticipant(id: 'sara', name: 'Sara'),
        AddParticipantResult.added,
      );
      expect(
        c.addParticipant(id: 'sara', name: 'Sara'),
        AddParticipantResult.duplicate,
      );
      expect(
        c.addParticipant(id: null, name: 'X'),
        AddParticipantResult.missingId,
      );
      expect(c.removeParticipant('host'), RemoveParticipantResult.isHost);
      expect(c.removeParticipant('ali'), RemoveParticipantResult.removed);
      expect(c.draft.quantityAssignments[1], {'host': 1});
      final changes = c
          .historyEntries(now: now)
          .map((e) => '${e.change}:${e.args['name']}')
          .toList();
      expect(changes, containsAll(['person_added:Sara', 'person_removed:Ali']));
    });

    test('marking someone paid is tracked and kept', () {
      final c = controller()..togglePaid('ali');
      final update = c.buildUpdate(now: now);
      expect(participant(update, 'ali')['status'], 'PAID');
      expect(participant(update, 'ali')['isPaid'], isTrue);
      final history = (update['history'] as List).cast<Map<String, dynamic>>();
      expect(history.first['change'], 'marked_paid');
      expect((history.first['args'] as Map)['name'], 'Ali');
      expect(history.where((h) => h['change'] == 'edited'), isEmpty);
    });

    test('a new date is written', () {
      final c = controller()..setDate(DateTime(2026, 11, 2, 20, 30));
      final update = c.buildUpdate(now: now);
      expect(
        (update['date'] as Timestamp).toDate(),
        DateTime(2026, 11, 2, 20, 30),
      );
    });
  });
}
