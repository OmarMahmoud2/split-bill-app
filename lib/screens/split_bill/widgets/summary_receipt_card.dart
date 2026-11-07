import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// The bill as a receipt: store, items, charges (dashed dividers) and the
/// total in big tabular Plus Jakarta figures. The total is keyed
/// `summary_total` for tests.
class SummaryReceiptCard extends StatelessWidget {
  const SummaryReceiptCard({
    super.key,
    required this.draft,
    required this.storeName,
    required this.totalMinor,
  });

  final BillDraft draft;
  final String storeName;

  /// Grand total from `computeBill`.
  final int totalMinor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cur = draft.currency;

    Widget line(
      String label,
      int minor, {
      String? note,
      bool minus = false,
      bool strong = false,
    }) {
      final style = AppTypography.bodyMedium.copyWith(
        color: strong ? p.textPrimary : p.textSecondary,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: style),
                  if (note != null)
                    Text(
                      note,
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textTertiary,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${minus ? '−' : ''}${formatMoneyMinor(minor, cur)}',
              style: AppTypography.amount.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: AppTypography.tabularFigures,
                color: strong ? p.textPrimary : p.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final charges = <Widget>[
      if (draft.taxMinor > 0) line('receipt_tax'.tr(), draft.taxMinor),
      if (draft.serviceMinor > 0)
        line('receipt_service_charge'.tr(), draft.serviceMinor),
      if (draft.tipMinor > 0) line('receipt_tip'.tr(), draft.tipMinor),
      if (draft.deliveryMinor > 0)
        line('receipt_delivery_fee'.tr(), draft.deliveryMinor),
      for (final c in draft.otherCharges)
        if (c.amountMinor > 0)
          line(
            c.label.isEmpty ? 'receipt_other_charge_label'.tr() : c.label,
            c.amountMinor,
          ),
      if (draft.discountMinor > 0)
        line('receipt_discount'.tr(), draft.discountMinor, minus: true),
    ];

    return Container(
      key: const ValueKey('summary_receipt'),
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.hairline),
        boxShadow: p.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(AppIcons.receipt, size: 20, color: p.textSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  storeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (draft.items.isNotEmpty) ...[
            _DashedDivider(color: p.borderStrong),
            for (final item in draft.items)
              line(
                item.name,
                item.lineTotalMinor,
                strong: true,
                note: item.quantity > 1
                    ? '${item.quantity} × ${formatMoneyMinor(item.unitPriceMinor, cur)}'
                    : null,
              ),
          ],
          if (charges.isNotEmpty) ...[
            _DashedDivider(color: p.borderStrong),
            ...charges,
          ],
          _DashedDivider(color: p.borderStrong),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'receipt_total'.tr(),
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
              ),
              MoneyText(
                key: const ValueKey('summary_total'),
                minor: totalMinor,
                currency: cur,
                size: MoneySize.large,
                tone: MoneyTone.neutral,
                animate: true,
                animateFromZero: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        height: 1,
        width: double.infinity,
        child: CustomPaint(painter: _DashPainter(color)),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 8) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + 4).clamp(0, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}
