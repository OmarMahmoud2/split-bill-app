import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Host hero: "Sea Breeze Grill · 4 Nov · Dahab trip", the bill total, and
/// "EGP 7.56 collected of 54.18 owed to you" over a teal progress bar.
class BillSummaryWidget extends StatelessWidget {
  const BillSummaryWidget({
    super.key,
    required this.metaLine,
    required this.totalMinor,
    required this.currency,
    required this.summary,
  });

  final String metaLine;
  final int totalMinor;
  final String currency;
  final CollectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final collectedText = formatMoneyMinor(summary.collectedMinor, currency);
    final owedText = formatMoneyMinor(
      summary.owedMinor,
      currency,
      showSymbol: false,
    );
    final Widget status;
    if (summary.owedMinor <= 0) {
      status = Text(
        'bf_bill_nothing_owed'.tr(),
        style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
      );
    } else if (summary.allSettled) {
      status = Text(
        'bf_bill_all_paid'.tr(),
        style: AppTypography.bodyMedium.copyWith(
          color: p.accent,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      status = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'bf_bill_collected'.tr(
                namedArgs: {'amount': collectedText},
              ),
              style: TextStyle(color: p.accent, fontWeight: FontWeight.w700),
            ),
            const TextSpan(text: ' '),
            TextSpan(
              text: 'bf_bill_of_owed'.tr(namedArgs: {'amount': owedText}),
              style: TextStyle(color: p.textSecondary),
            ),
          ],
        ),
        style: AppTypography.bodyMedium,
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metaLine,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: 2),
          MoneyText(
            minor: totalMinor,
            currency: currency,
            tone: MoneyTone.neutral,
            size: MoneySize.hero,
            style: const TextStyle(fontSize: 40),
            animate: true,
            semanticsLabel: 'bf_bill_total_semantics'.tr(
              namedArgs: {'amount': formatMoneyMinor(totalMinor, currency)},
            ),
          ),
          const SizedBox(height: 2),
          Semantics(container: true, child: status),
          if (summary.owedMinor > 0) ...[
            const SizedBox(height: 14),
            CollectedProgressBar(progress: summary.progress),
          ],
        ],
      ),
    );
  }
}

/// The 8 px teal bar under the collected line.
class CollectedProgressBar extends StatelessWidget {
  const CollectedProgressBar({super.key, required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final value = progress.clamp(0.0, 1.0);
    return Semantics(
      label: 'bf_bill_progress_semantics'.tr(
        namedArgs: {'percent': '${(value * 100).floor()}'},
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 8,
          color: p.hairline,
          alignment: AlignmentDirectional.centerStart,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: AppMotion.durationFor(context, AppMotion.money),
            curve: AppMotion.quiet,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: ColoredBox(color: p.accent),
            ),
          ),
        ),
      ),
    );
  }
}
