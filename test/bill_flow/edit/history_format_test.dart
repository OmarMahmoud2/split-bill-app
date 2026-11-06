import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/screens/edit_bill/history_format.dart';

/// Echoes the key and its args so tests see exactly what was looked up.
String fake(String key, Map<String, String> args) {
  if (args.isEmpty) return key;
  final sorted = args.keys.toList()..sort();
  return '$key(${sorted.map((k) => '$k=${args[k]}').join(',')})';
}

/// A tiny English catalogue with real placeholder replacement.
const _en = {
  'bf_edit_history_you': 'You',
  'bf_edit_history_someone': 'Someone',
  'bf_edit_history_item_price': 'changed {item} from {from} to {to}',
  'bf_edit_history_created': 'created the bill',
  'bf_edit_history_you_item_price': 'changed {item} from {from} to {to}',
  'bf_edit_history_you_created': 'created the bill',
  'bf_edit_time_hours': '{count} h ago',
};

String english(String key, Map<String, String> args) {
  var s = _en[key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}

BillHistoryEntry entry(
  String change, {
  Map<String, dynamic> args = const {},
  String by = 'u2',
  String? byName = 'Ali',
}) => BillHistoryEntry(
  by: by,
  byName: byName,
  at: DateTime(2026, 11, 4, 10),
  change: change,
  args: args,
);

String action(BillHistoryEntry e, {String currency = 'USD'}) =>
    describeHistoryEntry(
      e,
      currentUid: 'me',
      currency: currency,
      translate: fake,
      locale: 'en',
    ).action;

void main() {
  group('relativeTimeOf', () {
    final now = DateTime(2026, 11, 5, 12);

    test('buckets', () {
      expect(
        relativeTimeOf(now.subtract(const Duration(seconds: 20)), now).unit,
        RelativeUnit.justNow,
      );
      expect(
        relativeTimeOf(now.subtract(const Duration(minutes: 5)), now),
        RelativeTime(RelativeUnit.minutes, count: 5, at: now),
      );
      expect(
        relativeTimeOf(
          now.subtract(const Duration(hours: 2, minutes: 59)),
          now,
        ),
        RelativeTime(RelativeUnit.hours, count: 2, at: now),
      );
      expect(
        relativeTimeOf(now.subtract(const Duration(days: 3)), now),
        RelativeTime(RelativeUnit.days, count: 3, at: now),
      );
      expect(
        relativeTimeOf(now.subtract(const Duration(days: 8)), now).unit,
        RelativeUnit.date,
      );
    });

    test('future times (clock skew) read as just now', () {
      expect(
        relativeTimeOf(now.add(const Duration(minutes: 3)), now).unit,
        RelativeUnit.justNow,
      );
    });

    test('labels go through the translation keys', () {
      String label(Duration d) =>
          relativeTimeLabel(now.subtract(d), now, translate: fake);
      expect(label(Duration.zero), 'bf_edit_time_just_now');
      expect(
        label(const Duration(minutes: 7)),
        'bf_edit_time_minutes(count=7)',
      );
      expect(label(const Duration(hours: 2)), 'bf_edit_time_hours(count=2)');
      expect(label(const Duration(days: 6)), 'bf_edit_time_days(count=6)');
      expect(
        relativeTimeLabel(
          DateTime(2026, 10, 28),
          now,
          translate: fake,
          locale: 'en',
        ),
        'Oct 28',
      );
      expect(
        relativeTimeLabel(
          DateTime(2025, 10, 28),
          now,
          translate: fake,
          locale: 'en',
        ),
        'Oct 28, 2025',
      );
    });
  });

  group('describeHistoryEntry', () {
    test('author is You for the current user, else the stored name', () {
      final mine = describeHistoryEntry(
        entry('created', by: 'me'),
        currentUid: 'me',
        currency: 'USD',
        translate: fake,
      );
      expect(mine.author, 'bf_edit_history_you');
      final theirs = describeHistoryEntry(
        entry('created'),
        currentUid: 'me',
        currency: 'USD',
        translate: fake,
      );
      expect(theirs.author, 'Ali');
      final unknown = describeHistoryEntry(
        entry('created', byName: null),
        currentUid: 'me',
        currency: 'USD',
        translate: fake,
      );
      expect(unknown.author, 'bf_edit_history_someone');
    });

    test('board line: changed Kunafa from 6.00 to 7.00', () {
      final line = describeHistoryEntry(
        entry(
          'item_price',
          by: 'me',
          args: {'item': 'Kunafa', 'from': 600, 'to': 700},
        ),
        currentUid: 'me',
        currency: 'USD',
        translate: english,
        locale: 'en',
      );
      expect(line.toString(), 'You changed Kunafa from 6.00 to 7.00');
    });

    test('money args follow the currency decimals', () {
      expect(
        action(
          entry('item_price', args: {'item': 'Tea', 'from': 1500, 'to': 2250}),
          currency: 'KWD',
        ),
        'bf_edit_history_item_price(from=1.500,item=Tea,to=2.250)',
      );
      expect(
        action(
          entry('charges', args: {'from': 100, 'to': 1250}),
          currency: 'JPY',
        ),
        'bf_edit_history_charges(from=100,to=1,250)',
      );
    });

    test('every change code has its template', () {
      expect(action(entry('created')), 'bf_edit_history_created');
      expect(action(entry('edited')), 'bf_edit_history_edited');
      expect(
        action(entry('renamed', args: {'from': 'A', 'to': 'B'})),
        'bf_edit_history_renamed(from=A,to=B)',
      );
      expect(
        action(entry('item_added', args: {'item': 'Tea', 'to': 350})),
        'bf_edit_history_item_added(amount=3.50,item=Tea)',
      );
      expect(
        action(entry('item_added', args: {'item': 'Tea'})),
        'bf_edit_history_item_added_plain(item=Tea)',
      );
      expect(
        action(entry('item_removed', args: {'item': 'Tea'})),
        'bf_edit_history_item_removed(item=Tea)',
      );
      expect(
        action(entry('person_added', args: {'name': 'Sara'})),
        'bf_edit_history_person_added(name=Sara)',
      );
      expect(
        action(entry('person_removed', args: {'name': 'Sara'})),
        'bf_edit_history_person_removed(name=Sara)',
      );
      expect(
        action(entry('split_method', args: {'from': 'items', 'to': 'equal'})),
        'bf_edit_history_split_method('
        'from=bf_edit_method_items,to=bf_edit_method_equal)',
      );
      expect(
        action(entry('currency', args: {'from': 'USD', 'to': 'EGP'})),
        'bf_edit_history_currency(from=USD,to=EGP)',
      );
    });

    test('marked_paid: own share vs somebody else', () {
      expect(action(entry('marked_paid')), 'bf_edit_history_marked_paid_self');
      expect(
        action(entry('marked_paid', args: {'name': 'Ali', 'id': 'u2'})),
        'bf_edit_history_marked_paid_self',
      );
      expect(
        action(entry('marked_paid', args: {'name': 'Sara', 'id': 'u3'})),
        'bf_edit_history_marked_paid(name=Sara)',
      );
    });

    test('unknown change codes fall back to edited', () {
      expect(action(entry('teleported')), 'bf_edit_history_edited');
    });
  });
}
