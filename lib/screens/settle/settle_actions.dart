/// Actions shared by Settle up, Friend detail and Home: record a payment
/// (with the right success moment), and nudge someone who owes you.
library;

import 'package:split_bill_app/services/analytics_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/data/nudge_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/share_link_utils.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// App-wide nudge service; tests swap it.
NudgeService nudgeService = NudgeService();

/// Saves [payment] and shows the matching feedback.
///
/// [settlesGroup]: true when this was the last open payment of a group, so
/// the whole-group moment plays (RollToZero from [myBalanceBefore] + quiet
/// confetti). Otherwise a success toast. Returns whether it was saved.
Future<bool> recordPaymentWithFeedback(
  BuildContext context, {
  required PaymentRecord payment,
  bool settlesGroup = false,
  String? groupName,
  int myBalanceBefore = 0,
  int billCount = 0,
  int peopleCount = 0,
  int paymentCount = 0,
  VoidCallback? onArchive,
}) async {
  final repo = LedgerRepository.instance;
  try {
    await repo.recordPayment(payment);
  } catch (_) {
    if (!context.mounted) return false;
    AppToast.show(
      context,
      message: 'settle_record_failed'.tr(),
      type: AppToastType.error,
      actionLabel: 'feedback_try_again'.tr(),
      onAction: () => recordPaymentWithFeedback(
        context,
        payment: payment,
        settlesGroup: settlesGroup,
        groupName: groupName,
        myBalanceBefore: myBalanceBefore,
        billCount: billCount,
        peopleCount: peopleCount,
        paymentCount: paymentCount,
        onArchive: onArchive,
      ),
    );
    return false;
  }
  AnalyticsService.instance.settleUpDone(paymentCount < 1 ? 1 : paymentCount);
  if (!context.mounted) return true;
  final amount = moneyLabel(context, payment.amountMinor, payment.currency);
  if (settlesGroup) {
    final nav = Navigator.of(context);
    await SuccessScreen.show<void>(
      context,
      title: 'settle_everyone_square'.tr(),
      caption: groupName == null
          ? null
          : 'settle_group_balance'.tr(namedArgs: {'group': groupName}),
      message: 'settle_group_recap'.tr(
        namedArgs: {
          'bills': '$billCount',
          'people': '$peopleCount',
          'payments': '$paymentCount',
        },
      ),
      rollFromMinor: myBalanceBefore == 0 ? null : myBalanceBefore,
      amountMinor: 0,
      currency: payment.currency,
      amountSign: MoneySign.always,
      amountTone: MoneyTone.auto,
      celebrate: true,
      primaryLabel: 'done'.tr(),
      onPrimary: nav.pop,
      secondaryLabel: 'settle_share_recap'.tr(),
      onSecondary: () {
        SharePlus.instance.share(
          ShareParams(
            text: 'settle_recap_share_text'.tr(
              namedArgs: {
                'group': groupName ?? '',
                'bills': '$billCount',
                'people': '$peopleCount',
              },
            ),
          ),
        );
      },
      tertiaryLabel: onArchive == null ? null : 'settle_archive_group'.tr(),
      onTertiary: onArchive == null
          ? null
          : () {
              nav.pop();
              onArchive.call();
            },
    );
    return true;
  }
  final me = LedgerMe.current()?.uid;
  final message = payment.from == me
      ? 'settle_you_paid_toast'.tr(
          namedArgs: {'name': payment.toName ?? '', 'amount': amount},
        )
      : 'settle_marked_paid_toast'.tr(
          namedArgs: {'name': payment.fromName ?? '', 'amount': amount},
        );
  AppToast.show(context, message: message, type: AppToastType.success);
  return true;
}

/// Nudges [targetId] about what they owe, at most once a week.
///
/// Uses the newest open bill the two share (the backend needs a bill id).
/// Without one (e.g. only Quick IOUs), opens the share sheet with the same
/// friendly text instead.
Future<void> nudgePerson(
  BuildContext context, {
  required String targetId,
  required String targetName,
  required int amountMinor,
  required String currency,
  required Iterable<BillRecord> bills,
  String? contextLabel,
}) async {
  final me = LedgerMe.current();
  if (me == null) return;
  AppHaptics.light();
  final amount = moneyLabel(context, amountMinor, currency);
  final where = contextLabel ?? '';
  final args = {'name': me.name, 'amount': amount, 'context': where};
  final title = 'nudge_push_title'.tr(namedArgs: args);
  final body = 'nudge_push_body'.tr(namedArgs: args);
  final bill = pickNudgeBill(bills, me.uid, targetId);
  // Guests have no account to push to (the backend answers no_token): send
  // them their own pay link instead.
  if (targetId.startsWith('guest_') && bill != null) {
    await SharePlus.instance.share(
      ShareParams(
        text: 'bf_share_person_text'.tr(
          namedArgs: {
            'name': targetName,
            'amount': amount,
            'store': bill.title,
            'link': ShareLinkUtils.buildBillShareUrl(
              bill.id,
              participantId: targetId,
            ),
          },
        ),
      ),
    );
    return;
  }
  final result = await nudgeService.nudge(
    targetId: targetId,
    bill: bill,
    title: title,
    body: body,
    args: args,
  );
  if (!context.mounted) return;
  switch (result) {
    case NudgeResult.sent:
      AppToast.show(
        context,
        message: 'nudge_sent'.tr(namedArgs: {'name': targetName}),
        type: AppToastType.success,
      );
    case NudgeResult.tooSoon:
      final next = await nudgeService.nextAllowedAt(targetId);
      if (!context.mounted) return;
      final day = next == null
          ? ''
          : DateFormat.MMMEd(localeTag(context)).format(next);
      AppToast.show(
        context,
        message: 'nudge_too_soon'.tr(
          namedArgs: {'name': targetName, 'date': day},
        ),
        type: AppToastType.info,
      );
    case NudgeResult.noSharedBill:
      await SharePlus.instance.share(
        ShareParams(
          text: 'nudge_share_text'.tr(
            namedArgs: {'name': targetName, 'amount': amount, 'context': where},
          ),
        ),
      );
    case NudgeResult.failed:
      AppToast.show(
        context,
        message: 'nudge_failed'.tr(),
        type: AppToastType.error,
        actionLabel: 'feedback_try_again'.tr(),
        onAction: () => nudgePerson(
          context,
          targetId: targetId,
          targetName: targetName,
          amountMinor: amountMinor,
          currency: currency,
          bills: bills,
          contextLabel: contextLabel,
        ),
      );
  }
}

/// Asks before marking a payment as received in cash.
Future<bool> confirmCashPayment(
  BuildContext context, {
  required String fromName,
  required String toName,
  required String amount,
  bool fromIsMe = false,
  bool toIsMe = false,
}) async {
  // "You" takes its own verb form in many languages.
  final key = fromIsMe
      ? 'settle_record_cash_body_you_paid'
      : toIsMe
      ? 'settle_record_cash_body_paid_you'
      : 'settle_record_cash_body';
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('settle_record_cash_title'.tr()),
      content: Text(
        key.tr(namedArgs: {'from': fromName, 'to': toName, 'amount': amount}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('common_cancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('settle_mark_paid'.tr()),
        ),
      ],
    ),
  );
  return ok == true;
}
