import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';
import 'package:split_bill_app/widgets/money_text.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';

/// Host hero: "Sea Breeze Grill · 4 Nov · Dahab trip", the bill total, and
/// "EGP 7.56 collected of 54.18 owed to you" over a teal progress bar.
class BillSummaryWidget extends StatelessWidget {
  const BillSummaryWidget({
    super.key,
    required this.metaLine,
    required this.totalMinor,
    required this.currency,
    required this.summary,
    this.title,
    this.paidByName,
    this.paidByPhotoUrl,
    this.paidById,
  });

  /// Bill title shown beside the icon tile (the meta line is then the date).
  final String? title;

  /// Who paid the bill, with avatar.
  final String? paidByName;
  final String? paidByPhotoUrl;
  final String? paidById;

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
          if (title != null)
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(AppIcons.receipt, color: p.onAccentSoft),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLarge.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        metaLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              metaLine,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
          const SizedBox(height: 10),
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
          if (paidByName != null && paidByName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                PalAvatar(
                  seed: paidById ?? paidByName!.toLowerCase(),
                  name: paidByName,
                  photoUrl: paidByPhotoUrl,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'bd2_pdf_paid_by'.tr(namedArgs: {'name': paidByName!}),
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (summary.people > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 4),
              child: Text(
                'bd2_paid_count'.tr(
                  namedArgs: {
                    'paid': '${summary.paidPeople}',
                    'total': '${summary.people}',
                  },
                ),
                style: AppTypography.titleSmall.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Semantics(container: true, child: status),
          if (summary.owedMinor > 0) ...[
            const SizedBox(height: 10),
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
