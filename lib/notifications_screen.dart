import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'services/notification_service.dart';
import 'bill_details_screen.dart';
import 'participant_bill_screen.dart';
import 'widgets/empty_state_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final user = FirebaseAuth.instance.currentUser;

  Future<void> _clearAll() async {
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Notifications?"),
        content: const Text("This will delete all your notification history."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear All", style: TextStyle(color: Colors.red)),
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
          const SnackBar(content: Text("All notifications cleared.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please log in to view notifications.")),
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
                  const Expanded(
                    child: Text(
                      "Notifications",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  // Mark as Read (Pill)
                  _buildPillAction(
                    icon: Icons.done_all_rounded,
                    color: Colors.blue,
                    onTap: () => NotificationService().markAllAsRead(),
                    tooltip: "Mark all read",
                  ),
                  const SizedBox(width: 8),
                  // Clear All (Pill)
                  _buildPillAction(
                    icon: Icons.delete_sweep_rounded,
                    color: Colors.red,
                    onTap: _clearAll,
                    tooltip: "Clear all",
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
                  return const LoadingStateWidget(
                    message: "Loading notifications...",
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const EmptyStateWidget(
                    icon: Icons.notifications_none_rounded,
                    title: "No Notifications",
                    message:
                        "Your history is clean for now. Any alerts will appear here.",
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String title = data['title'] ?? 'Notification';
                    String body = data['body'] ?? '';
                    bool read = data['read'] ?? false;
                    Timestamp? ts = data['date'] as Timestamp?;
                    String timeAgo = ts != null
                        ? _formatTimestamp(ts)
                        : 'Unknown time';

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
                                    billData['storeName'] ?? 'Bill';
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
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
