import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_menu_widgets.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'widgets/send_notification_sheet.dart';

class UserAdminDetailScreen extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const UserAdminDetailScreen({
    super.key,
    required this.uid,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final String name = (userData['displayName'] as String?) ?? 'unknown_user'.tr();
    final isPremium = userData['isPremium'] ?? false;
    final isAdmin = userData['isAdmin'] ?? false;
    final int points = userData['points'] ?? 0;

    // Retrieve and process Avatar Image
    final String? photoUrl = userData['photoUrl'] as String?;
    ImageProvider? imageProvider;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image')) {
        try {
          final base64String = photoUrl.split(',').last;
          imageProvider = MemoryImage(base64Decode(base64String));
        } catch (_) {}
      } else {
        imageProvider = NetworkImage(photoUrl);
      }
    }

    // Process Country Name
    final String? isoCode = userData['isoCode'] as String?;
    String countryName = 'unknown'.tr();
    if (isoCode != null) {
      try {
        final country = countries.firstWhere((c) => c.code == isoCode);
        countryName = country.name;
      } catch (_) {
        countryName = isoCode;
      }
    }

    // Process Platform Info
    final String? loginPlatform = userData['loginPlatform'] as String?;
    String platformDisplay = 'unknown'.tr();
    if (loginPlatform != null) {
      if (loginPlatform.toLowerCase() == 'ios') {
        platformDisplay = 'Apple / iOS';
      } else if (loginPlatform.toLowerCase() == 'android') {
        platformDisplay = 'Android';
      } else {
        platformDisplay = loginPlatform;
      }
    } else {
      final email = userData['email'] as String? ?? '';
      if (email.endsWith('@privaterelay.appleid.com')) {
        platformDisplay = 'Apple (Inferred)';
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_rounded, color: Colors.blue),
            onPressed: () => _sendNotification(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // User Profile Summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.blue[50],
                          backgroundImage: imageProvider,
                          child: imageProvider == null
                              ? Text(
                                  name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.blue[700],
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isAdmin)
                              _buildBadge(
                                'admin'.tr(),
                                Colors.blueGrey[700]!,
                                Colors.blueGrey[50]!,
                              ),
                            if (isPremium) ...[
                              if (isAdmin) const SizedBox(width: 8),
                              _buildBadge(
                                'premium_crown'.tr(),
                                Colors.amber[800]!,
                                Colors.amber[50]!,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow(
                          Icons.mail_outline_rounded,
                          'email'.tr(),
                          userData['email'] ?? 'not_provided'.tr(),
                        ),
                        _buildDetailRow(
                          Icons.phone_iphone_rounded,
                          'phone'.tr(),
                          userData['phoneNumber'] ?? 'not_provided'.tr(),
                        ),
                        if (platformDisplay != 'unknown'.tr())
                          _buildDetailRow(
                            Icons.devices_rounded,
                            'platform'.tr(),
                            platformDisplay,
                          ),
                        _buildDetailRow(
                          Icons.public_rounded,
                          'country'.tr(),
                          countryName,
                        ),
                        _buildDetailRow(
                          Icons.stars_rounded,
                          'points'.tr(),
                          points.toString(),
                        ),
                        _buildDetailRow(
                          Icons.calendar_today_rounded,
                          'registered'.tr(),
                          userData['createdAt'] != null
                              ? DateFormat.yMMMd().format(
                                  (userData['createdAt'] as Timestamp).toDate(),
                                )
                              : 'unknown'.tr(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  ProfileSectionTitle(title: 'user_bills_summary'.tr()),
                ],
              ),
            ),
          ),
          
          // User Bills List
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bills')
                .where('participants_uids', arrayContains: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text('error_loading_bills'.tr()),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text('no_bills_found'.tr()),
                    ),
                  ),
                );
              }

              final bills = snapshot.data!.docs;
              // Sort locally to bypass Firebase composite index requirement
              bills.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>?;
                final bData = b.data() as Map<String, dynamic>?;
                final dateA = aData?['date'] as Timestamp?;
                final dateB = bData?['date'] as Timestamp?;
                if (dateA == null && dateB == null) return 0;
                if (dateA == null) return 1;
                if (dateB == null) return -1;
                return dateB.compareTo(dateA);
              });

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final billDoc = bills[index];
                      final billData = billDoc.data() as Map<String, dynamic>;
                      final storeName = billData['storeName'] ?? 'unknown_store'.tr();
                      final total = (billData['total'] as num? ?? 0.0).toDouble();
                      final currency = billData['currencyCode'] ?? 'USD';
                      final date = (billData['date'] as Timestamp).toDate();
                      final status = billData['status'] ?? 'PENDING';

                      return ProfileCoolTile(
                        icon: Icons.receipt_long_rounded,
                        title: storeName,
                        subtitle: '${CurrencyUtils.format(total, currencyCode: currency)} • ${DateFormat.yMMMd().format(date)}',
                        color: status == 'PAID' ? Colors.green : Colors.orange,
                        onTap: () {
                          _showBillSummarySheet(context, billData);
                        },
                      );
                    },
                    childCount: bills.length,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  void _sendNotification(BuildContext context) {
    PremiumBottomSheet.show(
      context: context,
      child: SendNotificationSheet(
        targetUid: uid,
        targetToken: userData['fcmToken'],
        userName: userData['displayName'] ?? 'user'.tr(),
      ),
    );
  }

  void _showBillSummarySheet(BuildContext context, Map<String, dynamic> billData) {
    PremiumBottomSheet.show(
      context: context,
      isScrollable: true,
      child: _BillSummarySheet(billData: billData),
    );
  }
}

class _BillSummarySheet extends StatelessWidget {
  final Map<String, dynamic> billData;

  const _BillSummarySheet({required this.billData});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final storeName = billData['storeName'] ?? 'unknown_store'.tr();
    final total = (billData['total'] as num? ?? 0.0).toDouble();
    final currency = billData['currencyCode'] ?? 'USD';
    final participants = billData['participants'] as List<dynamic>? ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          storeName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${'total_bill'.tr()}: ${CurrencyUtils.format(total, currencyCode: currency)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(height: 32),
        Text(
          'participants'.tr(),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        ...participants.map((p) {
          final pName = p['name'] ?? 'Friend';
          final pShare = (p['share'] as num? ?? 0.0).toDouble();
          final pStatus = p['status'] ?? 'PENDING';
          final isPaid = pStatus == 'PAID';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isPaid ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                    color: isPaid ? Colors.green : Colors.grey,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  CurrencyUtils.format(pShare, currencyCode: currency),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isPaid ? Colors.green : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}
