import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/notifications_screen.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/utils/currency_utils.dart';

class HomeHeader extends StatelessWidget {
  final User? user;
  final double iOwe;
  final double owedToMe;
  final void Function(String name, String? photoUrl) onQrTap;
  final ImageProvider? Function(String?) getAvatarImage;

  const HomeHeader({
    super.key,
    required this.user,
    required this.iOwe,
    required this.owedToMe,
    required this.onQrTap,
    required this.getAvatarImage,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    final currencyCode = context.watch<AppSettingsProvider>().currencyCode;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .snapshots(),
      builder: (context, snap) {
        String name = user?.displayName ?? "User";
        String? photoUrl;

        if (snap.hasData && snap.data!.exists) {
          var data = snap.data!.data() as Map<String, dynamic>;
          name = data['displayName'] ?? name;
          photoUrl = data['photoUrl'];
        }

        String firstName = name.split(' ')[0];

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. TOP CARD: Avatar, Name & Icons
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.1),
                    width: 1,
                  ),
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
                    // Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        image: getAvatarImage(photoUrl) != null
                            ? DecorationImage(
                                image: getAvatarImage(photoUrl)!,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: getAvatarImage(photoUrl) == null
                          ? const Icon(Icons.person_rounded, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    // Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back,",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            firstName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Icons
                    _buildHeaderAction(
                      icon: Icons.qr_code_scanner_rounded,
                      onTap: () => onQrTap(name, photoUrl),
                    ),
                    const SizedBox(width: 10),
                    _buildNotificationAction(context),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 2. SCROLLABLE SUMMARY CARDS: You Owe / Owed to you
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    _buildSquareCard(
                      context: context,
                      title: "You Owe",
                      amount: iOwe,
                      currencyCode: currencyCode,
                      color: Colors.orange,
                      icon: Icons.outbound_rounded,
                    ),
                    const SizedBox(width: 14),
                    _buildSquareCard(
                      context: context,
                      title: "Owed to You",
                      amount: owedToMe,
                      currencyCode: currencyCode,
                      color: Colors.green,
                      icon: Icons.call_received_rounded,
                    ),
                    // Add a third card for "Total Balance" or similar to make scrolling more evident
                    const SizedBox(width: 14),
                    _buildSquareCard(
                      context: context,
                      title: "Net Balance",
                      amount: (owedToMe - iOwe).abs(),
                      currencyCode: currencyCode,
                      color: (owedToMe - iOwe) >= 0 ? Colors.blue : Colors.red,
                      icon: Icons.account_balance_wallet_rounded,
                      isNet: true,
                      netValue: owedToMe - iOwe,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.black87, size: 22),
        ),
      ),
    );
  }

  Widget _buildNotificationAction(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, notifSnap) {
        bool unread = notifSnap.hasData && notifSnap.data!.docs.isNotEmpty;
        return Material(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: unread
                    ? ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.black,
                          BlendMode.srcIn,
                        ),
                        child: Lottie.asset(
                          'assets/animations/bell.json',
                          width: 26,
                          height: 26,
                        ),
                      )
                    : const Icon(
                        Icons.notifications_none_rounded,
                        color: Colors.black87,
                        size: 22,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSquareCard({
    required BuildContext context,
    required String title,
    required double amount,
    required String currencyCode,
    required Color color,
    required IconData icon,
    bool isNet = false,
    double netValue = 0,
  }) {
    return Container(
      width: 150,
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  "${isNet ? (netValue >= 0 ? "+" : "-") : ""}${CurrencyUtils.format(amount.abs(), currencyCode: currencyCode, decimalDigits: 1)}",
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
