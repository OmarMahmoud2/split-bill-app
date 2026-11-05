import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/paywall/paywall_text.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';
import 'package:split_bill_app/widgets/subscription_legal_disclosure.dart';

/// RevenueCat entitlement that unlocks Pro (same as RevenueCatService).
const String _proEntitlement = 'premium';

/// The v3 Pro paywall ("Split everything, without limits").
///
/// Honest and short: five perks, Yearly / Monthly / Lifetime with the
/// store-localized prices, a CTA that says exactly what happens, and the
/// full subscription terms with Terms, Privacy and Restore right under it.
class PremiumModal extends StatefulWidget {
  const PremiumModal({super.key}) : loadPlans = null, _preview = false;

  /// Design/test preview with injectable plans; never buys anything.
  @visibleForTesting
  const PremiumModal.preview({
    super.key,
    Future<List<PaywallPlan>> Function()? loadPlans,
  }) : loadPlans = loadPlans ?? _previewPlans,
       _preview = true;

  /// Plan source; null reads the current RevenueCat offering.
  final Future<List<PaywallPlan>> Function()? loadPlans;
  final bool _preview;

  static Future<List<PaywallPlan>> _previewPlans() async =>
      PaywallPlan.previews;

  /// Opens the paywall as a full-screen route. Resolves to true after a
  /// successful purchase or restore.
  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => const PremiumModal(),
      ),
    );
  }

  @override
  State<PremiumModal> createState() => _PremiumModalState();
}

class _PremiumModalState extends State<PremiumModal> {
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  List<PaywallPlan> _plans = const [];
  PaywallPlan? _selected;

  static const _perks = [
    'pw_perk_scans',
    'pw_perk_voice',
    'pw_perk_trips',
    'pw_perk_export',
    'pw_perk_no_ads',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<PaywallPlan>> _loadFromStore() async {
    final packages = await RevenueCatService.getPremiumPackages();
    return PaywallPlan.fromPackages(packages);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    List<PaywallPlan> plans;
    try {
      plans = await (widget.loadPlans ?? _loadFromStore)();
    } catch (e) {
      debugPrint('Paywall plans failed to load: $e');
      plans = const [];
    }
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _selected = PaywallPlan.defaultPlan(plans);
      _loading = false;
      _failed = plans.isEmpty;
    });
  }

  Future<void> _purchase() async {
    final plan = _selected;
    if (plan == null || _busy) return;
    AppHaptics.light();
    final package = plan.package;
    if (widget._preview || package == null) return;

    setState(() => _busy = true);
    try {
      try {
        await RevenueCatService.syncCurrentUser();
      } catch (e) {
        debugPrint('RevenueCat identify failed: $e');
      }
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final active =
          result.customerInfo.entitlements.all[_proEntitlement]?.isActive ??
          false;
      if (!mounted) return;
      if (active) {
        unawaited(RevenueCatService.syncPremiumStatus());
        await _celebrate(restored: false);
      } else {
        _toast('pw_purchase_pending', AppToastType.info);
      }
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return;
      if (code == PurchasesErrorCode.paymentPendingError) {
        _toast('pw_purchase_pending', AppToastType.info);
      } else {
        debugPrint('Purchase failed: $e');
        _toast('pw_purchase_failed', AppToastType.error);
      }
    } catch (e) {
      debugPrint('Purchase failed: $e');
      _toast('pw_purchase_failed', AppToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    AppHaptics.light();
    if (widget._preview) return;
    setState(() => _busy = true);
    try {
      final info = await Purchases.restorePurchases();
      final active = info.entitlements.all[_proEntitlement]?.isActive ?? false;
      unawaited(RevenueCatService.syncPremiumStatus());
      if (!mounted) return;
      if (active) {
        await _celebrate(restored: true);
      } else {
        _toast('no_previous_purchase_found', AppToastType.info);
      }
    } catch (e) {
      debugPrint('Restore failed: $e');
      _toast('pw_restore_failed', AppToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _celebrate({required bool restored}) async {
    final navigator = Navigator.of(context);
    await SuccessScreen.show<void>(
      context,
      title: (restored ? 'pw_restored_title' : 'pw_success_title').tr(),
      message: 'pw_success_message'.tr(),
      primaryLabel: 'pw_success_cta'.tr(),
      onPrimary: () => navigator.pop(),
      celebrate: !restored,
    );
    if (mounted) navigator.pop(true);
  }

  void _toast(String key, AppToastType type) {
    if (!mounted) return;
    AppToast.show(context, message: key.tr(), type: type);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      20,
                      12,
                      20,
                      0,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: V3IconButton.close(
                        context,
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 24, 0),
                    child: Semantics(
                      header: true,
                      child: Text(
                        'pw_title'.tr(),
                        style: AppTypography.displaySmall.copyWith(
                          color: p.textPrimary,
                          fontSize: 32,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      24,
                      18,
                      24,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final perk in _perks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ExcludeSemantics(
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                    color: p.accent,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    perk.tr(),
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: p.textPrimary,
                                      fontSize: 15,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
                    child: _buildPlans(context),
                  ),
                  const Spacer(),
                  const SizedBox(height: 20),
                  if (_selected != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        20,
                        0,
                        20,
                        16,
                      ),
                      child: _buildBottom(context, _selected!),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlans(BuildContext context) {
    if (_loading) {
      return SkeletonShimmer(
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Skeleton(
                  height: 64,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
          ],
        ),
      );
    }
    if (_failed) {
      return ErrorState.inline(
        title: 'pricing_unavailable'.tr(),
        message: 'pw_pricing_unavailable_message'.tr(),
        onRetry: _load,
      );
    }
    final p = context.palette;
    return Semantics(
      label: 'pw_plan_group'.tr(),
      explicitChildNodes: true,
      child: Column(
        children: [
          for (final plan in _plans)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: V3RadioTile(
                key: ValueKey('paywall-plan-${plan.kind.name}'),
                radius: 16,
                selected: identical(plan, _selected),
                onTap: () => setState(() => _selected = plan),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.nameKey.tr(),
                            style: AppTypography.labelLarge.copyWith(
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            paywallText(plan.subtitle),
                            style: AppTypography.bodySmall.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      paywallText(plan.trailingPrice),
                      style: AppTypography.amount.copyWith(
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottom(BuildContext context, PaywallPlan plan) {
    final p = context.palette;
    final label = paywallText(plan.cta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const ValueKey('paywall-cta'),
          onPressed: _busy ? null : _purchase,
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            foregroundColor: p.onAccent,
            minimumSize: const Size.fromHeight(54),
          ),
          child: _busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: p.onAccent,
                    semanticsLabel: 'feedback_loading'.tr(),
                  ),
                )
              : AnimatedSwitcher(
                  duration: AppMotion.durationFor(context, AppMotion.fast),
                  child: Text(label, key: ValueKey(label)),
                ),
        ),
        const SizedBox(height: 10),
        SubscriptionLegalDisclosure.plan(plan: plan, onRestore: _restore),
      ],
    );
  }
}
