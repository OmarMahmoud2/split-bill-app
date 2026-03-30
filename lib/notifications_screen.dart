import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'services/notification_service.dart';
import 'bill_details_screen.dart';
import 'participant_bill_screen.dart';
import 'widgets/empty_state_widget.dart';
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
      r'^Split Bill:\s*(.+)$',
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
    if (title.toLowerCase().startsWith('payment received') && paidMatch != null) {
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('clear_all_notifications').tr(),
        content: Text('this_will_delete_all_your_notification_history').tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common_cancel').tr(),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('clear_all', style: TextStyle(color: Colors.red)).tr(),
          ),
        ],
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('all_notifications_cleared').tr()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        body: Center(child: Text('please_log_in_to_view_notifications').tr()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          const SizedBox(height: 65),
          // Custom Header Card (Matching BillDetails/SplitBill style)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text('notifications',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ).tr(),
                  ),
                  // Mark as Read (Pill)
                  _buildPillAction(
                    icon: Icons.done_all_rounded,
                    color: Colors.blue,
                    onTap: () => NotificationService().markAllAsRead(),
                    tooltip: 'mark_all_read'.tr(),
                  ),
                  const SizedBox(width: 8),
                  // Clear All (Pill)
                  _buildPillAction(
                    icon: Icons.delete_sweep_rounded,
                    color: Colors.red,
                    onTap: _clearAll,
                    tooltip: 'clear_all'.tr(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('notifications')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return LoadingStateWidget(
                    message: 'loading_notifications'.tr(),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.notifications_none_rounded,
                    title: 'no_notifications'.tr(),
                    message: 'your_history_is_clean_for_now_any_alerts_will_appear_here'.tr(),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    final localizedCopy = _localizedNotificationCopy(data);
                    String title = localizedCopy.title;
                    String body = localizedCopy.body;
                    bool read = data['read'] ?? false;
                    Timestamp? ts = data['date'] as Timestamp?;
                    String timeAgo = ts != null
                        ? _formatTimestamp(ts)
                        : 'unknown_time'.tr();

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: read ? 0.02 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: read
                                ? Colors.grey[100]
                                : Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            read
                                ? Icons.notifications_none_rounded
                                : Icons.notifications_active_rounded,
                            color: read
                                ? Colors.grey
                                : Theme.of(context).primaryColor,
                            size: 24,
                          ),
                        ),
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: read
                                ? FontWeight.bold
                                : FontWeight.w900,
                            fontSize: 15,
                            color: read ? Colors.grey[700] : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                body,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  timeAgo,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[400],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: () async {
                          NotificationService().markAsRead(doc.id);
                          final notifData =
                              data['data'] as Map<String, dynamic>?;
                          if (notifData != null &&
                              notifData['billId'] != null) {
                            String billId = notifData['billId'];
                            try {
                              final billDoc = await FirebaseFirestore.instance
                                  .collection('bills')
                                  .doc(billId)
                                  .get();
                              if (billDoc.exists && context.mounted) {
                                final billData = billDoc.data()!;
                                final currentUser =
                                    FirebaseAuth.instance.currentUser;
                                bool amIHost =
                                    billData['hostId'] == currentUser?.uid;
                                String billName =
                                    billData['storeName'] ?? 'bill'.tr();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => amIHost
                                        ? BillDetailsScreen(
                                            billId: billId,
                                            billName: billName,
                                          )
                                        : ParticipantBillScreen(
                                            billId: billId,
                                            billName: billName,
                                          ),
                                  ),
                                );
                              }
                            } catch (e) {
                              debugPrint('Error navigating to bill: $e');
                            }
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
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
