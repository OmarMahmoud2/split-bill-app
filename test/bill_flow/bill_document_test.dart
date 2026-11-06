import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/bill_flow/share_links.dart';

Map<String, dynamic> receipt() => {
  'restaurant_name': 'Sea Breeze Grill',
  'items': [
    {'name': 'Burger', 'price': 14.0, 'qty': 1},
    {'name': 'Mint', 'price': 3.0, 'qty': 3},
  ],
  'tax_amount': 2.31,
  'other_charges': [
    {'label': 'Cover', 'amount': 1.0, 'splitMethod': 'equal'},
  ],
};

void main() {
  test('draftFromReceipt reads legacy receipt maps in minor units', () {
    final draft = draftFromReceipt(
      receiptData: receipt(),
      participantIds: const ['current_user', 'b'],
      currency: 'egp',
    );
    expect(draft.currency, 'EGP');
    expect(draft.items[1].unitPriceMinor, 300);
    expect(draft.items[1].quantity, 3);
    expect(draft.taxMinor, 231);
    expect(draft.otherCharges.single.split.name, 'equal');
    expect(draft.grandTotalMinor, 1400 + 900 + 231 + 100);
  });

  group('buildBillFields', () {
    late Map<String, dynamic> fields;
    setUp(() {
      final draft = draftFromReceipt(
        receiptData: receipt(),
        participantIds: const ['current_user', 'b'],
        currency: 'EGP',
        itemAssignments: const {
          0: ['b'],
        },
        quantityAssignments: const {
          1: {'current_user': 2, 'b': 1},
        },
      );
      fields = buildBillFields(
        computation: computeBill(draft),
        participants: const [
          BillParticipantInfo(id: 'current_user', name: 'Omar'),
          BillParticipantInfo(id: 'b', name: 'Mona', isGuest: true),
        ],
        hostUid: 'uid1',
        storeName: 'Sea Breeze Grill',
        groupId: 'g1',
      );
    });

    test('writes the 2.0 contract and keeps legacy fields', () {
      expect(fields['currency'], 'EGP');
      expect(fields['currencyCode'], 'EGP');
      expect(fields['splitMethod'], 'items');
      expect(fields['groupId'], 'g1');
      expect(fields['totalMinor'], 2631);
      expect(fields['total'], 26.31);
      final ps = fields['participants'] as List;
      final sum = ps.fold<int>(0, (s, p) => s + (p['shareMinor'] as int));
      expect(sum, fields['totalMinor']);
      expect(ps.first['id'], 'uid1');
      expect(ps.first['isPaid'], isTrue);
      expect(ps.last['status'], 'PENDING');
      expect(ps.last['share'], isA<double>());
      expect(fields['participants_uids'], ['uid1', 'b']);
    });

    test('quantity assignments survive the save', () {
      final mint = (fields['items'] as List)[1] as Map;
      expect(mint['unitAssignments'], {'uid1': 2, 'b': 1});
      expect(mint['assignedTo'], ['uid1', 'b']);
      expect(mint['priceMinor'], 300);
      expect(mint['price'], 3.0);
    });

    test('other charges keep both split keys', () {
      final cover = ((fields['charges'] as Map)['otherCharges'] as List).single;
      expect(cover['split_method'], 'equal');
      expect(cover['splitMethod'], 'equal');
      expect(cover['amountMinor'], 100);
    });

    test('BillReader round-trips the saved bill exactly', () {
      final reader = BillReader(fields);
      expect(reader.currency, 'EGP');
      expect(reader.totalMinor, 2631);
      final mona = reader.breakdownFor('b');
      expect(mona.totalMinor, reader.shareMinorFor('b'));
      // Mona took 1 of 3 mints, not half the line (legacy bug).
      final mint = mona.lines.firstWhere((l) => l.label == 'Mint');
      expect(mint.amountMinor, 300);
      expect(mint.units, 1);
    });

    test('previous payment status is kept on edit', () {
      final draft = BillReader(fields).toDraft();
      final again = buildBillFields(
        computation: computeBill(draft),
        participants: const [
          BillParticipantInfo(id: 'uid1', name: 'Omar'),
          BillParticipantInfo(id: 'b', name: 'Mona'),
        ],
        hostUid: 'uid1',
        previousParticipants: [
          {
            'id': 'b',
            'isPaid': true,
            'status': 'PAID',
            'paidVia': 'cash',
            'shareMinor': (fields['participants'] as List).last['shareMinor'],
          },
        ],
      );
      final mona = (again['participants'] as List).last as Map;
      expect(mona['isPaid'], isTrue);
      expect(mona['paidVia'], 'cash');
    });
  });

  group('BillReader legacy fallback', () {
    final legacy = <String, dynamic>{
      'currencyCode': 'USD',
      'total': 10.0,
      'items': [
        {
          'name': 'Pizza',
          'price': 10.0,
          'qty': 1,
          'assignedTo': ['a', 'b', 'c'],
        },
      ],
      'participants': [
        {'id': 'a', 'share': 3.3333333},
        {'id': 'b', 'share': 3.3333333},
        {'id': 'c', 'share': 3.3333333},
      ],
      'charges': {'taxAmount': 0, 'otherCharges': []},
    };

    test('reads doubles when minor fields are missing', () {
      final r = BillReader(legacy);
      expect(r.currency, 'USD');
      expect(r.splitMethod, SplitMethod.items);
      expect(r.shareMinorFor('a'), 333);
      expect(r.totalMinor, 999);
    });

    test('breakdown is recomputed exactly when stored shares drifted', () {
      final r = BillReader(legacy);
      final a = r.breakdownFor('a');
      expect(a.totalMinor, r.shareMinorFor('a'));
    });
  });

  group('history', () {
    test('appendHistory puts new entries first and caps the list', () {
      final at = DateTime.utc(2026, 11, 4);
      final existing = List.generate(
        kBillHistoryCap,
        (i) => {'by': 'x', 'at': Timestamp.fromDate(at), 'change': 'edited'},
      );
      final list = appendHistory(existing, [
        BillHistoryEntry(by: 'me', at: at, change: 'created'),
      ]);
      expect(list.length, kBillHistoryCap);
      expect(list.first['change'], 'created');
      expect(list.first['at'], isA<Timestamp>());
    });

    test('diffDrafts describes price, people, method changes', () {
      const before = BillDraft(
        currency: 'EGP',
        items: [DraftItem(name: 'Kunafa', unitPriceMinor: 600)],
        participantIds: ['a', 'b'],
      );
      final after = before.copyWith(
        items: const [DraftItem(name: 'Kunafa', unitPriceMinor: 700)],
        participantIds: const ['a', 'c'],
        method: SplitMethod.equal,
      );
      final entries = diffDrafts(
        before: before,
        after: after,
        by: 'a',
        at: DateTime(2026),
        participantNames: const {'b': 'Sara', 'c': 'Ali'},
      );
      final changes = entries.map((e) => e.change).toList();
      expect(changes, containsAll(['item_price', 'person_added',
          'person_removed', 'split_method']));
      final price = entries.firstWhere((e) => e.change == 'item_price');
      expect(price.args, {'item': 'Kunafa', 'from': 600, 'to': 700});
      final round = BillHistoryEntry.fromMap(price.toMap());
      expect(round.change, 'item_price');
      expect(round.at, DateTime(2026));
    });

    test('no change still records an edit', () {
      const d = BillDraft(currency: 'USD', items: [], participantIds: ['a']);
      final e = diffDrafts(before: d, after: d, by: 'a', at: DateTime(2026));
      expect(e.single.change, 'edited');
    });
  });

  group('share links', () {
    test('personal link carries p', () {
      expect(
        personalBillUrl('bill1', participantId: 'mona'),
        'https://splitbillapp-ffc39.web.app/bill/bill1?p=mona',
      );
      expect(
        personalBillUrl('bill1'),
        'https://splitbillapp-ffc39.web.app/bill/bill1',
      );
    });

    test('WhatsApp and SMS links encode the text', () {
      final wa = whatsAppUri('Mona, your share is EGP 16.38');
      expect(wa.toString(), contains('Mona%2C%20your%20share'));
      final sms = smsUri('a b', phone: '+20 100');
      expect(sms.toString(), 'sms:+20100?body=a%20b');
    });
  });
}
