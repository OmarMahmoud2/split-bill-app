import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/paywall/paywall_plans.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/widgets/paywall/paywall_pricing.dart';
import 'package:split_bill_app/widgets/paywall/paywall_text.dart';

/// Display order of the stubs (the offering order is yearly first).
List<PaywallPlan> stubOrder(List<PaywallPlan> plans) {
  const order = [
    PaywallPlanKind.monthly,
    PaywallPlanKind.yearly,
    PaywallPlanKind.lifetime,
  ];
  return [
    for (final k in order)
      for (final plan in plans)
        if (plan.kind == k) plan,
  ];
}

/// Monthly / Yearly / Lifetime as three ticket stubs (radio group). The
/// middle one is slightly wider; the selected one lifts 4 px.
class PaywallStubs extends StatelessWidget {
  const PaywallStubs({
    super.key,
    required this.plans,
    required this.selected,
    required this.onSelected,
  });

  final List<PaywallPlan> plans;
  final PaywallPlan? selected;
  final ValueChanged<PaywallPlan> onSelected;

  @override
  Widget build(BuildContext context) {
    final ordered = stubOrder(plans);
    return Semantics(
      label: 'pw_plan_group'.tr(),
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < ordered.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  flex: ordered[i].kind == PaywallPlanKind.yearly ? 115 : 100,
                  child: _Stub(
                    plan: ordered[i],
                    selected: identical(ordered[i], selected),
                    onTap: () => onSelected(ordered[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stub extends StatelessWidget {
  const _Stub({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  final PaywallPlan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = AppMotion.reduceMotion(context);
    final duration = reduce ? Duration.zero : AppMotion.slow;
    final name = plan.nameKey.tr();
    final per = paywallText(plan.stubPerLine);
    final badge =
        plan.hasTrialSubscription && plan.kind == PaywallPlanKind.yearly
        ? 'pw_badge_trial_days'.tr(namedArgs: {'days': '${plan.freeTrialDays}'})
        : null;
    final borderColor = selected
        ? (p.isDark ? p.accent : p.textPrimary)
        : p.border;
    const radius = BorderRadius.all(Radius.circular(16));

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      checked: selected,
      button: true,
      label: [name, plan.priceString, per, ?badge].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: duration,
              curve: AppMotion.quiet,
              transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: radius,
                border: Border.all(color: borderColor, width: 2),
              ),
            ),
          ),
          AnimatedContainer(
            duration: duration,
            curve: AppMotion.quiet,
            transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey('paywall-plan-${plan.kind.name}'),
                borderRadius: radius,
                onTap: onTap,
                child: ConstrainedBox(
                  // Fill the stub so the centred column stays centred
                  // (the Stack would otherwise anchor it to the start).
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: double.infinity,
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(8, 16, 8, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: AppTypography.labelMedium.copyWith(
                            color: p.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            plan.priceString,
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: AppTypography.displayFamily,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                              height: 1.1,
                              letterSpacing: -0.44,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          per,
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSmall.copyWith(
                            color: p.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              top: -12,
              left: -4,
              right: -4,
              child: IgnorePointer(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badge,
                        maxLines: 1,
                        style: AppTypography.labelSmall.copyWith(
                          color: p.onAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
