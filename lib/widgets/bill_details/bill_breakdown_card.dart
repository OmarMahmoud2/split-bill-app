import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Resolves a [CopyText] with easy_localization.
String resolveCopy(CopyText copy) =>
    copy.raw ?? copy.key!.tr(namedArgs: copy.args);

/// "Every cent accounted for": one row per [BreakdownLine] (items in ink,
/// charges muted), then a total that is exactly the sum of the rows.
class BillBreakdownCard extends StatelessWidget {
  const BillBreakdownCard({
    super.key,
    required this.breakdown,
    required this.currency,
    this.showTotal = true,
    this.totalLabel,
    this.bordered = true,
  });

  final PersonBreakdown breakdown;
  final String currency;
  final bool showTotal;

  /// Defaults to `bf_bill_breakdown_total`.
  final String? totalLabel;

  /// Hairline card around the rows (off inside sheets).
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final lines = breakdown.lines.where((l) => l.amountMinor != 0).toList();
    final rows = <Widget>[
      if (lines.isEmpty)
        Text(
          'bf_bill_breakdown_empty'.tr(),
          style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
        ),
      for (final line in lines)
        _LineRow(
          label: resolveCopy(breakdownLineCopy(line)),
          amount: formatMoneyMinor(
            line.amountMinor,
            currency,
            showSymbol: false,
          ),
          muted: !isItemLine(line),
        ),
      if (showTotal) ...[
        Divider(height: AppSpacing.xl, thickness: 1.5, color: p.hairline),
        Row(
          children: [
            Expanded(
              child: Text(
                totalLabel ?? 'bf_bill_breakdown_total'.tr(),
                style: AppTypography.titleSmall.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            MoneyText(
              key: const ValueKey('bf_bill_breakdown_total_amount'),
              minor: breakdown.totalMinor,
              currency: currency,
              tone: MoneyTone.neutral,
              size: MoneySize.row,
            ),
          ],
        ),
      ],
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0 && rows[i] is _LineRow)
            const SizedBox(height: AppSpacing.sm),
          rows[i],
        ],
      ],
    );
    if (!bordered) return column;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.lg,
        14,
        AppSpacing.lg,
        14,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
      ),
      child: column,
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.label,
    required this.amount,
    required this.muted,
  });

  final String label;
  final String amount;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = muted ? p.textSecondary : p.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(color: color),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          amount,
          style: AppTypography.amountSmall.copyWith(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
