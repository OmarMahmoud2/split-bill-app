/// Minor-unit totals for the scan review screen, built from what is in the
/// edit fields right now.
library;

import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/screens/scan_receipt/amount_input.dart';

/// One item row as typed.
typedef ReviewLine = ({String name, String qty, String price});

/// The charge fields as typed.
typedef ReviewChargeTexts = ({
  String tax,
  String service,
  String tip,
  String delivery,
  String discount,
});

/// A [BillDraft] (no participants yet) for the review screen. Rows with no
/// name are left out, unreadable amounts count as zero, other charges come
/// from [receiptData].
BillDraft buildReviewDraft({
  required Map<String, dynamic> receiptData,
  required String currency,
  required List<ReviewLine> lines,
  required ReviewChargeTexts charges,
}) {
  final code = normalizeCurrency(currency);
  final items = <Map<String, dynamic>>[
    for (final line in lines)
      if (line.name.trim().isNotEmpty)
        {
          'name': line.name.trim(),
          'qty': parseQuantityInput(line.qty) ?? 1,
          'priceMinor': parseMinorInput(line.price, code) ?? 0,
        },
  ];
  final draft = draftFromReceipt(
    receiptData: {...receiptData, 'items': items},
    participantIds: const [],
    currency: code,
  );
  int amount(String text) => parseMinorInput(text, code) ?? 0;
  return draft.copyWith(
    taxMinor: amount(charges.tax),
    serviceMinor: amount(charges.service),
    tipMinor: amount(charges.tip),
    deliveryMinor: amount(charges.delivery),
    discountMinor: amount(charges.discount),
  );
}

/// Writes [draft]'s totals back into [receiptData] in the legacy double
/// fields SplitBillScreen reads (plus `totalMinor` / `currency`).
void writeReviewTotals(Map<String, dynamic> receiptData, BillDraft draft) {
  final c = draft.currency;
  double major(int minor) => fromMinorUnits(minor, c);
  receiptData['subtotal'] = major(draft.itemsSubtotalMinor);
  receiptData['tax_amount'] = major(draft.taxMinor);
  receiptData['service_charge'] = major(draft.serviceMinor);
  receiptData['tip_amount'] = major(draft.tipMinor);
  receiptData['delivery_fee'] = major(draft.deliveryMinor);
  receiptData['discount_amount'] = major(draft.discountMinor);
  receiptData['total_amount'] = major(draft.grandTotalMinor);
  receiptData['totalMinor'] = draft.grandTotalMinor;
  receiptData['currency'] = c;
}

/// [part] as a share of [whole] in percent, for labels like "Tax 14%".
/// Whole numbers print bare, others with one decimal; `null` when [whole]
/// or [part] is zero.
String? percentLabel(int part, int whole) {
  if (whole <= 0 || part <= 0) return null;
  final tenths = (part * 1000 / whole).round();
  if (tenths % 10 == 0) return '${tenths ~/ 10}';
  return '${tenths ~/ 10}.${tenths % 10}';
}
