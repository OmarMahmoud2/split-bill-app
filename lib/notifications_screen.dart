import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:split_bill_app/widgets/layout/app_scaffold.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'services/notification_service.dart';
import 'bill_details_screen.dart';
import 'participant_bill_screen.dart';
import 'package:easy_localization/easy_localization.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  ({String title, String body}) _localizedNotificationCopy(
    Map<String, dynamic> data,
  ) {
    final rawTitle = (data['title'] as String?) ?? 'notification'.tr();
    final rawBody = (data['body'] as String?) ?? '';
    final titleKey = data['titleKey'] as String?;
    final bodyKey = data['bodyKey'] as String?;
    final titleArgs = Map<String, String>.from(
      (data['titleArgs'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
    );
    final bodyArgs = Map<String, String>.from(
      (data['bodyArgs'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          const {},
    );

    if ((titleKey == null || titleKey.isEmpty) &&
        (bodyKey == null || bodyKey.isEmpty)) {
      final legacyCopy = _legacyLocalizedNotificationCopy(rawTitle, rawBody);
      if (legacyCopy != null) {
        return legacyCopy;
      }
    }

    final title = titleKey != null && titleKey.isNotEmpty
        ? titleKey.tr(namedArgs: titleArgs)
        : rawTitle;
    final body = bodyKey != null && bodyKey.isNotEmpty
        ? bodyKey.tr(namedArgs: bodyArgs)
        : rawBody;

    return (title: title, body: body);
  }

  ({String title, String body})? _legacyLocalizedNotificationCopy(
    String title,
    String body,
  ) {
    final splitMatch = RegExp(
      r'^(?:Split Bill|Evens):\s*(.+)$',
      caseSensitive: false,
    ).firstMatch(title);
    final splitBodyMatch = RegExp(
      r'^Your share is\s+(.+?)\.\s+Tap to view details\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (splitMatch != null && splitBodyMatch != null) {
      return (
        title: 'split_bill_notification_title'.tr(
          namedArgs: {'store': splitMatch.group(1)!},
        ),
        body: 'split_bill_notification_body'.tr(
          namedArgs: {'amount': splitBodyMatch.group(1)!},
        ),
      );
    }

    final paidMatch = RegExp(
      r'^(.*?) paid (.+?)(?: via (.*?))? for (.+)\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (title.toLowerCase().startsWith('payment received') &&
        paidMatch != null) {
      final methodName = paidMatch.group(3);
      return (
        title: 'payment_received'.tr(),
        body: 'payment_received_body'.tr(
          namedArgs: {
            'payer': paidMatch.group(1)!,
            'amount': paidMatch.group(2)!,
            'store': paidMatch.group(4)!,
            'method_suffix': methodName == null || methodName.isEmpty
                ? ''
                : 'notification_via_method'.tr(
                    namedArgs: {'method': methodName},
                  ),
          },
        ),
      );
    }

    final markedMatch = RegExp(
      r'^(.*?) marked (.+?) as paid \(No Proof\)\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (title.toLowerCase().startsWith('payment marked as sent') &&
        markedMatch != null) {
      return (
        title: 'payment_marked_as_sent'.tr(),
        body: 'payment_marked_as_sent_body'.tr(
          namedArgs: {
            'payer': markedMatch.group(1)!,
            'amount': markedMatch.group(2)!,
          },
        ),
      );
    }

    final acceptedMatch = RegExp(
      r'^Your payment for "(.+)" has been approved by the host\.$',
      caseSensitive: false,
    ).firstMatch(body);
    if (title.toLowerCase().startsWith('payment accepted') &&
        acceptedMatch != null) {
      return (
        title: 'payment_accepted'.tr(),
        body: 'payment_accepted_body'.tr(
          namedArgs: {'bill_name': acceptedMatch.group(1)!},
        ),
      );
    }

    return null;
  }

  Future<void> _clearAll() async {
    if (user == null) return;

    final confirm = await showAppDialog(
      context,
      icon: AppIcons.delete,
      title: 'clear_all_notifications'.tr(),
      message: 'this_will_delete_all_your_notification_history'.tr(),
      confirmLabel: 'clear_all'.tr(),
      destructive: true,
    );

    if (confirm == true) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('notifications')
          .get();

      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }

      if (mounted) {
        AppToast.show(
          context,
          message: 'all_notifications_cleared'.tr(),
          type: AppToastType.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (user == null) {
      return AppScaffold(
        body: Center(child: Text('please_log_in_to_view_notifications').tr()),
      );
    }
    return AppScaffold(
      body: AdaptiveBody(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LedgerTopBar(
                title: 'notifications'.tr(),
                actions: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await NotificationService().markAllAsRead();
                        AppHaptics.selection();
                      } catch (_) {
                        if (context.mounted) {
                          AppToast.show(
                            context,
                            message: 'notifications_action_failed'.tr(),
                            type: AppToastType.error,
                          );
                        }
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: p.accent),
                    child: Text('mark_all_read'.tr()),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'groups_more'.tr(),
                    icon: Icon(AppIcons.more, color: p.textPrimary),
                    onSelected: (_) => _clearAll(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'clear',
                        child: Text('clear_all'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('notifications')
                      .orderBy('date', descending: true)
                      .limit(100)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorState(
                        message: 'notifications_load_failed'.tr(),
                        onRetry: () => setState(() {}),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: SkeletonShimmer(
                          child: Column(
                            children: [
                              SkeletonCard(),
                              SizedBox(height: 10),
                              SkeletonCard(),
                              SizedBox(height: 10),
                              SkeletonCard(),
                            ],
                          ),
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? const [];
                    if (docs.isEmpty) {
                      return EmptyState(
                        icon: AppIcons.bell,
                        title: 'no_notifications'.tr(),
                        message:
                            'your_history_is_clean_for_now_any_alerts_will_appear_here'
                                .tr(),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        16,
                        20,
                        24,
                      ),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final copy = _localizedNotificationCopy(data);
                        final read = data['read'] == true;
                        final ts = data['date'] as Timestamp?;
                        final when = ts != null
                            ? _formatTimestamp(ts)
                            : 'unknown_time'.tr();
                        final payload = data['data'] as Map<String, dynamic>?;
                        final isReminder =
                            payload?['type'] == 'nudge' ||
                            (data['titleKey'] as String?)?.startsWith(
                                  'nudge_',
                                ) ==
                                true;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: StaggeredEntrance(
                            index: index,
                            child: NotificationCard(
                              title: copy.title,
                              body: copy.body,
                              when: when,
                              read: read,
                              reminder: isReminder,
                              senderId: payload?['senderId']?.toString(),
                              senderName: payload?['senderName']?.toString(),
                              senderPhotoUrl: payload?['senderPhotoUrl']
                                  ?.toString(),
                              onTap: () => _open(doc.id, payload),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(String id, Map<String, dynamic>? payload) async {
    NotificationService().markAsRead(id).catchError((_) {});
    final billId = payload?['billId']?.toString();
    if (billId == null) return;
    try {
      final billDoc = await FirebaseFirestore.instance
          .collection('bills')
          .doc(billId)
          .get();
      if (!mounted) return;
      if (!billDoc.exists) {
        AppToast.show(
          context,
          message: 'notifications_bill_gone'.tr(),
          type: AppToastType.info,
        );
        return;
      }
      final billData = billDoc.data()!;
      final amIHost =
          billData['hostId'] == FirebaseAuth.instance.currentUser?.uid;
      final billName = billData['storeName'] ?? 'bill'.tr();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => amIHost
              ? BillDetailsScreen(billId: billId, billName: billName)
              : ParticipantBillScreen(billId: billId, billName: billName),
        ),
      );
    } catch (_) {
      if (mounted) {
        AppToast.show(
          context,
          message: 'notifications_open_failed'.tr(),
          type: AppToastType.error,
        );
      }
    }
  }

  String _formatTimestamp(Timestamp ts) {
    final now = DateTime.now();
    final date = ts.toDate();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'just_now'.tr();
    if (diff.inMinutes < 60) {
      return 'minutes_ago'.tr(namedArgs: {'count': diff.inMinutes.toString()});
    }
    if (diff.inHours < 24) {
      return 'hours_ago'.tr(namedArgs: {'count': diff.inHours.toString()});
    }
    if (diff.inDays < 7) {
      return 'days_ago'.tr(namedArgs: {'count': diff.inDays.toString()});
    }
    return DateFormat.yMd(context.locale.toLanguageTag()).format(date);
  }
}

/// One inbox entry: unread entries sit on the surface with a colored dot
/// (amber for reminders, teal otherwise); read ones blend into the canvas.
class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.title,
    required this.body,
    required this.when,
    required this.read,
    this.reminder = false,
    this.onTap,
    this.senderId,
    this.senderName,
    this.senderPhotoUrl,
  });

  /// The person behind the notification, when the payload names one.
  final String? senderId;
  final String? senderName;
  final String? senderPhotoUrl;

  final String title;
  final String body;
  final String when;
  final bool read;
  final bool reminder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dot = read ? null : (reminder ? p.coral : p.accent);
    final hasPerson =
        (senderName ?? '').isNotEmpty || (senderId ?? '').isNotEmpty;
    final leading = hasPerson
        ? LedgerAvatar(
            id: senderId ?? '',
            name: senderName ?? '',
            photoUrl: senderPhotoUrl,
          )
        : Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: reminder ? p.coralSoft : p.accentSoft,
              borderRadius: AppRadii.rowRadius,
            ),
            child: Icon(
              AppIcons.bell,
              size: 20,
              color: reminder ? p.coral : p.accent,
            ),
          );
    return Semantics(
      label: read ? null : 'notifications_unread'.tr(),
      child: LedgerCard(
        onTap: onTap,
        color: read ? p.background : p.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: p.textPrimary,
                      fontSize: 15,
                      fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    when,
                    style: AppTypography.caption.copyWith(
                      color: p.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (dot != null)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsetsDirectional.only(start: 8, top: 6),
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
          ],
        ),
      ),
    );
  }
}
