/// Activity feed items derived from bills and payments (no extra writes).
library;

import 'package:split_bill_app/data/models.dart';

enum ActivityKind { billAdded, payment, iou }

/// How the amount on an activity row reads for the user.
enum ActivityTone { owed, owe, neutral }

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.kind,
    required this.actorId,
    required this.actorName,
    required this.date,
    required this.amountMinor,
    required this.currency,
    required this.tone,
    this.counterpartId,
    this.counterpartName,
    this.title = '',
    this.groupId,
    this.billId,
    this.hasProof = false,
  });

  final String id;
  final ActivityKind kind;
  final String actorId;
  final String actorName;
  final String? counterpartId;
  final String? counterpartName;
  final String title;
  final String? groupId;
  final String? billId;
  final DateTime date;

  /// Unsigned amount; [tone] says which way it goes for the user.
  final int amountMinor;
  final String currency;
  final ActivityTone tone;
  final bool hasProof;

  /// Signed for display: + when the user receives, − when the user owes.
  int get signedMinor => switch (tone) {
    ActivityTone.owed => amountMinor,
    ActivityTone.owe => -amountMinor,
    ActivityTone.neutral => amountMinor,
  };
}

/// "Sara added Taxi": for the host, the bill total; for a participant, what
/// they owe on it (amber while unpaid).
ActivityItem activityFromBill(BillRecord b, String me) {
  final iAmHost = b.hostId == me;
  final myShare = b.share(me);
  final owe = !iAmHost && myShare != null && !myShare.isPaid;
  return ActivityItem(
    id: 'bill:${b.id}',
    kind: ActivityKind.billAdded,
    actorId: b.hostId,
    actorName: b.nameOf(b.hostId),
    title: b.title,
    groupId: b.groupId,
    billId: b.id,
    date: b.date ?? DateTime.fromMillisecondsSinceEpoch(0),
    amountMinor: iAmHost || myShare == null ? b.totalMinor : myShare.shareMinor,
    currency: b.currency,
    tone: owe ? ActivityTone.owe : ActivityTone.neutral,
  );
}

/// "Ali paid you" (teal), "You paid Mona" (neutral), "Ali owes you" (IOU).
ActivityItem activityFromPayment(PaymentRecord p, String me) {
  final isIou = p.kind == PaymentKind.iou;
  final ActivityTone tone;
  if (isIou) {
    tone = p.to == me
        ? ActivityTone.owed
        : (p.from == me ? ActivityTone.owe : ActivityTone.neutral);
  } else {
    tone = p.to == me ? ActivityTone.owed : ActivityTone.neutral;
  }
  return ActivityItem(
    id: 'pay:${p.id}',
    kind: isIou ? ActivityKind.iou : ActivityKind.payment,
    actorId: p.from,
    actorName: p.fromName ?? '',
    counterpartId: p.to,
    counterpartName: p.toName,
    title: p.note ?? '',
    groupId: p.groupId,
    billId: p.billId,
    date: p.createdAt ?? DateTime.now(),
    amountMinor: p.amountMinor,
    currency: p.currency,
    tone: tone,
    hasProof: p.proofUrl != null,
  );
}

/// Result of merging two date-descending pages.
class MergedPage<T> {
  const MergedPage(this.items, this.takenFromA, this.takenFromB);
  final List<T> items;
  final int takenFromA;
  final int takenFromB;
}

/// Merges two lists that are each sorted newest first and keeps the newest
/// [limit]. The counts say how far each source's cursor should advance, so
/// items that were fetched but not shown come back on the next page.
MergedPage<T> mergeNewestFirst<T>(
  List<T> a,
  List<T> b,
  DateTime Function(T) dateOf,
  int limit,
) {
  final out = <T>[];
  var i = 0, j = 0;
  while (out.length < limit && (i < a.length || j < b.length)) {
    if (j >= b.length ||
        (i < a.length && !dateOf(a[i]).isBefore(dateOf(b[j])))) {
      out.add(a[i++]);
    } else {
      out.add(b[j++]);
    }
  }
  return MergedPage(out, i, j);
}

enum DayBucket { today, yesterday, earlier }

DayBucket dayBucket(DateTime date, DateTime now) {
  final d = DateTime(date.year, date.month, date.day);
  final n = DateTime(now.year, now.month, now.day);
  final diff = n.difference(d).inDays;
  if (diff <= 0) return DayBucket.today;
  if (diff == 1) return DayBucket.yesterday;
  return DayBucket.earlier;
}

/// Groups items (newest first) into consecutive day sections.
List<(DateTime, List<ActivityItem>)> groupByDay(List<ActivityItem> items) {
  final out = <(DateTime, List<ActivityItem>)>[];
  for (final item in items) {
    final day = DateTime(item.date.year, item.date.month, item.date.day);
    if (out.isEmpty || out.last.$1 != day) {
      out.add((day, [item]));
    } else {
      out.last.$2.add(item);
    }
  }
  return out;
}
