import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:split_bill_app/screens/profile/widgets/profile_menu_widgets.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
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
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final p = context.palette;
        final currentData =
            (snapshot.data?.data() as Map<String, dynamic>?) ?? userData;
        final String name =
            (currentData['displayName'] as String?)?.trim().isNotEmpty == true
            ? currentData['displayName']
            : 'unknown_user'.tr();
        final isPremium = RevenueCatService.isUserActivePremium(currentData);
        final isAdmin = currentData['isAdmin'] == true;
        final int points = (currentData['points'] as num?)?.toInt() ?? 0;
        final String? photoUrl = currentData['photoUrl'] as String?;
        final ImageProvider? avatarImage = ImageUtils.getAvatarImage(photoUrl);

        // Process Country Name
        final String? isoCode = currentData['isoCode'] as String?;
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
        final String? loginPlatform = currentData['loginPlatform'] as String?;
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
          final email = currentData['email'] as String? ?? '';
          if (email.endsWith('@privaterelay.appleid.com')) {
            platformDisplay = 'Apple (Inferred)';
          }
        }

        return Scaffold(
          backgroundColor: p.surfaceMuted,
          appBar: AppBar(
            title: Text(name),
            backgroundColor: p.surface,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.notifications_active_rounded, color: p.info),
                onPressed: () => _sendNotification(context, currentData),
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Profile Summary
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: p.shadow.withValues(alpha: 0.03),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: isAdmin
                                  ? p.tint(
                                      Colors.blueGrey[50]!,
                                      Colors.blueGrey,
                                    )
                                  : (isPremium
                                        ? p.tint(
                                            Colors.amber[50]!,
                                            Colors.amber,
                                          )
                                        : p.infoSoft),
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? Text(
                                      name.isNotEmpty
                                          ? name.characters.first.toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: isAdmin
                                            ? (p.isDark
                                                  ? Colors.blueGrey[200]
                                                  : Colors.blueGrey[700])
                                            : (isPremium
                                                  ? (p.isDark
                                                        ? Colors.amber[300]
                                                        : Colors.amber[800])
                                                  : (p.isDark
                                                        ? p.infoStrong
                                                        : Colors.blue[700])),
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
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isAdmin) ...[
                                  _buildBadge(
                                    'admin'.tr(),
                                    p.isDark
                                        ? Colors.blueGrey[200]!
                                        : Colors.blueGrey[700]!,
                                    p.tint(
                                      Colors.blueGrey[50]!,
                                      Colors.blueGrey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (isPremium)
                                  _buildBadge(
                                    'premium_crown'.tr(),
                                    p.isDark
                                        ? Colors.amber[300]!
                                        : Colors.amber[800]!,
                                    p.tint(Colors.amber[50]!, Colors.amber),
                                  )
                                else if (!isAdmin)
                                  _buildBadge(
                                    'admin_user_free'.tr(),
                                    p.textMedium,
                                    p.surfaceVariant,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildDetailRow(
                              p,
                              Icons.fingerprint_rounded,
                              'UID',
                              uid,
                            ),
                            _buildDetailRow(
                              p,
                              Icons.mail_outline_rounded,
                              'email'.tr(),
                              currentData['email'] ?? 'not_provided'.tr(),
                            ),
                            _buildDetailRow(
                              p,
                              Icons.phone_iphone_rounded,
                              'phone'.tr(),
                              currentData['phoneNumber'] ?? 'not_provided'.tr(),
                            ),
                            if (platformDisplay != 'unknown'.tr())
                              _buildDetailRow(
                                p,
                                Icons.devices_rounded,
                                'platform'.tr(),
                                platformDisplay,
                              ),
                            _buildDetailRow(
                              p,
                              Icons.public_rounded,
                              'country'.tr(),
                              countryName,
                            ),
                            _buildDetailRow(
                              p,
                              Icons.stars_rounded,
                              'points'.tr(),
                              points.toString(),
                            ),
                            if (currentData['premiumExpiresAt'] != null)
                              _buildDetailRow(
                                p,
                                Icons.timer_outlined,
                                'Expires',
                                currentData['premiumExpiresAt']
                                    .toString()
                                    .split('T')
                                    .first,
                              ),
                            _buildDetailRow(
                              p,
                              Icons.calendar_today_rounded,
                              'registered'.tr(),
                              currentData['createdAt'] != null
                                  ? DateFormat.yMMMd().format(
                                      (currentData['createdAt'] as Timestamp)
                                          .toDate(),
                                    )
                                  : 'unknown'.tr(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      ProfileSectionTitle(title: 'admin_controls'.tr()),

                      // Admin Controls Container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: p.shadow.withValues(alpha: 0.03),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Points Management
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'points'.tr(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.tint(
                                      Colors.amber[50]!,
                                      Colors.amber,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.stars_rounded,
                                        color: p.isDark
                                            ? Colors.amber[300]
                                            : Colors.amber[800],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$points pts',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: p.isDark
                                              ? Colors.amber[200]
                                              : Colors.amber[900],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Points Action Buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildActionChip(
                                  label: '+5',
                                  color: p.success,
                                  onTap: () =>
                                      _modifyPoints(context, points, 5),
                                ),
                                _buildActionChip(
                                  label: '+10',
                                  color: p.success,
                                  onTap: () =>
                                      _modifyPoints(context, points, 10),
                                ),
                                _buildActionChip(
                                  label: '+50',
                                  color: p.success,
                                  onTap: () =>
                                      _modifyPoints(context, points, 50),
                                ),
                                _buildActionChip(
                                  label: '-5',
                                  color: p.danger,
                                  onTap: () =>
                                      _modifyPoints(context, points, -5),
                                ),
                                _buildActionChip(
                                  label: '-10',
                                  color: p.danger,
                                  onTap: () =>
                                      _modifyPoints(context, points, -10),
                                ),
                                _buildActionChip(
                                  label: 'set_custom_points'.tr(),
                                  color: p.info,
                                  isOutlined: true,
                                  onTap: () =>
                                      _showCustomPointsDialog(context, points),
                                ),
                              ],
                            ),

                            const Divider(height: 28),

                            // 2. Premium Management
                            Text(
                              'premium_status'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        _togglePremium(context, isPremium),
                                    icon: Icon(
                                      isPremium
                                          ? Icons.remove_circle_outline_rounded
                                          : Icons.workspace_premium_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isPremium
                                          ? 'revoke_premium'.tr()
                                          : 'grant_premium'.tr(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isPremium
                                          ? p.dangerSoft
                                          : Colors.amber[500],
                                      foregroundColor: isPremium
                                          ? p.dangerStrong
                                          : Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: isPremium
                                            ? BorderSide(
                                                color: p.isDark
                                                    ? p.danger.withValues(
                                                        alpha: 0.4,
                                                      )
                                                    : Colors.red.shade200,
                                              )
                                            : BorderSide.none,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 28),

                            // 3. Admin Role Management
                            Text(
                              'admin'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _toggleAdminRole(context, isAdmin),
                                    icon: Icon(
                                      isAdmin
                                          ? Icons.person_remove_rounded
                                          : Icons.admin_panel_settings_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isAdmin
                                          ? 'remove_admin'.tr()
                                          : 'make_admin'.tr(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isAdmin
                                          ? p.dangerStrong
                                          : (p.isDark
                                                ? Colors.blueGrey[100]
                                                : Colors.blueGrey[800]),
                                      side: BorderSide(
                                        color: isAdmin
                                            ? Colors.red.shade300
                                            : Colors.blueGrey.shade300,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final billDoc = bills[index];
                        final billData = billDoc.data() as Map<String, dynamic>;
                        final storeName =
                            billData['storeName'] ?? 'unknown_store'.tr();
                        final total = (billData['total'] as num? ?? 0.0)
                            .toDouble();
                        final currency = billData['currencyCode'] ?? 'USD';
                        final date = (billData['date'] as Timestamp).toDate();
                        final status = billData['status'] ?? 'PENDING';

                        return ProfileCoolTile(
                          icon: Icons.receipt_long_rounded,
                          title: storeName,
                          subtitle:
                              '${CurrencyUtils.format(total, currencyCode: currency)} • ${DateFormat.yMMMd().format(date)}',
                          color: status == 'PAID' ? p.success : p.warning,
                          onTap: () {
                            _showBillSummarySheet(context, billData);
                          },
                        );
                      }, childCount: bills.length),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return Material(
      color: isOutlined ? Colors.transparent : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isOutlined
                ? Border.all(color: color.withValues(alpha: 0.5))
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _modifyPoints(
    BuildContext context,
    int currentPoints,
    int delta,
  ) async {
    final newPoints = (currentPoints + delta).clamp(0, 999999);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'points': newPoints,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'user_updated_success'.tr()} ($newPoints pts)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: context.palette.danger,
          ),
        );
      }
    }
  }

  Future<void> _showCustomPointsDialog(
    BuildContext context,
    int currentPoints,
  ) async {
    final controller = TextEditingController(text: currentPoints.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('set_custom_points'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'points'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, parsed);
            },
            child: Text('save'.tr()),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      final safePoints = result.clamp(0, 999999);
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'points': safePoints,
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${'user_updated_success'.tr()} ($safePoints pts)'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: context.palette.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _togglePremium(
    BuildContext context,
    bool currentlyPremium,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          currentlyPremium ? 'revoke_premium'.tr() : 'grant_premium'.tr(),
        ),
        content: Text(
          currentlyPremium
              ? 'confirm_premium_revoke'.tr()
              : 'confirm_premium_grant'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyPremium
                  ? ctx.palette.danger
                  : Colors.amber[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              currentlyPremium ? 'revoke_premium'.tr() : 'grant_premium'.tr(),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final updates = currentlyPremium
            ? <String, dynamic>{
                'isPremium': false,
                'premiumUpdatedAt': FieldValue.serverTimestamp(),
              }
            : <String, dynamic>{
                'isPremium': true,
                'premiumExpiresAt': null,
                'premiumEntitlementId': 'premium',
                'premiumProductId': 'admin_granted_lifetime',
                'premiumUpdatedAt': FieldValue.serverTimestamp(),
              };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(updates, SetOptions(merge: true));

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('user_updated_success'.tr())));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: context.palette.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleAdminRole(
    BuildContext context,
    bool currentlyAdmin,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(currentlyAdmin ? 'remove_admin'.tr() : 'make_admin'.tr()),
        content: Text('confirm_admin_toggle'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: currentlyAdmin
                  ? ctx.palette.danger
                  : Colors.blueGrey[800],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              currentlyAdmin ? 'remove_admin'.tr() : 'make_admin'.tr(),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'isAdmin': !currentlyAdmin,
        });

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('user_updated_success'.tr())));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: context.palette.danger,
            ),
          );
        }
      }
    }
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

  Widget _buildDetailRow(
    AppPalette p,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: p.textDisabled),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(color: p.textSecondary, fontSize: 13),
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

  void _sendNotification(
    BuildContext context,
    Map<String, dynamic> currentData,
  ) {
    PremiumBottomSheet.show(
      context: context,
      child: SendNotificationSheet(
        targetUid: uid,
        targetToken: currentData['fcmToken'],
        userName: currentData['displayName'] ?? 'user'.tr(),
      ),
    );
  }

  void _showBillSummarySheet(
    BuildContext context,
    Map<String, dynamic> billData,
  ) {
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
    final palette = context.palette;
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
                    color: (isPaid ? palette.success : palette.textTertiary)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                    color: isPaid ? palette.success : palette.textTertiary,
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
                    color: isPaid ? palette.success : colorScheme.onSurface,
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
