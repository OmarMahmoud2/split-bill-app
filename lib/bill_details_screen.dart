import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/edit_bill_screen.dart';
import 'package:split_bill_app/widgets/bill_details/bill_summary_widget.dart';
import 'package:split_bill_app/widgets/bill_details/participant_tile.dart';
import 'package:split_bill_app/widgets/bill_details/details_modals.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/utils/share_link_utils.dart';
import 'services/notification_service.dart';
import 'package:split_bill_app/widgets/custom_app_header.dart';
import 'package:easy_localization/easy_localization.dart';

class BillDetailsScreen extends StatefulWidget {
  final String billId;
  final String billName;

  const BillDetailsScreen({
    super.key,
    required this.billId,
    required this.billName,
  });

  @override
  State<BillDetailsScreen> createState() => _BillDetailsScreenState();
}

class _BillDetailsScreenState extends State<BillDetailsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // --- ACTIONS ---

  // 1. Enhanced View Proof Dialog
  void _viewProof(
    Map<String, dynamic> participant,
    List<dynamic> allParticipants,
    int index,
  ) {
    String? proofBase64 = participant['paymentProof'];

    if (proofBase64 == null) {
      // Show "No Proof" Dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('no_proof_submitted').tr(),
          content: Text('this_participant_marked_their_share_as_paid_but_didn_t_upload_a_screenshot_do_you_want_to_approve_it',
          ).tr(),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common_cancel').tr(),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsPaid(allParticipants, index, forcePaid: true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text('approve_payment').tr(),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.memory(
                  base64Decode(proofBase64.split(',').last),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('common_cancel',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ).tr(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _markAsPaid(allParticipants, index, forcePaid: true);
                        Navigator.pop(context);
                      },
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text('approve').tr(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Mark as Paid (Toggle or Force)
  Future<void> _markAsPaid(
    List<dynamic> participants,
    int index, {
    bool forcePaid = false,
  }) async {
    String currentStatus = participants[index]['status'] ?? 'PENDING';
    String newStatus = forcePaid
        ? 'PAID'
        : (currentStatus == 'PAID' ? 'PENDING' : 'PAID');

    participants[index]['status'] = newStatus;
    participants[index]['isPaid'] = newStatus == 'PAID';

    await FirebaseFirestore.instance
        .collection('bills')
        .doc(widget.billId)
        .update({'participants': participants});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'marked_as_status'.tr(namedArgs: {'status': newStatus}),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );

      // Send Notification to Participant if marked as PAID
      if (newStatus == 'PAID') {
        final participant = participants[index];
        final String? participantUid = participant['id'];
        if (participantUid != null && !participantUid.startsWith('guest_')) {
          _sendPaymentAcceptedNotification(
            participantUid,
            participant['name'] ?? 'Friend',
          );
        }
      }
    }
  }

  Future<void> _sendPaymentAcceptedNotification(
    String participantUid,
    String name,
  ) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(participantUid)
          .get();
      if (!userDoc.exists) return;

      String? token = userDoc.get('fcmToken');
      if (token != null && token.isNotEmpty) {
        await NotificationService().sendNotification(
          targetToken: token,
          targetUid: participantUid,
          title: 'payment_accepted'.tr(),
          body:
              "Your payment for \"${widget.billName}\" has been approved by the host.",
          data: {
            'billId': widget.billId,
            'type': 'payment_accepted',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        );
      }
    } catch (e) {
      debugPrint("Error sending approval notification: $e");
    }
  }

  // 3. Confirm Reminder Dialog
  void _confirmReminder(
    String targetUid,
    String name,
    double amount,
    String currencyCode,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Row(
          children: [
            Icon(
              Icons.notifications_active_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text('reminder').tr(),
          ],
        ),
        content: Text(
          "This will send a notification to \"$name\" about their remaining ${CurrencyUtils.format(amount, currencyCode: currencyCode)} share.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common_cancel', style: TextStyle(color: Colors.grey)).tr(),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendReminder(targetUid, name, amount, currencyCode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('send_now').tr(),
          ),
        ],
      ),
    );
  }

  // 4. Send Reminder (Smart Notification)
  Future<void> _sendReminder(
    String targetUid,
    String name,
    double amount,
    String currencyCode,
  ) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .get();
      if (!userDoc.exists) return;

      String? token = userDoc.get('fcmToken');
      if (token != null && token.isNotEmpty) {
        await NotificationService().sendNotification(
          targetToken: token,
          targetUid: targetUid,
          title: 'reminder_title'.tr(
            namedArgs: {'bill_name': widget.billName},
          ),
          body: 'reminder_body'.tr(
            namedArgs: {
              'amount': CurrencyUtils.format(
                amount,
                currencyCode: currencyCode,
              ),
            },
          ),
          data: {'billId': widget.billId},
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'reminder_sent_to'.tr(namedArgs: {'name': name}),
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.blue[800],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error sending reminder: $e");
    }
  }

  // 5. Delete Bill Confirmation
  Future<void> _confirmDelete() async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: Text('delete_bill',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ).tr(),
        content: Text('this_action_is_irreversible_all_participants_will_lose_access_to_this_bill_data',
        ).tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common_cancel').tr(),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('delete_permanently').tr(),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('bills')
          .doc(widget.billId)
          .delete();
      if (mounted) {
        Navigator.pop(context); // Go back to Home
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('bill_deleted').tr(),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 6. Action Sheet for Participant
  void _showParticipantActions(
    Map<String, dynamic> participant,
    List<dynamic> allParticipants,
    int index,
    Map<String, dynamic> billData,
  ) {
    final bool isAppUser =
        participant['id'] != null && !participant['id'].startsWith('guest_');
    final double share = (participant['share'] as num? ?? 0.0).toDouble();
    final String status = participant['status'] ?? 'PENDING';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.only(bottom: 24),
            ),
            Text(
              participant['name'] ?? "Participant",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionItem(
              icon: status == 'PAID'
                  ? Icons.undo_rounded
                  : Icons.check_circle_rounded,
              color: status == 'PAID' ? Colors.orange : Colors.green,
              label: status == 'PAID' ? "Mark as Unpaid" : "Mark as Paid",
              onTap: () {
                Navigator.pop(context);
                _markAsPaid(allParticipants, index);
              },
            ),
            if (isAppUser)
              _buildActionItem(
                icon: Icons.notifications_active_rounded,
                color: Colors.blue,
                label: "Send Reminder",
                onTap: () {
                  Navigator.pop(context);
                  _confirmReminder(
                    participant['id'],
                    participant['name'],
                    share,
                    (billData['currencyCode'] ??
                            billData['currency_code'] ??
                            'USD')
                        .toString(),
                  );
                },
              )
            else
              _buildActionItem(
                icon: Icons.share_rounded,
                color: Colors.blue,
                label: "Share via Link",
                onTap: () {
                  Navigator.pop(context);
                  _shareUserLink(
                    context,
                    participant['name'],
                    share,
                    participant['id'],
                    (billData['currencyCode'] ??
                            billData['currency_code'] ??
                            'USD')
                        .toString(),
                  );
                },
              ),
            _buildActionItem(
              icon: Icons.receipt_long_rounded,
              color: Colors.deepPurple,
              label: "Show Personal Breakdown",
              onTap: () {
                Navigator.pop(context);
                BillDetailsModals.showUserShareDetails(
                  context,
                  participant,
                  billData,
                );
              },
            ),
            if (participant['paymentProof'] != null)
              _buildActionItem(
                icon: Icons.image_rounded,
                color: Colors.orange[800]!,
                label: "Review Proof",
                onTap: () {
                  Navigator.pop(context);
                  _viewProof(participant, allParticipants, index);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }

  // 7. FAB Actions Sheet
  void _showManagementSheet(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.only(bottom: 24),
            ),
            Text('management_actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ).tr(),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.blue,
                  size: 22,
                ),
              ),
              title: Text('edit_bill_info',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ).tr(),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        EditBillScreen(billId: widget.billId, billData: data),
                  ),
                );
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                  size: 22,
                ),
              ),
              title: Text('delete_entire_bill',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red,
                ),
              ).tr(),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete();
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 1. Add 'context' as a parameter
  Future<void> _shareBillWithLogo(BuildContext context) async {
    // 2. Calculate the anchor point for the iPad popover
    final box = context.findRenderObject() as RenderBox?;
    final Rect? sharePosition = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;

    final String url = ShareLinkUtils.buildBillShareUrl(widget.billId);
    final String message =
        "💸 Hey! Here is the split bill for \"${widget.billName}\".\n\n"
        "Tap the link to see your share and settle up:\n$url\n\n"
        "Powered by SplitBill App 🚀";

    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: "Split Bill: ${widget.billName}",
        sharePositionOrigin: sharePosition,
      ),
    );
  }

  Future<void> _shareUserLink(
    BuildContext context,
    String name,
    double amount,
    String? participantId,
    String currencyCode,
  ) async {
    // 2. Calculate the anchor point
    final box = context.findRenderObject() as RenderBox?;
    final Rect? sharePosition = box != null
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;

    // Use the passed participant ID
    String pid = participantId ?? '';

    final String url = ShareLinkUtils.buildBillShareUrl(
      widget.billId,
      participantId: pid,
    );
    final String message =
        "💸 Hey $name! Your share for \"${widget.billName}\" is ${CurrencyUtils.format(amount, currencyCode: currencyCode)}.\n\n"
        "Check your items and pay here:\n$url\n\n"
        "Powered by SplitBill App 🚀";

    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: "Your share for ${widget.billName}",
        sharePositionOrigin: sharePosition,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bills')
          .doc(widget.billId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: LoadingStateWidget(message: 'loading_bill_details'.tr()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(body: Center(child: Text('bill_not_found').tr()));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        List<dynamic> participantsData = data['participants'];
        double total = (data['total'] as num).toDouble();
        bool amIHost = data['hostId'] == user?.uid;
        final currencyCode =
            (data['currencyCode'] ?? data['currency_code'] ?? 'USD')
                .toString();

        // PRECISION PERCENTAGE FIX:
        // Calculate percentages based on sum of shares if total is mismatching
        double sumOfShares = participantsData.fold(
          0.0,
          (runningTotal, p) =>
              runningTotal + (p['share'] as num? ?? 0).toDouble(),
        );
        final double calculationBase = sumOfShares > 0 ? sumOfShares : total;

        double collected = 0.0;
        for (var p in participantsData) {
          if (p['status'] == 'PAID') {
            collected += (p['share'] as num? ?? 0.0).toDouble();
          }
        }

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: CustomAppHeader(
            title: widget.billName,
            trailing: IconButton(
              onPressed: () => _shareBillWithLogo(context),
              icon: Icon(
                Icons.ios_share_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 120, top: 8),
                  children: [
                    BillSummaryWidget(
                      total: total,
                      collected: collected,
                      title: widget.billName,
                      date: data['date'],
                      hostName: data['hostName'],
                      currencyCode: currencyCode,
                    ),

                    // Refined Bill Details Tile
                    _buildDetailsActionTile(data),

                    Padding(
                      padding: EdgeInsets.fromLTRB(20, 32, 20, 12),
                      child: Text('participants',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey,
                          letterSpacing: 1.5,
                        ),
                      ).tr(),
                    ),

                    ...participantsData.asMap().entries.map((entry) {
                      int index = entry.key;
                      var p = entry.value;
                      bool isHostParticipant = p['id'] == data['hostId'];

                      return ParticipantTile(
                        participant: p,
                        totalBill:
                            calculationBase, // Use sumOfShares for 100% sum
                        isHost: isHostParticipant,
                        currencyCode: currencyCode,
                        onTap: () => _showParticipantActions(
                          p,
                          participantsData,
                          index,
                          data,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: amIHost
              ? Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 12),
                  child: FloatingActionButton(
                    onPressed: () => _showManagementSheet(data),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    elevation: 10,
                    child: const Icon(
                      CupertinoIcons.settings,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildDetailsActionTile(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => BillDetailsModals.showFullBillDetails(context, data),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Lottie.asset(
                    'assets/animations/food.json',
                    repeat: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('full_bill_details',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ).tr(),
                      Text('items_and_charges_breakdown',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ).tr(),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
