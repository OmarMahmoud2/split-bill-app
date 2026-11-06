import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:split_bill_app/widgets/paywall/paywall_pricing.dart';
import 'package:split_bill_app/widgets/paywall/paywall_receipt.dart';
import 'package:split_bill_app/widgets/paywall/paywall_stubs.dart';
import 'package:split_bill_app/widgets/paywall/paywall_text.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';
import 'package:split_bill_app/widgets/subscription_legal_disclosure.dart';

/// The v4 paywall layout ("Every bill, no limits"): close button, headline,
/// receipt of perks, plan stubs, "due today", then the CTA, legal text and
/// links. Purely presentational: purchase / restore live in the caller.
///
/// The area above the CTA scrolls, so small screens and large text fit.
class PaywallBody extends StatelessWidget {
  const PaywallBody({
    super.key,
    required this.loading,
    required this.failed,
    required this.plans,
    required this.selected,
    required this.busy,
    required this.onSelected,
    required this.onPurchase,
    required this.onRestore,
    required this.onRetry,
    required this.onClose,
    this.clock = DateTime.now,
  });

  final bool loading;
  final bool failed;
  final List<PaywallPlan> plans;
  final PaywallPlan? selected;
  final bool busy;
  final ValueChanged<PaywallPlan> onSelected;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  /// Today, injectable for tests.
  final DateTime Function() clock;

  void _select(PaywallPlan plan) {
    if (identical(plan, selected)) return;
    AppHaptics.selection();
    onSelected(plan);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final plan = selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: V3IconButton.close(context, onPressed: onClose),
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(22, 4, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'pw_headline'.tr(),
                          style: TextStyle(
                            fontFamily: AppTypography.displayFamily,
                            fontWeight: FontWeight.w800,
                            fontSize: 34,
                            height: 1.05,
                            letterSpacing: -1.02,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const PaywallReceipt(),
                      const SizedBox(height: 18),
                      _plans(context),
                      if (plan != null) _dueToday(context, plan),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (plan != null) _bottom(context, plan),
      ],
    );
  }

  Widget _plans(BuildContext context) {
    if (loading) {
      return SkeletonShimmer(
        child: const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Skeleton(
            height: 92,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      );
    }
    if (failed) {
      return ErrorState.inline(
        title: 'pricing_unavailable'.tr(),
        message: 'pw_pricing_unavailable_message'.tr(),
        onRetry: onRetry,
      );
    }
    return PaywallStubs(plans: plans, selected: selected, onSelected: _select);
  }

  String _locale(BuildContext context) =>
      Localizations.localeOf(context).toString();

  /// The date the trial ends, or null when [plan] has no trial.
  String? _trialDate(BuildContext context, PaywallPlan plan) {
    if (!plan.hasTrialSubscription) return null;
    return formatTrialDate(
      trialEndDate(clock(), plan.freeTrialDays!),
      _locale(context),
    );
  }

  Widget _dueToday(BuildContext context, PaywallPlan plan) {
    final p = context.palette;
    final date = _trialDate(context, plan);
    final label = date != null
        ? 'pw_due_today_then'.tr(
            namedArgs: {'price': plan.priceString, 'date': date},
          )
        : 'pw_due_today'.tr();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 22, 2, 0),
      child: Row(
        key: const ValueKey('paywall-due-today'),
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: p.textSecondary,
                fontSize: 14.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            plan.dueTodayString(locale: _locale(context)),
            style: TextStyle(
              fontFamily: 'IBMPlexMono',
              fontWeight: FontWeight.w500,
              fontSize: 15,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottom(BuildContext context, PaywallPlan plan) {
    final p = context.palette;
    final date = _trialDate(context, plan);
    final legal = [
      for (final c in plan.legalV4(store: paywallStoreName(), date: date))
        paywallText(c),
    ].join(' ');
    final label = paywallText(plan.ctaV4);
    final linkStyle = AppTypography.labelMedium.copyWith(
      color: p.textPrimary,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const ValueKey('paywall-cta'),
            onPressed: busy ? null : onPurchase,
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: AppTypography.labelLarge.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: busy
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
                    child: Text(
                      label,
                      key: ValueKey(label),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 12, 4, 2),
            child: Text(
              legal,
              key: const ValueKey('paywall-legal'),
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: p.textSecondary,
                fontWeight: FontWeight.w400,
                fontSize: 11.5,
                height: 1.5,
              ),
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              _Link(
                key: const ValueKey('paywall-restore'),
                label: 'pw_link_restore'.tr(),
                style: linkStyle,
                onTap: onRestore,
              ),
              _Link(
                label: 'pw_link_terms'.tr(),
                style: linkStyle,
                onTap: () => SubscriptionLegalDisclosure.openLink(
                  context,
                  AppLinks.termsOfUseUrl,
                ),
              ),
              _Link(
                label: 'pw_link_privacy'.tr(),
                style: linkStyle,
                onTap: () => SubscriptionLegalDisclosure.openLink(
                  context,
                  AppLinks.privacyPolicyUrl,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Link extends StatelessWidget {
  const _Link({
    super.key,
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: context.palette.textPrimary,
      minimumSize: const Size(44, 44),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: style,
    ),
    child: Text(label),
  );
}
