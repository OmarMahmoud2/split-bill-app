/// Pure helpers for the bill views (host and participant). No Flutter
/// widgets and no Firebase calls here, so they are unit-testable.
library;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';

/// Payment state of one participant as the bill views show it.
enum PayStatus {
  /// Settled (`status == 'PAID'` or legacy `isPaid == true`).
  paid,

  /// The participant said they paid; the host has to check (`REVIEW`).
  review,

  /// Nothing yet (`PENDING` or missing).
  notYet,
}

/// Reads [PayStatus] from a participant map (1.x and 2.0 shapes).
PayStatus payStatusOf(Map<String, dynamic>? participant) {
  if (participant == null) return PayStatus.notYet;
  final status = participant['status']?.toString().toUpperCase();
  if (status == 'PAID') return PayStatus.paid;
  if (status == 'REVIEW') return PayStatus.review;
  if (status == null && participant['isPaid'] == true) return PayStatus.paid;
  return PayStatus.notYet;
}

extension PayStatusCopy on PayStatus {
  /// Translation key of the status pill.
  String get labelKey => switch (this) {
    PayStatus.paid => 'bf_bill_status_paid',
    PayStatus.review => 'bf_bill_status_check_proof',
    PayStatus.notYet => 'bf_bill_status_not_yet',
  };

  /// Translation key of the pill, seen by the participant themself.
  String get selfLabelKey => switch (this) {
    PayStatus.paid => 'bf_bill_status_paid',
    PayStatus.review => 'bf_bill_status_waiting',
    PayStatus.notYet => 'bf_bill_status_not_yet',
  };
}

/// What the host has collected on a bill, in minor units.
class CollectionSummary {
  const CollectionSummary({
    required this.owedMinor,
    required this.collectedMinor,
    required this.reviewMinor,
    required this.people,
    required this.paidPeople,
  });

  /// Everything other people owe the host (all non-host shares).
  final int owedMinor;

  /// Shares of the people marked paid.
  final int collectedMinor;

  /// Shares waiting for the host to check a proof.
  final int reviewMinor;

  /// Non-host participants.
  final int people;
  final int paidPeople;

  int get outstandingMinor => owedMinor - collectedMinor;

  /// 0..1, for the progress bar.
  double get progress {
    if (owedMinor <= 0) return 0;
    return (collectedMinor / owedMinor).clamp(0.0, 1.0);
  }

  /// Whole percent, floored so it never shows 100 before everyone paid.
  int get percent => (progress * 100).floor();

  /// True when somebody owed something and everybody has paid.
  bool get allSettled => owedMinor > 0 && collectedMinor >= owedMinor;
}

/// Computes [CollectionSummary] for [reader], where [hostId] is the person
/// who paid the bill (their own share is not "owed to you").
CollectionSummary collectionSummary(BillReader reader, {String? hostId}) {
  var owed = 0;
  var collected = 0;
  var review = 0;
  var people = 0;
  var paidPeople = 0;
  for (final p in reader.participants) {
    final id = p['id']?.toString() ?? '';
    if (hostId != null && id == hostId) continue;
    final share = reader.shareMinorOf(p);
    people++;
    owed += share;
    switch (payStatusOf(p)) {
      case PayStatus.paid:
        collected += share;
        paidPeople++;
      case PayStatus.review:
        review += share;
      case PayStatus.notYet:
        break;
    }
  }
  return CollectionSummary(
    owedMinor: owed,
    collectedMinor: collected,
    reviewMinor: review,
    people: people,
    paidPeople: paidPeople,
  );
}

/// The participant the reminder button targets: the first non-host person
/// who has not paid yet (people waiting on a proof check are skipped).
Map<String, dynamic>? nextToRemind(BillReader reader, {String? hostId}) {
  for (final p in reader.participants) {
    final id = p['id']?.toString() ?? '';
    if (hostId != null && id == hostId) continue;
    if (payStatusOf(p) == PayStatus.notYet && reader.shareMinorOf(p) > 0) {
      return p;
    }
  }
  return null;
}

/// True for people added by name only (no app account).
bool isGuestParticipant(Map<String, dynamic> participant) {
  final id = participant['id']?.toString() ?? '';
  return id.isEmpty ||
      id.startsWith('guest_') ||
      participant['isGuest'] == true;
}

/// One or two initials for an avatar.
String initialsOf(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  String first(String s) => String.fromCharCodes(s.runes.take(1)).toUpperCase();
  if (parts.length == 1) return first(parts.first);
  return '${first(parts.first)}${first(parts[1])}';
}

/// A translation key plus its named arguments, or a raw label.
class CopyText {
  const CopyText(this.key, [this.args = const {}]) : raw = null;
  const CopyText.raw(String this.raw) : key = null, args = const {};

  final String? key;
  final Map<String, String> args;
  final String? raw;

  @override
  String toString() => raw ?? '$key$args';
}

