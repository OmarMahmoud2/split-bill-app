import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_breakdown_card.dart';
import 'package:split_bill_app/widgets/bill_details/bill_details_header.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';
import 'package:split_bill_app/widgets/bill_details/participant_tile.dart';
import 'package:split_bill_app/widgets/bill_details/pay_methods_list.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Bill, participant view (v3 Bills board 2). Presentational: everything
/// comes in as plain data and callbacks, so it pumps without Firebase.
class ParticipantBillView extends StatelessWidget {
  const ParticipantBillView({
    super.key,
    required this.hostName,
    required this.storeName,
    required this.currency,
    required this.breakdown,
    required this.status,
    required this.payEntries,
    required this.onOpenMethod,
    required this.onPaid,
    this.shareMinor,
    this.payLoading = false,
    this.openingEntry,
    this.submitting = false,
    this.offline = false,
  });

  final String hostName;
  final String storeName;
  final String currency;
  final PersonBreakdown breakdown;

  /// Stored share; defaults to the breakdown total (they match by contract).
  final int? shareMinor;
  final PayStatus status;
  final List<PayMethodEntry> payEntries;
  final bool payLoading;
  final PayMethodEntry? openingEntry;
  final ValueChanged<PayMethodEntry> onOpenMethod;
  final VoidCallback onPaid;
  final bool submitting;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final share = shareMinor ?? breakdown.totalMinor;
    final settled = status == PayStatus.paid;
    final firstName = hostName.trim().split(RegExp(r'\s+')).first;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'bf_bill_host_paid_store'.tr(
                namedArgs: {'host': hostName, 'store': storeName},
              ),
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'bf_bill_your_share'.tr(),
                    style: AppTypography.titleSmall.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (status != PayStatus.notYet)
                  PayStatusPill(status: status, self: true),
              ],
            ),
            MoneyText(
              key: const ValueKey('bf_bill_your_share_amount'),
              minor: share,
              currency: currency,
              tone: settled ? MoneyTone.neutral : MoneyTone.owe,
              sign: MoneySign.none,
              size: MoneySize.hero,
              style: const TextStyle(fontSize: 48),
              animate: true,
              semanticsLabel: 'bf_bill_your_share_semantics'.tr(
                namedArgs: {'amount': formatMoneyMinor(share, currency)},
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
        child: BillBreakdownCard(breakdown: breakdown, currency: currency),
      ),
      if (status == PayStatus.notYet) ...[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 8),
          child: Text(
            'bf_bill_pay_with'.tr(namedArgs: {'name': firstName}),
            style: AppTypography.labelMedium.copyWith(
              color: p.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: PayMethodsList(
            entries: payEntries,
            loading: payLoading,
            busyEntry: openingEntry,
            onOpen: onOpenMethod,
          ),
        ),
      ] else
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          child: _StatusNote(
            icon: settled ? AppIcons.success : AppIcons.clock,
            text: settled
                ? 'bf_bill_settled_note'.tr(namedArgs: {'host': firstName})
                : 'bd2_you_sent_waiting'.tr(
                    namedArgs: {
                      'amount': formatMoneyMinor(share, currency),
                      'name': firstName,
                    },
                  ),
          ),
        ),
      const SizedBox(height: AppSpacing.xxl),
    ];

    return Column(
      children: [
        const BillDetailsHeader(),
        OfflineBanner(
          visible: offline,
          margin: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
        ),
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < children.length; i++)
                StaggeredEntrance(index: i, child: children[i]),
            ],
          ),
        ),
        if (status == PayStatus.notYet && share > 0)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 16),
            child: BillPillButton(
              key: const ValueKey('bf_bill_paid_cta'),
              label: 'bf_bill_paid_cta'.tr(),
              busy: submitting,
              onPressed: onPaid,
            ),
          ),
      ],
    );
  }
}

class _StatusNote extends StatelessWidget {
  const _StatusNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
        boxShadow: p.softShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: p.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium.copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
