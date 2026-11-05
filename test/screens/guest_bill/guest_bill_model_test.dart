import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/guest_bill/guest_bill_model.dart';

/// The v3 mockup bill: Mona had a Caesar salad and a third of the lemon
/// mint; 14% tax and 12% service on a 57.00 subtotal.
Map<String, dynamic> seaBreeze({Object? monaShare = 16.38, int? shareMinor}) =>
    {
      'storeName': 'Sea Breeze Grill',
      'hostId': 'omar',
      'hostName': 'Omar',
      'currencyCode': 'EGP',
      'total': 71.82,
      'charges': {'taxAmount': 7.98, 'serviceCharge': 6.84},
      'items': [
        {
          'name': 'Caesar salad',
          'price': 10.0,
          'qty': 1,
          'assignedTo': ['mona'],
        },
        {
          'name': 'Lemon mint',
          'price': 9.0,
          'qty': 1,
          'assignedTo': ['sara', 'ali', 'mona'],
        },
        {
          'name': 'Burger',
          'price': 20.0,
          'qty': 1,
          'assignedTo': ['sara'],
        },
        {
          'name': 'Fish',
          'price': 18.0,
          'qty': 1,
          'assignedTo': ['ali'],
        },
      ],
      'participants': [
        {
          'id': 'omar',
          'name': 'Omar',
          'share': 0.0,
          'status': 'PAID',
          'phoneNumber': '+201001234567',
        },
        {'id': 'sara', 'name': 'Sara', 'share': 29.0, 'status': 'PAID'},
        {'id': 'ali', 'name': 'Ali', 'share': 26.44, 'status': 'PAID'},
        {
          'id': 'mona',
          'name': 'Mona',
          'share': monaShare,
          'shareMinor': ?shareMinor,
          'status': 'PENDING',
        },
      ],
      'paymentMethods': {'InstaPay': 'omar@instapay'},
    };

