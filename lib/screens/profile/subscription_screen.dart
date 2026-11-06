import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:split_bill_app/config/feature_costs.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/paywall/paywall_text.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

/// Subscription status: plan, renewal, what Pro includes, and the store's
/// own management page plus Restore purchases.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key, this.userStream});

  /// The users/{uid} data; null reads Firestore for the signed-in user.
  @visibleForTesting
  final Stream<Map<String, dynamic>?>? userStream;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Stream<Map<String, dynamic>?> _stream;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stream = _makeStream();
  }

  Stream<Map<String, dynamic>?> _makeStream() {
    if (widget.userStream != null) return widget.userStream!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((s) => s.data());
  }

  Future<void> _manage() async {
    AppHaptics.light();
    var opened = false;
    try {
      opened = await RevenueCatService.openSubscriptionManagement();
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      AppToast.show(
        context,
        message: 'subscription_settings_unavailable'.tr(),
        type: AppToastType.error,
      );
    }
  }

  Future<void> _restore() async {
    if (_busy || widget.userStream != null) return;
    AppHaptics.light();
    setState(() => _busy = true);
    try {
      final info = await Purchases.restorePurchases();
      final active = info.entitlements.all['premium']?.isActive ?? false;
      unawaited(RevenueCatService.syncPremiumStatus());
      if (!mounted) return;
      AppToast.show(
        context,
        message: (active ? 'pw_restore_success' : 'no_previous_purchase_found')
            .tr(),
        type: active ? AppToastType.success : AppToastType.info,
      );
    } catch (e) {
      debugPrint('Restore failed: $e');
      if (mounted) {
        AppToast.show(
          context,
          message: 'pw_restore_failed'.tr(),
          type: AppToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: _stream,
          builder: (context, snapshot) {
            Widget body;
            if (snapshot.hasError) {
              body = ErrorState.inline(
                onRetry: () => setState(() => _stream = _makeStream()),
              );
            } else if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              body = const _LoadingCard();
            } else {
              final data = snapshot.data;
              body = RevenueCatService.isUserActivePremium(data)
                  ? _ProStatus(data: data!, onManage: _manage)
                  : _FreeStatus(points: (data?['points'] as num?)?.toInt());
            }
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                V3TopBar(
                  title: 'pw_subscription_title'.tr(),
                  leading: V3IconButton.back(context),
                ),
                const SizedBox(height: 18),
                body,
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 0),
                  child: OutlinedButton(
                    key: const ValueKey('subscription-restore'),
                    onPressed: _busy ? null : _restore,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: Text('pw_restore_purchases'.tr()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 20),
    child: SkeletonShimmer(
      child: Column(
        children: [
          SkeletonCard(lines: [0.3, 0.7, 0.5]),
          SizedBox(height: 12),
          SkeletonCard(lines: [0.8, 0.8, 0.8]),
        ],
      ),
    ),
  );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  final String badge;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProBadge(label: badge),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppTypography.displaySmall.copyWith(color: p.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProStatus extends StatelessWidget {
  const _ProStatus({required this.data, required this.onManage});

  final Map<String, dynamic> data;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final kind =
        planKindForProductId(data['premiumProductId']?.toString()) ??
        (data['premiumExpiresAt'] == null ? PaywallPlanKind.lifetime : null);
    final storeName = storeNameForId(data['premiumStore']?.toString());
    final expires = DateTime.tryParse(
      data['premiumExpiresAt']?.toString() ?? '',
    )?.toLocal();
    final willRenew = data['premiumWillRenew'] != false;
    final date = expires == null
        ? null
        : DateFormat.yMMMd(context.locale.toString()).format(expires);

    final String status;
    if (kind == PaywallPlanKind.lifetime || date == null) {
      status = 'pw_status_lifetime'.tr();
    } else if (willRenew) {
      status = storeName == null
          ? 'pw_status_renews'.tr(namedArgs: {'date': date})
          : 'pw_status_renews_store'.tr(
              namedArgs: {'date': date, 'store': storeName},
            );
    } else {
      status = 'pw_status_ends'.tr(namedArgs: {'date': date});
    }

    final badgeKey = switch (kind) {
      PaywallPlanKind.yearly => 'pw_badge_yearly',
      PaywallPlanKind.monthly => 'pw_badge_monthly',
      PaywallPlanKind.lifetime => 'pw_badge_lifetime',
      null => 'v3_pro_badge',
    };
    final titleKey = switch (kind) {
      PaywallPlanKind.yearly => 'pw_plan_title_yearly',
      PaywallPlanKind.monthly => 'pw_plan_title_monthly',
      PaywallPlanKind.lifetime => 'pw_plan_title_lifetime',
      null => 'pw_plan_title_pro',
    };
    // Promotional grants have nothing to manage in a store.
    final canManage =
        kind != PaywallPlanKind.lifetime &&
        data['premiumStore']?.toString().toUpperCase() != 'PROMOTIONAL';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanCard(badge: badgeKey.tr(), title: titleKey.tr(), subtitle: status),
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            SettingsRow(
              title: 'pw_row_scans'.tr(),
              value: 'pw_unlimited'.tr(),
              showChevron: false,
            ),
            SettingsRow(
              title: 'pw_row_voice'.tr(),
              value: 'pw_unlimited'.tr(),
              showChevron: false,
            ),
            SettingsRow(
              title: 'pw_row_ads'.tr(),
              value: 'pw_off'.tr(),
              showChevron: false,
            ),
          ],
        ),
        if (canManage)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
            child: OutlinedButton(
              key: const ValueKey('subscription-manage'),
              onPressed: onManage,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              child: Text(
                'pw_manage_in'.tr(namedArgs: {'store': paywallStoreName()}),
              ),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _FreeStatus extends StatelessWidget {
  const _FreeStatus({required this.points});

  final int? points;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlanCard(
          badge: 'pw_badge_free'.tr(),
          title: 'pw_plan_title_free'.tr(),
          subtitle: 'pw_free_points'.tr(
            namedArgs: {
              'points': '${points ?? 0}',
              'cost': '${FeatureCosts.receiptScanPoints}',
            },
          ),
        ),
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            SettingsRow(
              title: 'pw_row_scans'.tr(),
              value: 'pw_points_based'.tr(),
              showChevron: false,
            ),
            SettingsRow(
              title: 'pw_row_ads'.tr(),
              value: 'pw_ads_optional'.tr(),
              showChevron: false,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          child: FilledButton(
            key: const ValueKey('subscription-see-plans'),
            onPressed: () {
              AppHaptics.light();
              PremiumModal.show(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              minimumSize: const Size.fromHeight(54),
            ),
            child: Text('pw_see_plans'.tr()),
          ),
        ),
      ],
    );
  }
}
