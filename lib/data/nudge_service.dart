/// Friendly payment reminders ("Nudge"), capped at one per person per week.
///
/// The backend (`POST notifications/send/`) only delivers a push when the
/// caller and the target share the bill named by `billId`; there is no
/// group-level payload. Group and friend nudges therefore send the most
/// recent open bill the two people share ([pickNudgeBill]). When they share
/// none (a balance made only of Quick IOUs), the caller falls back to the
/// share sheet.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/services/notification_service.dart';

enum NudgeResult {
  sent,

  /// Already nudged within [NudgeService.cooldown].
  tooSoon,

  /// No bill both people are on, so the backend can't deliver it.
  noSharedBill,

  /// The backend refused or the network failed.
  failed,
}

typedef NudgeSender =
    Future<bool> Function({
      required String targetUid,
      required String billId,
      required String title,
      required String body,
      required Map<String, String> args,
    });

/// The newest open bill that [me] and [other] are both on, where one of
/// them still owes the other.
BillRecord? pickNudgeBill(Iterable<BillRecord> bills, String me, String other) {
  BillRecord? best;
  for (final b in bills) {
    if (!b.isOpen) continue;
    final related =
        (b.hostId == me && b.owedBy(other) > 0) ||
        (b.hostId == other && b.owedBy(me) > 0) ||
        (b.share(me) != null &&
            b.share(other) != null &&
            b.hostId != me &&
            b.hostId != other);
    if (!related) continue;
    if (best == null ||
        (b.date ?? DateTime(0)).isAfter(best.date ?? DateTime(0))) {
      best = b;
    }
  }
  return best;
}

class NudgeService {
  NudgeService({
    Future<SharedPreferences> Function()? prefs,
    NudgeSender? sender,
    DateTime Function()? clock,
  }) : _prefs = prefs ?? SharedPreferences.getInstance,
       _sender = sender ?? _defaultSender,
       _clock = clock ?? DateTime.now;

  static const Duration cooldown = Duration(days: 7);
  static const String _prefix = 'nudge_last_';

  final Future<SharedPreferences> Function() _prefs;
  final NudgeSender _sender;
  final DateTime Function() _clock;

  static Future<bool> _defaultSender({
    required String targetUid,
    required String billId,
    required String title,
    required String body,
    required Map<String, String> args,
  }) => NotificationService().sendNotification(
    targetUid: targetUid,
    billId: billId,
    title: title,
    body: body,
    data: {'billId': billId, 'type': 'nudge'},
    historyTitleKey: 'nudge_push_title',
    historyBodyKey: 'nudge_push_body',
    historyTitleArgs: args,
    historyBodyArgs: args,
  );

  Future<DateTime?> lastNudgedAt(String targetId) async {
    final p = await _prefs();
    final ms = p.getInt('$_prefix$targetId');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// When [targetId] can be nudged again (null: now).
  Future<DateTime?> nextAllowedAt(String targetId) async {
    final last = await lastNudgedAt(targetId);
    if (last == null) return null;
    final next = last.add(cooldown);
    return next.isAfter(_clock()) ? next : null;
  }

  /// Sends a nudge about [bill] unless [targetId] was nudged this week.
  /// [title]/[body] are in the sender's language; the inbox copy uses the
  /// `nudge_push_*` keys with [args] so it reads in the recipient's.
  Future<NudgeResult> nudge({
    required String targetId,
    required BillRecord? bill,
    required String title,
    required String body,
    Map<String, String> args = const {},
  }) async {
    if (await nextAllowedAt(targetId) != null) return NudgeResult.tooSoon;
    if (bill == null) return NudgeResult.noSharedBill;
    final ok = await _sender(
      targetUid: targetId,
      billId: bill.id,
      title: title,
      body: body,
      args: args,
    );
    if (!ok) return NudgeResult.failed;
    final p = await _prefs();
    await p.setInt('$_prefix$targetId', _clock().millisecondsSinceEpoch);
    return NudgeResult.sent;
  }
}
