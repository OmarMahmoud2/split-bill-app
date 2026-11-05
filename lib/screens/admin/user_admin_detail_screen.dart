import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/currency_utils.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';
import 'widgets/admin_avatar.dart';
import 'widgets/send_notification_sheet.dart';

/// Admin: one user's profile, plan, points and bills (v3 "User detail").
class UserAdminDetailScreen extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> userData;

  const UserAdminDetailScreen({
    super.key,
    required this.uid,
    required this.userData,
  });

  static String platformLabel(Map<String, dynamic> data) {
    final loginPlatform =
        (data['loginPlatform'] ?? data['fcmPlatform']) as String?;
    if (loginPlatform != null && loginPlatform.isNotEmpty) {
      switch (loginPlatform.toLowerCase()) {
        case 'ios':
          return 'iOS';
        case 'android':
          return 'Android';
        case 'web':
          return 'Web';
      }
      return loginPlatform;
    }
    final email = data['email'] as String? ?? '';
    if (email.endsWith('@privaterelay.appleid.com')) return 'iOS';
    return '';
  }

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
        final locale = context.locale.toLanguageTag();
        final createdAt = currentData['createdAt'];
        final joined = createdAt is Timestamp
            ? DateFormat.yMMMd(locale).format(createdAt.toDate())
            : null;
        final lastSync = currentData['fcmTokenUpdatedAt'];

        final String? isoCode = currentData['isoCode'] as String?;
        String countryName = 'unknown'.tr();
        if (isoCode != null) {
          try {
            countryName = countries.firstWhere((c) => c.code == isoCode).name;
          } catch (_) {
            countryName = isoCode;
          }
        }
        final platform = platformLabel(currentData);
        final plan = isAdmin
            ? 'admin'.tr()
            : (isPremium ? 'adm3_plan_pro'.tr() : 'adm3_plan_free'.tr());
        final caption = [
          if (joined != null) 'adm3_joined'.tr(namedArgs: {'date': joined}),
          if (platform.isNotEmpty) platform,
          plan,
        ].join(' · ');
        final expires = currentData['premiumExpiresAt']?.toString() ?? '';

        return Scaffold(
          backgroundColor: p.canvas,
          body: SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: V3TopBar(
                    leading: V3IconButton.back(context),
                    title: 'adm3_user_title'.tr(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      16,
                      20,
                      0,
                    ),
                    child: Row(
                      children: [
                        AdminAvatar(
                          name: name,
                          photoUrl: currentData['photoUrl'] as String?,
                          size: 52,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: AppTypography.titleLarge.copyWith(
                                  color: p.textPrimary,
                                ),
                              ),
                              Text(
                                caption,
                                style: AppTypography.bodySmall.copyWith(
                                  color: p.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 14)),
                SliverToBoxAdapter(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('bills')
                        .where('participants_uids', arrayContains: uid)
                        .snapshots(),
                    builder: (context, billSnap) {
                      final bills = [...?billSnap.data?.docs];
                      bills.sort((a, b) {
                        final dateA =
                            (a.data() as Map<String, dynamic>?)?['date']
                                as Timestamp?;
                        final dateB =
                            (b.data() as Map<String, dynamic>?)?['date']
                                as Timestamp?;
                        if (dateA == null && dateB == null) return 0;
                        if (dateA == null) return 1;
                        if (dateB == null) return -1;
                        return dateB.compareTo(dateA);
                      });
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SettingsCard(
                            children: [
                              _InfoRow(
                                'adm3_bills'.tr(),
                                billSnap.hasData ? '${bills.length}' : '—',
                                numeric: true,
                              ),
                              _InfoRow(
                                'adm3_points_balance'.tr(),
                                '$points',
                                numeric: true,
                              ),
                              _InfoRow(
                                'adm3_last_sync'.tr(),
                                lastSync is Timestamp
                                    ? DateFormat.yMMMd(
                                        locale,
                                      ).format(lastSync.toDate())
                                    : '—',
                              ),
                              if (isPremium && expires.isNotEmpty)
                                _InfoRow(
                                  'adm3_premium_expires'.tr(),
                                  expires.split('T').first,
                                ),
                              _InfoRow(
                                'email'.tr(),
                                (currentData['email'] as String?) ??
                                    'not_provided'.tr(),
                              ),
                              _InfoRow(
                                'phone'.tr(),
                                (currentData['phoneNumber'] as String?) ??
                                    'not_provided'.tr(),
                              ),
                              _InfoRow('country'.tr(), countryName),
                              _InfoRow('UID', uid, selectable: true),
                            ],
                          ),
                          _actions(
                            context,
                            currentData,
                            points,
                            isPremium,
                            isAdmin,
                          ),
                          SettingsSectionLabel('user_bills_summary'.tr()),
                          if (billSnap.hasError)
                            ErrorState.inline(
                              message: 'error_loading_bills'.tr(),
                            )
                          else if (!billSnap.hasData)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: SkeletonCard(),
                            )
                          else if (bills.isEmpty)
                            EmptyState(
                              compact: true,
                              icon: Icons.receipt_long_outlined,
                              title: 'no_bills_found'.tr(),
                            )
                          else
                            SettingsCard(
                              children: [
                                for (final doc in bills)
                                  _billRow(
                                    context,
                                    doc.data() as Map<String, dynamic>,
                                    locale,
                                  ),
                              ],
                            ),
                          const SizedBox(height: 48),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actions(
    BuildContext context,
    Map<String, dynamic> currentData,
    int points,
    bool isPremium,
    bool isAdmin,
  ) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            key: const ValueKey('admin-grant-10'),
            onPressed: () => _modifyPoints(context, points, 10),
            child: Text('adm3_grant_points'.tr(namedArgs: {'count': '10'})),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final delta in const [5, 50, -5, -10])
                V3ChoiceChip(
                  label: delta > 0 ? '+$delta' : '−${-delta}',
                  selected: false,
                  onTap: () => _modifyPoints(context, points, delta),
                ),
              V3ChoiceChip(
                label: 'set_custom_points'.tr(),
                selected: false,
                onTap: () => _showCustomPointsDialog(context, points),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _sendNotification(context, currentData),
            child: Text('adm3_send_message'.tr()),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _togglePremium(context, isPremium),
            style: isPremium
                ? OutlinedButton.styleFrom(
                    foregroundColor: p.error,
                    side: BorderSide(color: p.errorSoft),
                  )
                : null,
            child: Text(
              isPremium ? 'revoke_premium'.tr() : 'grant_premium'.tr(),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => _toggleAdminRole(context, isAdmin),
            style: isAdmin
                ? OutlinedButton.styleFrom(
                    foregroundColor: p.error,
                    side: BorderSide(color: p.errorSoft),
                  )
                : null,
            child: Text(
              isAdmin ? 'adm3_remove_admin'.tr() : 'adm3_make_admin'.tr(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(
    BuildContext context,
    Map<String, dynamic> billData,
    String locale,
  ) {
    final storeName = billData['storeName'] ?? 'unknown_store'.tr();
    final total = (billData['total'] as num? ?? 0.0).toDouble();
    final currency = billData['currencyCode'] ?? 'USD';
    final date = billData['date'];
    final status = billData['status'] ?? 'PENDING';
    return SettingsRow(
      title: storeName.toString(),
      subtitle: [
        CurrencyUtils.format(total, currencyCode: currency),
        if (date is Timestamp) DateFormat.yMMMd(locale).format(date.toDate()),
      ].join(' · '),
      trailing: status == 'PAID' ? SoftChip('adm3_paid'.tr()) : null,
      onTap: () => _showBillSummarySheet(context, billData),
    );
  }

  Future<void> _saveUser(
    BuildContext context,
    Map<String, dynamic> updates, {
    String? successMessage,
    bool merge = false,
  }) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(uid);
      if (merge) {
        await ref.set(updates, SetOptions(merge: true));
      } else {
        await ref.update(updates);
      }
      if (context.mounted) {
        AppToast.show(
          context,
          message: successMessage ?? 'user_updated_success'.tr(),
          type: AppToastType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          message: 'adm3_update_failed'.tr(),
          type: AppToastType.error,
        );
      }
    }
  }

  Future<void> _modifyPoints(
    BuildContext context,
    int currentPoints,
    int delta,
  ) {
    final newPoints = (currentPoints + delta).clamp(0, 999999);
    return _saveUser(
      context,
      {'points': newPoints},
      successMessage: 'adm3_points_saved'.tr(
        namedArgs: {'count': '$newPoints'},
      ),
    );
  }

  Future<void> _showCustomPointsDialog(
    BuildContext context,
    int currentPoints,
  ) async {
    final controller = TextEditingController(text: currentPoints.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('set_custom_points'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(labelText: 'points'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: Text('adm3_save'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && context.mounted) {
      final safePoints = result.clamp(0, 999999);
      await _saveUser(
        context,
        {'points': safePoints},
        successMessage: 'adm3_points_saved'.tr(
          namedArgs: {'count': '$safePoints'},
        ),
      );
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    required bool destructive,
  }) async {
    if (destructive) AppHaptics.warning();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final p = ctx.palette;
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr()),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: p.error,
                      foregroundColor: p.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _togglePremium(
    BuildContext context,
    bool currentlyPremium,
  ) async {
    final label = currentlyPremium
        ? 'revoke_premium'.tr()
        : 'grant_premium'.tr();
    final ok = await _confirm(
      context,
      title: label,
      message: currentlyPremium
          ? 'confirm_premium_revoke'.tr()
          : 'confirm_premium_grant'.tr(),
      action: label,
      destructive: currentlyPremium,
    );
    if (!ok || !context.mounted) return;
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
    await _saveUser(context, updates, merge: true);
  }

  Future<void> _toggleAdminRole(
    BuildContext context,
    bool currentlyAdmin,
  ) async {
    final label = currentlyAdmin
        ? 'adm3_remove_admin'.tr()
        : 'adm3_make_admin'.tr();
    final ok = await _confirm(
      context,
      title: label,
      message: 'confirm_admin_toggle'.tr(),
      action: label,
      destructive: currentlyAdmin,
    );
    if (!ok || !context.mounted) return;
    await _saveUser(context, {'isAdmin': !currentlyAdmin});
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

class _InfoRow extends StatelessWidget {
  const _InfoRow(
    this.label,
    this.value, {
    this.numeric = false,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool numeric;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final style = numeric
        ? AppTypography.amountSmall.copyWith(
            color: p.textPrimary,
            fontFeatures: AppTypography.tabularFigures,
          )
        : AppTypography.bodyMedium.copyWith(color: p.textPrimary);
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  color: p.textPrimary,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: selectable
                    ? SelectableText(
                        value,
                        style: style,
                        textAlign: TextAlign.end,
                      )
                    : Text(
                        value,
                        style: style,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillSummarySheet extends StatelessWidget {
  final Map<String, dynamic> billData;

  const _BillSummarySheet({required this.billData});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final storeName = billData['storeName'] ?? 'unknown_store'.tr();
    final total = (billData['total'] as num? ?? 0.0).toDouble();
    final currency = billData['currencyCode'] ?? 'USD';
    final participants = billData['participants'] as List<dynamic>? ?? [];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          storeName.toString(),
          style: AppTypography.headlineMedium.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          '${'total_bill'.tr()}: ${CurrencyUtils.format(total, currencyCode: currency)}',
          style: AppTypography.amount.copyWith(color: p.textPrimary),
        ),
        Divider(height: 28, color: p.borderSubtle),
        Text(
          'participants'.tr(),
          style: AppTypography.titleSmall.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: 8),
        ...participants.map((part) {
          final pName = (part is Map ? part['name'] : null) ?? 'a_friend'.tr();
          final pShare = ((part is Map ? part['share'] : null) as num? ?? 0.0)
              .toDouble();
          final isPaid = part is Map && part['status'] == 'PAID';
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  size: 18,
                  color: isPaid ? p.accent : p.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$pName',
                    style: AppTypography.bodyLarge.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
                Text(
                  isPaid ? 'adm3_paid'.tr() : 'adm3_pending'.tr(),
                  style: AppTypography.bodySmall.copyWith(
                    color: p.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  CurrencyUtils.format(pShare, currencyCode: currency),
                  style: AppTypography.amountSmall.copyWith(
                    color: p.textPrimary,
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
