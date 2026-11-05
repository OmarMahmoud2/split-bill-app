import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';

/// Major-unit double from older screens -> exact minor units.
int _minor(double amount, String currency) =>
    toMinorUnits(amount, normalizeCurrency(currency));

/// A label / amount row of the summary. Amounts use the currency's real
/// decimals (never one decimal) in tabular Inter Tight.
class BillSummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final double fontSize;
  final bool isPrimary;
  final String currency;

  const BillSummaryRow({
    super.key,
    required this.label,
    required this.amount,
    this.isBold = false,
    this.fontSize = 16,
    this.isPrimary = false,
    this.currency = "USD",
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final weight = isBold ? FontWeight.w600 : FontWeight.w400;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: fontSize,
              fontWeight: weight,
              color: isPrimary ? p.textPrimary : p.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(
          formatMoneyMinor(_minor(amount, currency), currency),
          style: AppTypography.amountSmall.copyWith(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: isPrimary ? p.accent : p.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// A participant's share on the summary screen: avatar, name, amount.
class ParticipantShareCard extends StatelessWidget {
  final Map<String, dynamic> participant;
  final double share;
  final bool isWinner;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final ImageProvider? Function(String?) getAvatarImage;
  final String currency;

  const ParticipantShareCard({
    super.key,
    required this.participant,
    required this.share,
    required this.isWinner,
    required this.onTap,
    this.onEdit,
    required this.getAvatarImage,
    this.currency = "USD",
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = participant['name']?.toString() ?? '';
    final id = participant['id']?.toString() ?? name;
    final image = getAvatarImage(participant['photoUrl']?.toString());
    final initial = name.isEmpty
        ? '?'
        : String.fromCharCodes(name.runes.take(1)).toUpperCase();
    return Material(
      color: p.surface,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: p.hairline),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: p.avatarTintFor(id),
                backgroundImage: image,
                child: image == null
                    ? Text(
                        initial,
                        style: AppTypography.labelMedium.copyWith(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: AppTypography.titleSmall.copyWith(
                              color: p.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isWinner) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.oweSoft,
                              borderRadius: AppRadii.chipRadius,
                            ),
                            child: Text(
                              'big_loser'.tr(),
                              style: AppTypography.labelSmall.copyWith(
                                color: p.oweInk,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'view_details'.tr(),
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoneyMinor(_minor(share, currency), currency),
                    style: AppTypography.amount.copyWith(color: p.textPrimary),
                  ),
                  if (onEdit != null)
                    InkWell(
                      onTap: onEdit,
                      borderRadius: AppRadii.chipRadius,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                          horizontal: AppSpacing.xs,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded, size: 13, color: p.accent),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              'common_edit'.tr(),
                              style: AppTypography.labelSmall.copyWith(
                                color: p.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: p.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
