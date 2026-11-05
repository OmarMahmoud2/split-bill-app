import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';

import '../guest_bill_model.dart';
import 'guest_chrome.dart';

String guestHostName(GuestBill bill) =>
    bill.hostName.isEmpty ? 'host'.tr() : bill.hostName;

String guestStoreName(GuestBill bill) =>
    bill.storeName.isEmpty ? 'receipt'.tr() : bill.storeName;

String guestAmount(int minor, String currency, {bool symbol = true}) =>
    formatMoneyMinor(minor, currency, showSymbol: symbol);

/// Row label for a breakdown line ("Lemon mint, 1 of 3", "Tax 14%").
String guestLineLabel(GuestLine line, GuestBill bill, {bool withBase = false}) {
  String rated(String rateKey, String plainKey) {
    final rate = line.ratePercent;
    if (rate == null) return plainKey.tr();
    final label = rateKey.tr(namedArgs: {'rate': rate});
    if (!withBase || line.baseMinor == null) return label;
    return 'guest_rate_of'.tr(
      namedArgs: {
        'label': label,
        'base': guestAmount(line.baseMinor!, bill.currency, symbol: false),
      },
    );
  }

  return switch (line.kind) {
    GuestLineKind.item =>
      line.sharedWith > 1
          ? 'guest_item_shared'.tr(
              namedArgs: {
                // Isolate the (often Latin) item name so RTL text keeps
                // "1 of 3" in reading order.
                'item': '\u2068${line.label}\u2069',
                'count': line.sharedWith.toString(),
              },
            )
          : line.label,
    GuestLineKind.tax => rated('guest_tax_rate', 'guest_tax'),
    GuestLineKind.service => rated('guest_service_rate', 'guest_service'),
    GuestLineKind.tip => 'guest_tip'.tr(),
    GuestLineKind.delivery => 'guest_delivery'.tr(),
    GuestLineKind.other =>
      line.label.isNotEmpty ? line.label : 'guest_other_charges'.tr(),
    GuestLineKind.discount => 'guest_discount'.tr(),
    GuestLineKind.adjustment => 'guest_adjustment'.tr(
      namedArgs: {'host': guestHostName(bill)},
    ),
    GuestLineKind.share => 'guest_your_share'.tr(),
  };
}

/// One label/amount row; amounts are tabular and never flip in RTL.
class GuestAmountRow extends StatelessWidget {
  const GuestAmountRow({
    super.key,
    required this.label,
    required this.amount,
    this.muted = false,
    this.bold = false,
    this.fontSize = 14,
  });

  final String label;
  final String amount;
  final bool muted;
  final bool bold;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = muted ? p.textSecondary : p.textPrimary;
    final weight = bold ? FontWeight.w700 : FontWeight.w400;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: fontSize,
                color: color,
                fontWeight: weight,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            amount,
            textDirection: TextDirection.ltr,
            style: AppTypography.amountSmall.copyWith(
              fontSize: fontSize,
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Phone breakdown card: the lines, then "See the whole receipt".
class GuestBreakdownCard extends StatelessWidget {
  const GuestBreakdownCard({
    super.key,
    required this.bill,
    required this.breakdown,
  });

  final GuestBill bill;
  final GuestBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GuestCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final line in breakdown.lines) ...[
            GuestAmountRow(
              label: guestLineLabel(line, bill),
              amount: guestAmount(
                line.amountMinor,
                breakdown.currency,
                symbol: false,
              ),
              muted: line.isMuted,
            ),
            const SizedBox(height: 8),
          ],
          if (bill.items.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: p.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppTypography.labelLarge.copyWith(fontSize: 13),
                ),
                onPressed: () => showGuestReceipt(context, bill),
                child: Text('guest_see_receipt'.tr()),
              ),
            ),
        ],
      ),
    );
  }
}

/// Desktop "What you had" table with a total row.
class GuestBreakdownTable extends StatelessWidget {
  const GuestBreakdownTable({
    super.key,
    required this.bill,
    required this.breakdown,
  });

  final GuestBill bill;
  final GuestBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget row(Widget child, {bool strong = false}) => DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: strong ? p.border : p.borderSubtle),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: strong ? 12 : 10,
        ),
        child: child,
      ),
    );
    return GuestCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
            child: Text(
              'guest_what_you_had'.tr(),
              style: AppTypography.titleSmall.copyWith(
                fontSize: 15,
                color: p.textPrimary,
              ),
            ),
          ),
          for (final line in breakdown.lines)
            row(
              GuestAmountRow(
                label: guestLineLabel(line, bill, withBase: true),
                amount: guestAmount(
                  line.amountMinor,
                  breakdown.currency,
                  symbol: false,
                ),
                muted: line.isMuted,
                fontSize: 15,
              ),
            ),
          row(
            GuestAmountRow(
              label: 'guest_total'.tr(),
              amount: guestAmount(breakdown.totalMinor, breakdown.currency),
              bold: true,
              fontSize: 15,
            ),
            strong: true,
          ),
        ],
      ),
    );
  }
}

/// Every item on the receipt and who had it.
Future<void> showGuestReceipt(BuildContext context, GuestBill bill) {
  final names = {for (final p in bill.participants) p.id: p.name};
  Widget content(BuildContext c) {
    final p = c.palette;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              guestStoreName(bill),
              style: AppTypography.headlineMedium.copyWith(
                color: p.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'guest_receipt_title'.tr(),
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                for (final item in bill.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GuestAmountRow(
                          label: item.quantity > 1
                              ? '${item.quantity} × ${item.name}'
                              : item.name,
                          amount: guestAmount(
                            item.lineTotal,
                            bill.currency,
                            symbol: false,
                          ),
                          fontSize: 15,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.assignees.isEmpty
                              ? 'guest_receipt_unassigned'.tr()
                              : item.assignees
                                    .map((id) => names[id] ?? '?')
                                    .join(', '),
                          style: AppTypography.bodySmall.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                Divider(color: p.border, height: 24),
                GuestAmountRow(
                  label: 'guest_total'.tr(),
                  amount: guestAmount(bill.displayTotalMinor, bill.currency),
                  bold: true,
                  fontSize: 15,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
          child: content(c),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    builder: content,
  );
}