/// How a breakdown line is labelled ("Lemon mint, 1 of 3",
/// "Fries, split 2 ways", "Tax share").
CopyText breakdownLineCopy(BreakdownLine line) {
  final label = line.label?.trim() ?? '';
  switch (line.kind) {
    case BreakdownKind.item:
      final name = label.isEmpty ? '?' : label;
      final units = line.units;
      final qty = line.quantity ?? 1;
      if (units != null) {
        if (qty > 1) {
          return CopyText('bf_bill_line_item_units', {
            'item': name,
            'units': '$units',
            'qty': '$qty',
          });
        }
        return CopyText.raw(name);
      }
      final shared = line.sharedWith ?? 1;
      if (shared > 1) {
        return CopyText('bf_bill_line_item_split', {
          'item': name,
          'count': '$shared',
        });
      }
      if (qty > 1) {
        return CopyText('bf_bill_line_item_qty', {'item': name, 'qty': '$qty'});
      }
      return CopyText.raw(name);
    case BreakdownKind.tax:
      return const CopyText('bf_bill_line_tax');
    case BreakdownKind.service:
      return const CopyText('bf_bill_line_service');
    case BreakdownKind.tip:
      return const CopyText('bf_bill_line_tip');
    case BreakdownKind.delivery:
      return const CopyText('bf_bill_line_delivery');
    case BreakdownKind.other:
      if (label.isEmpty) return const CopyText('bf_bill_line_other_charges');
      return CopyText('bf_bill_line_other', {'label': label});
    case BreakdownKind.discount:
      return const CopyText('bf_bill_line_discount');
    case BreakdownKind.methodShare:
      return const CopyText('bf_bill_line_method_share');
    case BreakdownKind.roulette:
      return const CopyText('bf_bill_line_roulette');
    case BreakdownKind.manual:
      return const CopyText('bf_bill_line_manual');
    case BreakdownKind.adjustment:
      return const CopyText('bf_bill_line_adjustment');
  }
}

/// Item lines are the "what you had"; everything else is a charge, shown
/// muted.
bool isItemLine(BreakdownLine line) => line.kind == BreakdownKind.item;

/// "2 min ago" style copy for [then] relative to [now].
CopyText relativeTimeCopy(DateTime then, DateTime now) {
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return const CopyText('bf_bill_time_just_now');
  if (diff.inHours < 1) {
    return CopyText('bf_bill_time_minutes', {'count': '${diff.inMinutes}'});
  }
  if (diff.inDays < 1) {
    return CopyText('bf_bill_time_hours', {'count': '${diff.inHours}'});
  }
  return CopyText('bf_bill_time_days', {'count': '${diff.inDays}'});
}

/// Converts Firestore [Timestamp]s, epoch millis and ISO strings.
DateTime? dateFromAny(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  if (value is Timestamp) return value.toDate();
  return null;
}

/// True when [error] means the device could not reach the server.
bool isOfflineError(Object error) {
  if (error is FirebaseException) {
    return error.code == 'unavailable' ||
        error.code == 'network-request-failed' ||
        error.code == 'deadline-exceeded';
  }
  final text = error.runtimeType.toString();
  return text.contains('SocketException') || text.contains('ClientException');
}

/// Friendly message key for a failed bill action. Never shows the raw
/// exception.
String billErrorKey(Object error) {
  if (isOfflineError(error)) return 'bf_bill_error_offline';
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return 'bf_bill_error_permission';
      case 'not-found':
        return 'bf_bill_error_not_found';
      case 'aborted':
      case 'failed-precondition':
        return 'bf_bill_error_conflict';
    }
  }
  return 'bf_bill_error_generic';
}

/// History change code -> translation key (unknown codes read "edited").
String historyChangeKey(String change) => switch (change) {
  'created' => 'bf_bill_history_created',
  'renamed' => 'bf_bill_history_renamed',
  'item_price' => 'bf_bill_history_item_price',
  'item_added' => 'bf_bill_history_item_added',
  'item_removed' => 'bf_bill_history_item_removed',
  'person_added' => 'bf_bill_history_person_added',
  'person_removed' => 'bf_bill_history_person_removed',
  'charges' => 'bf_bill_history_charges',
  'split_method' => 'bf_bill_history_split_method',
  'currency' => 'bf_bill_history_currency',
  'marked_paid' => 'bf_bill_history_marked_paid',
  _ => 'bf_bill_history_edited',
};

/// Returns a copy of [participants] with the entry whose id is [id]
/// replaced by `update(entry)`. Throws [StateError] when it is missing.
List<Map<String, dynamic>> updateParticipant(
  List<dynamic> participants,
  String id,
  Map<String, dynamic> Function(Map<String, dynamic> p) update,
) {
  var found = false;
  final out = <Map<String, dynamic>>[];
  for (final raw in participants) {
    if (raw is! Map) continue;
    final p = Map<String, dynamic>.from(raw);
    if (p['id']?.toString() == id) {
      found = true;
      out.add(update(p));
    } else {
      out.add(p);
    }
  }
  if (!found) throw StateError('participant $id not on bill');
  return out;
}

/// [participant] with the submitted payment proof cleared and the share back
/// to unpaid (the host rejected the proof).
Map<String, dynamic> rejectProof(Map<String, dynamic> participant) {
  final out = Map<String, dynamic>.from(participant)
    ..remove('paymentProof')
    ..remove('paymentMethod')
    ..remove('paymentTime');
  out['status'] = 'PENDING';
  out['isPaid'] = false;
  return out;
}
