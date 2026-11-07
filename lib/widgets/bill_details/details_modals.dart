import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:split_bill_app/widgets/feedback/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart'
    show minorFromAny;
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_breakdown_card.dart';
import 'package:split_bill_app/widgets/bill_details/bill_details_header.dart';
import 'package:split_bill_app/widgets/bill_details/participant_tile.dart';
import 'package:split_bill_app/widgets/money_text.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

/// One line of the whole-bill sheet (item or charge), in minor units.
class BillLine {
  const BillLine({
    required this.label,
    required this.amountMinor,
    this.muted = false,
  });

  final String label;
  final int amountMinor;
  final bool muted;
}

/// Items then charges of the whole bill, read through [BillReader] so 1.x
/// docs (doubles) and 2.0 docs (minor units) read the same. The lines sum
/// to the items subtotal plus charges minus discount.
List<BillLine> wholeBillLines(BillReader reader) {
  final lines = <BillLine>[];
  for (final item in reader.items) {
    final qty = (item['qty'] as num?)?.round() ?? 1;
    final name = item['name']?.toString().trim() ?? '';
    final label = name.isEmpty ? 'bf_bill_item_unnamed'.tr() : name;
    lines.add(
      BillLine(
        label: qty > 1
            ? 'bf_bill_line_item_qty'.tr(
                namedArgs: {'item': label, 'qty': '$qty'},
              )
            : label,
        amountMinor: reader.itemUnitPriceMinor(item) * (qty < 1 ? 1 : qty),
      ),
    );
  }
  void charge(String key, String minorKey, String legacyKey) {
    final v = reader.chargeMinor(minorKey, legacyKey);
    if (v != 0) {
      lines.add(BillLine(label: key.tr(), amountMinor: v, muted: true));
    }
  }

  charge('receipt_tax', 'tax', 'taxAmount');
  charge('receipt_service_charge', 'service', 'serviceCharge');
  charge('receipt_tip', 'tip', 'tipAmount');
  charge('receipt_delivery_fee', 'delivery', 'deliveryFeeAmount');
  final other = reader.charges['otherCharges'];
  if (other is List) {
    for (final c in other) {
      if (c is! Map) continue;
      final amount = c['amountMinor'] is num
          ? (c['amountMinor'] as num).round()
          : minorFromAny(c['amount'], reader.currency);
      if (amount == 0) continue;
      final label = c['label']?.toString().trim() ?? '';
      lines.add(
        BillLine(
          label: label.isEmpty ? 'receipt_other_charge_label'.tr() : label,
          amountMinor: amount,
          muted: true,
        ),
      );
    }
  }
  final discount = reader.chargeMinor('discount', 'discountAmount');
  if (discount != 0) {
    lines.add(
      BillLine(
        label: 'receipt_discount'.tr(),
        amountMinor: -discount.abs(),
        muted: true,
      ),
    );
  }
  return lines;
}

class BillDetailsModals {
  BillDetailsModals._();

  /// Whole bill: every item and charge, and the grand total.
  static Future<void> showFullBillDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final reader = BillReader(data);
    final currency = reader.currency;
    final lines = wholeBillLines(reader);
    final p = context.palette;
    final store = data['storeName']?.toString().trim();
    return PremiumBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            (store == null || store.isEmpty)
                ? 'bf_bill_full_title'.tr()
                : store,
            style: AppTypography.headlineSmall.copyWith(color: p.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final line in lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.label,
                              style: AppTypography.bodyMedium.copyWith(
                                color: line.muted
                                    ? p.textSecondary
                                    : p.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            formatMoneyMinor(
                              line.amountMinor,
                              currency,
                              showSymbol: false,
                            ),
                            style: AppTypography.amountSmall.copyWith(
                              fontSize: 14,
                              color: line.muted
                                  ? p.textSecondary
                                  : p.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Divider(height: AppSpacing.xl, color: p.borderSubtle),
          Row(
            children: [
              Expanded(
                child: Text(
                  'grand_total'.tr(),
                  style: AppTypography.titleSmall.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              MoneyText(
                minor: reader.totalMinor,
                currency: currency,
                tone: MoneyTone.neutral,
                size: MoneySize.row,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          BillPillButton(
            label: 'bf_bill_done'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// One person's exact breakdown (same numbers they see).
  static Future<void> showUserShareDetails(
    BuildContext context,
    Map<String, dynamic> participant,
    Map<String, dynamic> billData,
  ) {
    final reader = BillReader(billData);
    final id = participant['id']?.toString() ?? '';
    final name = participant['name']?.toString() ?? '';
    final p = context.palette;
    return PremiumBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BillAvatar(
                name: name,
                photoUrl: participant['photoUrl']?.toString(),
                tintKey: id,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'bf_bill_breakdown_for'.tr(namedArgs: {'name': name}),
                  style: AppTypography.titleLarge.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Flexible(
            child: SingleChildScrollView(
              child: BillBreakdownCard(
                breakdown: reader.breakdownFor(id),
                currency: reader.currency,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BillPillButton(
            label: 'bf_bill_done'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Full-size proof with Confirm.
  static Future<void> showProof(
    BuildContext context, {
    required String name,
    required Uint8List image,
    required VoidCallback onConfirm,
  }) {
    final p = context.palette;
    return showDialog<void>(
      context: context,
      barrierColor: p.scrim,
      builder: (dialogContext) => Dialog(
        backgroundColor: p.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        child: Padding(
          padding: AppSpacing.allLg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'bf_bill_proof_from'.tr(namedArgs: {'name': name}),
                style: AppTypography.titleMedium.copyWith(color: p.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(
                child: ClipRRect(
                  borderRadius: AppRadii.rowRadius,
                  child: InteractiveViewer(
                    child: Image.memory(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Padding(
                        padding: AppSpacing.allXl,
                        child: Text(
                          'bf_bill_proof_unreadable'.tr(),
                          style: AppTypography.bodyMedium.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              BillPillButton(
                label: 'bf_bill_proof_confirm_paid'.tr(),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  onConfirm();
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              BillPillButton(
                label: 'common_cancel'.tr(),
                ghost: true,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Destructive confirmation. Resolves true when confirmed.
  static Future<bool> confirmDelete(BuildContext context) async {
    return showAppDialog(
      context,
      icon: AppIcons.delete,
      title: 'bf_bill_delete_title'.tr(),
      message: 'bf_bill_delete_message'.tr(),
      confirmLabel: 'bf_bill_delete_confirm'.tr(),
      destructive: true,
    );
  }
}
