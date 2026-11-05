import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_breakdown_card.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';

/// Sentence for one history entry, without the author ("changed Kunafa
/// from 6.00 to 7.00").
String historyChangeText(BillHistoryEntry entry, String currency) {
  String money(Object? v) => v is num
      ? formatMoneyMinor(v.round(), currency, showSymbol: false)
      : (v?.toString() ?? '');
  final a = entry.args;
  return historyChangeKey(entry.change).tr(
    namedArgs: {
      'item': a['item']?.toString() ?? '',
      'name': a['name']?.toString() ?? '',
      'from': entry.change == 'item_price'
          ? money(a['from'])
          : '${a['from'] ?? ''}',
      'to': entry.change == 'item_price' ? money(a['to']) : '${a['to'] ?? ''}',
    },
  );
}

/// "HISTORY" card: who changed what, newest first.
class BillHistoryCard extends StatelessWidget {
  const BillHistoryCard({
    super.key,
    required this.entries,
    required this.currency,
    required this.currentUid,
    required this.now,
    this.maxEntries = 5,
  });

  final List<BillHistoryEntry> entries;
  final String currency;
  final String? currentUid;
  final DateTime now;
  final int maxEntries;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shown = entries.take(maxEntries).toList();
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < shown.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: shown[i].by == currentUid
                        ? 'bf_bill_history_you'.tr()
                        : (shown[i].byName?.trim().isNotEmpty == true
                              ? shown[i].byName!
                              : 'bf_bill_history_someone'.tr()),
                    style: TextStyle(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text:
                        ' ${historyChangeText(shown[i], currency)} · '
                        '${resolveCopy(relativeTimeCopy(shown[i].at, now))}',
                    style: TextStyle(color: p.textSecondary),
                  ),
                ],
              ),
              style: AppTypography.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
