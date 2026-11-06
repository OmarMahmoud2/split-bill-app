import 'package:split_bill_app/services/analytics_service.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/paywall/paywall_body.dart';

/// RevenueCat entitlement that unlocks Pro (same as RevenueCatService).
const String _proEntitlement = 'premium';

/// The Pro paywall ("Every bill, no limits").
///
/// Honest and short: five perks, Yearly / Monthly / Lifetime with the
/// store-localized prices, a CTA that says exactly what happens, and the
/// full subscription terms with Terms, Privacy and Restore right under it.
class PremiumModal extends StatefulWidget {
  const PremiumModal({super.key, this.placement = 'unknown'})
    : loadPlans = null,
      _preview = false;

  /// Design/test preview with injectable plans; never buys anything.
  @visibleForTesting
  const PremiumModal.preview({
    super.key,
    Future<List<PaywallPlan>> Function()? loadPlans,
  }) : loadPlans = loadPlans ?? _previewPlans,
       placement = 'preview',
       _preview = true;

  /// Plan source; null reads the current RevenueCat offering.
  final Future<List<PaywallPlan>> Function()? loadPlans;
  final bool _preview;

  /// Which feature or screen opened the paywall (analytics only).
  final String placement;

  static Future<List<PaywallPlan>> _previewPlans() async =>
      PaywallPlan.previews;

  /// Opens the paywall as a full-screen route. Resolves to true after a
  /// successful purchase or restore.
  static Future<bool?> show(
    BuildContext context, {
    String placement = 'unknown',
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => PremiumModal(placement: placement),
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

  @override
  void initState() {
    super.initState();
    if (!widget._preview) {
      AnalyticsService.instance.paywallView(widget.placement);
    }
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
    AnalyticsService.instance.purchaseStarted(plan.kind.name);
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
        AnalyticsService.instance.purchaseSuccess(
          plan.kind.name,
          isTrial: plan.hasFreeTrial,
        );
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
        AnalyticsService.instance.purchaseRestored();
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
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: SafeArea(
        child: PaywallBody(
          loading: _loading,
          failed: _failed,
          plans: _plans,
          selected: _selected,
          busy: _busy,
          onSelected: (plan) => setState(() => _selected = plan),
          onPurchase: _purchase,
          onRestore: _restore,
          onRetry: _load,
          onClose: () => Navigator.of(context).pop(false),
        ),
      ),
    );
  }
}
