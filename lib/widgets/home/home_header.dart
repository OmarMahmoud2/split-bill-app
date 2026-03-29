import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import 'package:split_bill_app/notifications_screen.dart';
import 'package:provider/provider.dart';
import 'package:split_bill_app/providers/app_settings_provider.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:easy_localization/easy_localization.dart';

class HomeHeader extends StatelessWidget {
  final User? user;
  final double iOwe;
  final double owedToMe;
  final int completedBillsCount;
  final void Function(String name, String? photoUrl) onQrTap;
  final VoidCallback onCompletedBillsTap;
  final ImageProvider? Function(String?) getAvatarImage;

  const HomeHeader({
    super.key,
    required this.user,
    required this.iOwe,
    required this.owedToMe,
    required this.completedBillsCount,
    required this.onQrTap,
    required this.onCompletedBillsTap,
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
        String name = user?.displayName ?? 'user'.tr();
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
                          Text('welcome_back_2',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ).tr(),
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
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.35,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 10),
                children: [
                  _buildSummaryCard(
                    title: 'you_owe'.tr(),
                    value: CurrencyUtils.format(
                      iOwe,
                      currencyCode: currencyCode,
                      decimalDigits: 1,
                    ),
                    color: Colors.orange,
                    icon: Icons.outbound_rounded,
                  ),
                  _buildSummaryCard(
                    title: 'owed_to_you'.tr(),
                    value: CurrencyUtils.format(
                      owedToMe,
                      currencyCode: currencyCode,
                      decimalDigits: 1,
                    ),
                    color: Colors.green,
                    icon: Icons.call_received_rounded,
                  ),
                  _buildSummaryCard(
                    title: 'net_balance'.tr(),
                    value:
                        '${(owedToMe - iOwe) >= 0 ? "+" : "-"}${CurrencyUtils.format((owedToMe - iOwe).abs(), currencyCode: currencyCode, decimalDigits: 1)}',
                    color: (owedToMe - iOwe) >= 0 ? Colors.blue : Colors.red,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                  _buildSummaryCard(
                    title: 'completed_bills'.tr(),
                    value: '$completedBillsCount',
                    color: Colors.deepPurple,
                    icon: Icons.task_alt_rounded,
                    footerLabel: 'open_history'.tr(),
                    onTap: onCompletedBillsTap,
                  ),
                ],
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

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    String? footerLabel,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    child: Text(
                      value,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (footerLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      footerLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
