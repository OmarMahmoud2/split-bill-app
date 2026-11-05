import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/screens/edit_bill/history_format.dart';
import 'package:split_bill_app/theme/theme.dart';

/// The HISTORY card of the edit screen: "**You** changed Kunafa from 6.00
/// to 7.00 · 2 h ago", newest first. Purely presentational.
class BillHistoryCard extends StatelessWidget {
  const BillHistoryCard({
    super.key,
    required this.entries,
    required this.currentUid,
    required this.currency,
    this.now,
    this.maxEntries = 10,
    this.translate = trTranslate,
  });

  final List<BillHistoryEntry> entries;
  final String? currentUid;
  final String currency;

  /// Clock for relative times (tests pass a fixed one).
  final DateTime? now;
  final int maxEntries;
  final Translate translate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final locale = (Localizations.maybeLocaleOf(context) ?? const Locale('en'))
        .toLanguageTag();
    final clock = now ?? DateTime.now();
    final shown = entries.take(maxEntries).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.border),
      ),
      child: shown.isEmpty
          ? Text(
              translate('bf_edit_history_empty', const {}),
              style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _line(context, shown[i], clock, locale),
                ],
              ],
            ),
    );
  }

  Widget _line(
    BuildContext context,
    BillHistoryEntry entry,
    DateTime clock,
    String locale,
  ) {
    final p = context.palette;
    final line = describeHistoryEntry(
      entry,
      currentUid: currentUid,
      currency: currency,
      translate: translate,
      locale: locale,
    );
    final when = relativeTimeLabel(
      entry.at,
      clock,
      translate: translate,
      locale: locale,
    );
    final base = AppTypography.bodySmall;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: line.author,
            style: base.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: ' ${line.action} · $when',
            style: base.copyWith(color: p.textSecondary),
          ),
        ],
      ),
    );
  }
}
