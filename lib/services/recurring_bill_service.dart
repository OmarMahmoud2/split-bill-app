/// Recurring bill templates (Pro), stored at `groups/{gid}/recurring/{id}`.
///
/// The date math is pure and tested; a backend job is expected to turn due
/// templates into bills (see the report for the proposed rule and job).
library;

import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurringFrequency {
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurringFrequency(this.id);

  /// Stored value.
  final String id;

  static RecurringFrequency fromId(String? id) => RecurringFrequency.values
      .firstWhere((f) => f.id == id, orElse: () => RecurringFrequency.monthly);
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// The occurrence after [from] for [frequency].
///
/// Monthly and yearly keep the [anchorDay] (defaults to `from.day`) and
/// clamp it to the month's last day: anchor 31 gives 31 Jan, 28 Feb (29 in a
/// leap year), 31 Mar. Yearly 29 Feb becomes 28 Feb in common years and
/// returns to 29 Feb in leap years. Time of day is dropped.
DateTime nextRecurringDate(
  DateTime from,
  RecurringFrequency frequency, {
  int? anchorDay,
}) {
  final anchor = (anchorDay ?? from.day).clamp(1, 31);
  switch (frequency) {
    case RecurringFrequency.weekly:
      final d = DateTime(from.year, from.month, from.day + 7);
      return DateTime(d.year, d.month, d.day);
    case RecurringFrequency.monthly:
      final y = from.month == 12 ? from.year + 1 : from.year;
      final m = from.month == 12 ? 1 : from.month + 1;
      return DateTime(y, m, anchor.clamp(1, _daysInMonth(y, m)));
    case RecurringFrequency.yearly:
      final y = from.year + 1;
      return DateTime(
        y,
        from.month,
        anchor.clamp(1, _daysInMonth(y, from.month)),
      );
  }
}

/// The next [count] occurrences starting at (and including) [first].
List<DateTime> upcomingRecurringDates(
  DateTime first,
  RecurringFrequency frequency, {
  int count = 3,
}) {
  final anchor = first.day;
  final dates = <DateTime>[DateTime(first.year, first.month, first.day)];
  while (dates.length < count) {
    dates.add(nextRecurringDate(dates.last, frequency, anchorDay: anchor));
  }
  return dates;
}

/// A recurring bill template.
class RecurringBillTemplate {
  const RecurringBillTemplate({
    required this.name,
    required this.amountMinor,
    required this.currency,
    required this.frequency,
    required this.nextOn,
    required this.createdBy,
    required this.memberIds,
    this.active = true,
  });

  final String name;
  final int amountMinor;
  final String currency;
  final RecurringFrequency frequency;
  final DateTime nextOn;
  final String createdBy;
  final List<String> memberIds;
  final bool active;

  /// Errors as translation keys; empty when valid.
  List<String> validate() => [
    if (name.trim().isEmpty) 'rec_error_name',
    if (amountMinor <= 0) 'rec_error_amount',
    if (memberIds.isEmpty) 'rec_error_group',
  ];

  Map<String, dynamic> toFirestore() => {
    'name': name.trim(),
    'amountMinor': amountMinor,
    'currency': currency,
    'frequency': frequency.id,
    'anchorDay': nextOn.day,
    'nextOn': Timestamp.fromDate(
      DateTime(nextOn.year, nextOn.month, nextOn.day),
    ),
    'createdBy': createdBy,
    'createdAt': FieldValue.serverTimestamp(),
    'memberIds': memberIds,
    'active': active,
  };
}

class RecurringBillService {
  RecurringBillService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Saves [template] under `groups/{groupId}/recurring/`. Returns its id.
  Future<String> save(String groupId, RecurringBillTemplate template) async {
    final ref = await _db
        .collection('groups')
        .doc(groupId)
        .collection('recurring')
        .add(template.toFirestore());
    return ref.id;
  }
}