void main() {
  group('parseGuestLink', () {
    test('reads ?billId= with ?p= and legacy ?uid=', () {
      expect(
        parseGuestLink(Uri.parse('https://x.web.app/?billId=abc&p=mona')),
        const GuestLink(billId: 'abc', participantId: 'mona'),
      );
      expect(
        parseGuestLink(Uri.parse('https://x.web.app/?billId=abc&uid=ali')),
        const GuestLink(billId: 'abc', participantId: 'ali'),
      );
    });

    test('reads /bill/<id> and /b/<id>', () {
      expect(
        parseGuestLink(Uri.parse('https://x.web.app/bill/abc?p=mona')),
        const GuestLink(billId: 'abc', participantId: 'mona'),
      );
      expect(
        parseGuestLink(Uri.parse('https://x.web.app/b/xyz')),
        const GuestLink(billId: 'xyz'),
      );
    });

    test('is null without a bill id', () {
      expect(parseGuestLink(Uri.parse('https://x.web.app/')), isNull);
      expect(parseGuestLink(Uri.parse('https://x.web.app/?billId=')), isNull);
      expect(parseGuestLink(Uri.parse('https://x.web.app/bill/')), isNull);
    });
  });

  group('GuestBill', () {
    test('reads legacy fields in minor units', () {
      final bill = GuestBill.fromMap('b1', seaBreeze());
      expect(bill.currency, 'EGP');
      expect(bill.totalMinor, 7182);
      expect(bill.guests.map((p) => p.name), ['Sara', 'Ali', 'Mona']);
      expect(bill.participant('mona')!.shareMinor, 1638);
      expect(bill.participant('mona')!.status, GuestPayStatus.pending);
      expect(bill.hostPhone, '+201001234567');
      expect(bill.isSettled, isFalse);
    });

    test('prefers shareMinor and the 2.0 currency field', () {
      final data = seaBreeze(shareMinor: 1700)..['currency'] = 'usd';
      final bill = GuestBill.fromMap('b1', data);
      expect(bill.currency, 'USD');
      expect(bill.participant('mona')!.shareMinor, 1700);
    });

    test('is settled when every guest paid', () {
      final data = seaBreeze();
      (data['participants'] as List).last['status'] = 'PAID';
      expect(GuestBill.fromMap('b1', data).isSettled, isTrue);
    });

    test('legacy isPaid without status counts as paid', () {
      final data = seaBreeze();
      final mona = (data['participants'] as List).last as Map;
      mona.remove('status');
      mona['isPaid'] = true;
      expect(
        GuestBill.fromMap('b1', data).participant('mona')!.status,
        GuestPayStatus.paid,
      );
    });

    test('expires by expiresAt or status', () {
      final now = DateTime(2026, 11, 5);
      final data = seaBreeze()..['expiresAt'] = DateTime(2026, 11, 1);
      expect(GuestBill.fromMap('b1', data).isExpired(now), isTrue);
      expect(GuestBill.fromMap('b1', seaBreeze()).isExpired(now), isFalse);
      final archived = seaBreeze()..['status'] = 'ARCHIVED';
      expect(GuestBill.fromMap('b1', archived).isExpired(now), isTrue);
    });
  });

  group('GuestBreakdown', () {
    test('matches the mockup: items, tax 14%, service 12%', () {
      final b = GuestBill.fromMap('b1', seaBreeze()).breakdownFor('mona');
      expect(b.itemized, isTrue);
      expect(b.totalMinor, 1638);
      expect(b.lines.map((l) => (l.kind, l.amountMinor)).toList(), [
        (GuestLineKind.item, 1000),
        (GuestLineKind.item, 300),
        (GuestLineKind.tax, 182),
        (GuestLineKind.service, 156),
      ]);
      expect(b.lines[1].sharedWith, 3);
      expect(b.lines[2].ratePercent, '14');
      expect(b.lines[2].baseMinor, 1300);
      expect(b.lines[3].ratePercent, '12');
      expect(b.lines.fold<int>(0, (s, l) => s + l.amountMinor), b.totalMinor);
    });

    test('adds an adjustment line when the stored share differs', () {
      final b = GuestBill.fromMap(
        'b1',
        seaBreeze(monaShare: 17.0),
      ).breakdownFor('mona');
      expect(b.totalMinor, 1700);
      expect(b.lines.last.kind, GuestLineKind.adjustment);
      expect(b.lines.last.amountMinor, 62);
      expect(b.lines.fold<int>(0, (s, l) => s + l.amountMinor), b.totalMinor);
    });

    test('falls back to the stored share without items', () {
      final data = seaBreeze()..remove('items');
      final b = GuestBill.fromMap('b1', data).breakdownFor('mona');
      expect(b.itemized, isFalse);
      expect(b.totalMinor, 1638);
      expect(b.lines.single.kind, GuestLineKind.share);
    });

    test('falls back when items name unknown people', () {
      final data = seaBreeze();
      (data['items'] as List).add({
        'name': 'Ghost',
        'price': 5.0,
        'assignedTo': ['nobody'],
      });
      final b = GuestBill.fromMap('b1', data).breakdownFor('mona');
      expect(b.itemized, isFalse);
      expect(b.totalMinor, 1638);
    });

    test('hides a rate that does not reproduce the charge', () {
      final data = seaBreeze();
      (data['charges'] as Map)['taxAmount'] = 7.77;
      final b = GuestBill.fromMap('b1', data).breakdownFor('mona');
      final tax = b.lines.firstWhere((l) => l.kind == GuestLineKind.tax);
      expect(tax.ratePercent, isNull);
    });

    test('discount is a negative line', () {
      final data = seaBreeze();
      (data['charges'] as Map)['discountAmount'] = 5.70;
      final b = GuestBill.fromMap('b1', data).breakdownFor('mona');
      final discount = b.lines.firstWhere(
        (l) => l.kind == GuestLineKind.discount,
      );
      expect(discount.amountMinor, -130);
    });
  });
}
