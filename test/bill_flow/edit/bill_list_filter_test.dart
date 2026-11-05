import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/completed_bills_screen.dart';

Map<String, dynamic> doc({
  required String host,
  required DateTime date,
  String name = 'Sea Breeze Grill',
  String currency = 'USD',
  List<Map<String, dynamic>>? participants,
  List<String> items = const ['Kunafa'],
  String? groupName,
}) => {
  'hostId': host,
  'storeName': name,
  'currency': currency,
  'date': Timestamp.fromDate(date),
  'groupName': ?groupName,
  'items': [
    for (final i in items) {'name': i, 'priceMinor': 100, 'qty': 1},
  ],
  'participants':
      participants ??
      [
        {'id': 'me', 'name': 'Omar', 'shareMinor': 1000, 'status': 'PAID'},
        {'id': 'ali', 'name': 'Ali', 'shareMinor': 2000, 'status': 'PENDING'},
        {'id': 'sara', 'name': 'Sára', 'shareMinor': 3000, 'status': 'PAID'},
      ],
};

final now = DateTime(2026, 11, 5, 12); // Thursday

BillListEntry entry(String id, Map<String, dynamic> data) =>
    BillListEntry.fromData(id, data, 'me');

void main() {
  test('normalizeForSearch folds case, accents and Arabic marks', () {
    expect(normalizeForSearch('  Café  Crème '), 'cafe creme');
    expect(normalizeForSearch('مُحَمَّد'), 'محمد');
    expect(normalizeForSearch('أحمد'), 'احمد');
    expect(normalizeForSearch('ŞİMŞEK'), normalizeForSearch('simsek'));
  });

  group('BillListEntry amounts (current user perspective)', () {
    test('host, open: what the others still owe, positive', () {
      final e = entry('a', doc(host: 'me', date: now));
      expect(e.isMine, isTrue);
      expect(e.settled, isFalse);
      expect(e.amountMinor, 2000);
      expect(e.peopleCount, 3);
      expect(e.payerName, isNull);
    });

    test('host, settled: the others\' whole shares', () {
      final e = entry(
        'a',
        doc(
          host: 'me',
          date: now,
          participants: [
            {'id': 'me', 'name': 'Omar', 'shareMinor': 1000, 'status': 'PAID'},
            {'id': 'ali', 'name': 'Ali', 'shareMinor': 2000, 'status': 'PAID'},
          ],
        ),
      );
      expect(e.settled, isTrue);
      expect(e.amountMinor, 2000);
    });

    test('participant: my share, negative, and who paid', () {
      final e = BillListEntry.fromData(
        'b',
        doc(
          host: 'ali',
          date: now,
          participants: [
            {'id': 'ali', 'name': 'Ali', 'shareMinor': 1000, 'status': 'PAID'},
            {'id': 'me', 'name': 'Omar', 'share': 12.0, 'status': 'PENDING'},
          ],
        ),
        'me',
      );
      expect(e.amountMinor, -1200, reason: 'legacy double read via BillReader');
      expect(e.settled, isFalse);
      expect(e.payerName, 'Ali');
    });

    test('currency decimals come from the bill (KWD 3)', () {
      final e = entry(
        'k',
        doc(
          host: 'ali',
          date: now,
          currency: 'KWD',
          participants: [
            {'id': 'ali', 'name': 'Ali', 'share': 1.0, 'status': 'PAID'},
            {'id': 'me', 'name': 'Omar', 'share': 1.25, 'status': 'PENDING'},
          ],
        ),
      );
      expect(e.currency, 'KWD');
      expect(e.amountMinor, -1250);
    });
  });

  group('filterAndGroupBills', () {
    final entries = [
      entry('week1', doc(host: 'me', date: DateTime(2026, 11, 4))),
      entry(
        'week2',
        doc(
          host: 'ali',
          name: 'Taxi to Blue Hole',
          date: DateTime(2026, 11, 3),
          items: ['Ride'],
          participants: [
            {'id': 'ali', 'name': 'Ali', 'shareMinor': 1200, 'status': 'PAID'},
            {'id': 'me', 'name': 'Omar', 'shareMinor': 1200, 'status': 'PAID'},
          ],
        ),
      ),
      entry(
        'nov1',
        doc(
          host: 'me',
          name: 'Diving day',
          date: DateTime(2026, 11, 1),
          groupName: 'Dahab trip',
        ),
      ),
      entry(
        'oct',
        doc(host: 'me', name: 'Internet', date: DateTime(2026, 10, 30)),
      ),
      entry(
        'sep',
        doc(
          host: 'me',
          name: 'Café Riche',
          date: DateTime(2026, 9, 12),
          items: ['Crème brûlée'],
        ),
      ),
    ];

    List<String> ids(BillListQuery q) => [
      for (final s in filterAndGroupBills(entries, q, now))
        for (final e in s.entries) e.id,
    ];

    test('this week first, then one section per month, newest first', () {
      final sections = filterAndGroupBills(entries, const BillListQuery(), now);
      expect(sections.map((s) => s.kind), [
        BillSectionKind.thisWeek,
        BillSectionKind.month,
        BillSectionKind.month,
        BillSectionKind.month,
      ]);
      expect(sections[0].entries.map((e) => e.id), ['week1', 'week2']);
      expect(sections[1].month, DateTime(2026, 11));
      expect(sections[1].entries.single.id, 'nov1');
      expect(sections[2].month, DateTime(2026, 10));
      expect(sections[3].month, DateTime(2026, 9));
    });

    test('week starts on Monday', () {
      expect(startOfWeek(now), DateTime(2026, 11, 2));
      expect(startOfWeek(DateTime(2026, 11, 2, 8)), DateTime(2026, 11, 2));
      expect(startOfWeek(DateTime(2026, 11, 8, 23)), DateTime(2026, 11, 2));
    });

    test('search: store, people, items; case and accent insensitive', () {
      expect(ids(const BillListQuery(text: 'TAXI')), ['week2']);
      expect(ids(const BillListQuery(text: 'ride')), ['week2']);
      expect(ids(const BillListQuery(text: 'cafe')), ['sep']);
      expect(ids(const BillListQuery(text: 'creme brulee')), ['sep']);
      expect(ids(const BillListQuery(text: 'sara')).length, 4);
      expect(ids(const BillListQuery(text: 'dahab')), ['nov1']);
      expect(ids(const BillListQuery(text: 'zzz')), isEmpty);
    });

    test('status, mine and month chips combine', () {
      expect(ids(const BillListQuery(status: BillStatusFilter.settled)), [
        'week2',
      ]);
      expect(
        ids(const BillListQuery(status: BillStatusFilter.open)),
        isNot(contains('week2')),
      );
      expect(
        ids(const BillListQuery(mineOnly: true)),
        isNot(contains('week2')),
      );
      expect(ids(BillListQuery(month: DateTime(2026, 11))), [
        'week1',
        'week2',
        'nov1',
      ]);
      expect(
        ids(
          BillListQuery(
            month: DateTime(2026, 11),
            mineOnly: true,
            text: 'diving',
          ),
        ),
        ['nov1'],
      );
      expect(const BillListQuery().hasFilters, isFalse);
      expect(const BillListQuery(mineOnly: true).hasFilters, isTrue);
    });
  });
}
