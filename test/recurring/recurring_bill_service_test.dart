import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/recurring/recurring_bill_screen.dart';
import 'package:split_bill_app/services/recurring_bill_service.dart';

void main() {
  group('nextRecurringDate', () {
    test('weekly adds seven days across a month end', () {
      expect(
        nextRecurringDate(DateTime(2026, 11, 27), RecurringFrequency.weekly),
        DateTime(2026, 12, 4),
      );
    });

    test('monthly rolls over the year', () {
      expect(
        nextRecurringDate(DateTime(2026, 12, 1), RecurringFrequency.monthly),
        DateTime(2027, 1, 1),
      );
    });

    test('monthly clamps to the month end and keeps the anchor', () {
      final dates = upcomingRecurringDates(
        DateTime(2027, 1, 31),
        RecurringFrequency.monthly,
        count: 4,
      );
      expect(dates, [
        DateTime(2027, 1, 31),
        DateTime(2027, 2, 28),
        DateTime(2027, 3, 31),
        DateTime(2027, 4, 30),
      ]);
    });

    test('monthly in a leap year gives 29 Feb', () {
      expect(
        nextRecurringDate(DateTime(2028, 1, 30), RecurringFrequency.monthly),
        DateTime(2028, 2, 29),
      );
    });

    test('yearly from 29 Feb clamps and returns in leap years', () {
      final dates = upcomingRecurringDates(
        DateTime(2028, 2, 29),
        RecurringFrequency.yearly,
        count: 5,
      );
      expect(dates.last, DateTime(2032, 2, 29));
      expect(dates[1], DateTime(2029, 2, 28));
    });

    test('drops the time of day', () {
      expect(
        nextRecurringDate(
          DateTime(2026, 3, 10, 18, 30),
          RecurringFrequency.weekly,
        ),
        DateTime(2026, 3, 17),
      );
    });
  });

  test('frequency ids round-trip and default to monthly', () {
    for (final f in RecurringFrequency.values) {
      expect(RecurringFrequency.fromId(f.id), f);
    }
    expect(RecurringFrequency.fromId('daily'), RecurringFrequency.monthly);
  });

  group('RecurringBillTemplate', () {
    RecurringBillTemplate t({String name = 'Rent', int amount = 1260000}) =>
        RecurringBillTemplate(
          name: name,
          amountMinor: amount,
          currency: 'EGP',
          frequency: RecurringFrequency.monthly,
          nextOn: DateTime(2026, 12, 1, 9),
          createdBy: 'me',
          memberIds: const ['me', 'ali', 'mona'],
        );

    test('validates name, amount and group', () {
      expect(t().validate(), isEmpty);
      expect(t(name: ' ', amount: 0).validate(), [
        'rec_error_name',
        'rec_error_amount',
      ]);
    });

    test('stores the documented fields', () {
      final data = t().toFirestore();
      expect(data['name'], 'Rent');
      expect(data['amountMinor'], 1260000);
      expect(data['currency'], 'EGP');
      expect(data['frequency'], 'monthly');
      expect(data['anchorDay'], 1);
      expect((data['nextOn'] as Timestamp).toDate(), DateTime(2026, 12, 1));
      expect(data['createdBy'], 'me');
      expect(data['memberIds'], ['me', 'ali', 'mona']);
      expect(data['active'], isTrue);
      expect(data['createdAt'], isA<FieldValue>());
    });
  });

  group('parseAmountMinor', () {
    test('accepts dot and comma decimals', () {
      expect(parseAmountMinor('12600', 'EGP'), 1260000);
      expect(parseAmountMinor('12,600.50', 'USD'), 1260050);
      expect(parseAmountMinor('12.600,5', 'EUR'), 1260050);
      expect(parseAmountMinor('1500', 'JPY'), 1500);
    });
    test('rejects empty, zero and junk', () {
      expect(parseAmountMinor('', 'USD'), isNull);
      expect(parseAmountMinor('0', 'USD'), isNull);
      expect(parseAmountMinor('abc', 'USD'), isNull);
    });
  });

  test('group option reads members and marks the current user', () {
    final g = RecurringGroupOption.fromFirestore(
      'g1',
      {
        'name': 'Flat 4B',
        'members': [
          {'id': 'me', 'name': 'Omar'},
          {'id': 'ali', 'name': 'Ali'},
        ],
        'memberIds': ['me', 'ali', 'mona'],
      },
      currentUid: 'me',
      youLabel: 'You',
    );
    expect(g.name, 'Flat 4B');
    expect(g.members, {'me': 'You', 'ali': 'Ali', 'mona': ''});
  });
}
