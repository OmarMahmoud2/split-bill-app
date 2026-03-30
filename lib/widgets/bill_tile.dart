import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/bill_details_screen.dart';
import 'package:split_bill_app/participant_bill_screen.dart';
import 'package:split_bill_app/scan_receipt_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/utils/currency_utils.dart';

class BillTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String billId;
  final String currentUserId;

  const BillTile({
    super.key,
    required this.data,
    required this.billId,
    required this.currentUserId,
  });

  Future<void> _deleteDraftBill(BuildContext context) async {
    final localImagePath = data['localImagePath']?.toString();

    try {
      if (localImagePath != null && localImagePath.isNotEmpty) {
        final file = File(localImagePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await FirebaseFirestore.instance.collection('bills').doc(billId).delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('bill_deleted').tr(),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'error_saving'.tr(namedArgs: {'error': e.toString()}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteDraft(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('delete_saved_draft').tr(),
        content: Text('delete_saved_draft_message').tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common_cancel').tr(),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('common_delete').tr(),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (shouldDelete == true) {
      await _deleteDraftBill(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool amIHost = data['hostId'] == currentUserId;
    final isDraft = data['status'] == 'UNATTEMPTED';
    String storeName = data['storeName'] ?? "Bill";
    double totalAmount = (data['total'] as num?)?.toDouble() ?? 0.0;

    List parts = data['participants'] ?? [];
    double collected = 0.0;

    for (var p in parts) {
      if (p['status'] == 'PAID') {
        collected += (p['share'] as num? ?? 0.0).toDouble();
      }
    }

    double progress = 0.0;
    if (totalAmount > 0) {
      progress = collected / totalAmount;
    }
    if (progress > 1.0) progress = 1.0;
    int percentage = (progress * 100).toInt();

    Timestamp? ts = data['date'];
    String dateStr = "";
    if (ts != null) {
      dateStr = DateFormat("d MMM, yyyy | hh:mm a").format(ts.toDate());
    }

    // Determine Category for Coloring
    Color tileColor;
    if (isDraft) {
      tileColor = Colors.amber.shade50;
    } else {
      bool isSettled = false;
      if (amIHost) {
        bool anyPending = parts.any(
          (p) => p['status'] == 'PENDING' || p['status'] == 'REVIEW',
        );
        isSettled = !anyPending;
      } else {
        var me = parts.firstWhere(
          (p) => p['id'] == currentUserId,
          orElse: () => null,
        );
        isSettled = (me != null && me['status'] == 'PAID');
      }

      if (isSettled) {
        tileColor = Colors.green.shade50;
      } else {
        DateTime now = DateTime.now();
        DateTime threeDaysAgo = now.subtract(const Duration(days: 3));
        Timestamp? timestamp = data['date'];
        DateTime date = timestamp?.toDate() ?? DateTime(2000);

        if (date.isAfter(threeDaysAgo)) {
          tileColor = Colors.blue.shade50;
        } else {
          tileColor = Colors.red.shade50;
        }
      }
    }

    return GestureDetector(
      onTap: () {
        if (isDraft) {
          // Resume Scan
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScanReceiptScreen(
                billId: billId,
                initialLocalImagePath: data['localImagePath'],
                participants: (data['participants'] as List<dynamic>?)
                    ?.map((e) => e as Map<String, dynamic>)
                    .toList(),
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => amIHost
                  ? BillDetailsScreen(billId: billId, billName: storeName)
                  : ParticipantBillScreen(billId: billId, billName: storeName),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: tileColor,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Lottie.asset(
                  'assets/animations/food.json',
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) =>
                      const Icon(Icons.fastfood, color: Colors.orange),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 24,
                    child: Stack(
                      children: List.generate(
                        parts.length > 3 ? 4 : parts.length,
                        (i) {
                          if (i == 3) {
                            return Positioned(
                              left: i * 16.0,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.grey[300],
                                child: Text(
                                  "+${parts.length - 3}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Positioned(
                            left: i * 16.0,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors
                                  .primaries[i % Colors.primaries.length]
                                  .withValues(alpha: 0.5),
                              child: const Icon(
                                Icons.person,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isDraft)
                  IconButton(
                    onPressed: () => _confirmDeleteDraft(context),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    tooltip: 'common_delete'.tr(),
                  )
                else ...[
                  Text(
                    CurrencyUtils.format(
                      totalAmount,
                      currencyCode:
                          data['currencyCode'] ??
                          Provider.of<AppSettingsProvider>(
                            context,
                            listen: false,
                          ).currencyCode,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                          amIHost ? Colors.green : Colors.blue,
                        ),
                      ),
                      Text(
                        "$percentage%",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
