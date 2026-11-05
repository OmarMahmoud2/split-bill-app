import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';

/// Status pill: Paid (teal soft), Check proof (slate/indigo soft), Not yet
/// (amber soft). The word carries the meaning, the color supports it.
class PayStatusPill extends StatelessWidget {
  const PayStatusPill({super.key, required this.status, this.self = false});

  final PayStatus status;

  /// Participant's own view ("Waiting" instead of "Check proof").
  final bool self;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (bg, ink) = switch (status) {
      PayStatus.paid => (p.accentSoft, p.onAccentSoft),
      PayStatus.review => (p.infoSoft, p.infoStrong),
      PayStatus.notYet => (p.oweSoft, p.oweInk),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadii.chipRadius),
      child: Text(
        (self ? status.selfLabelKey : status.labelKey).tr(),
        style: AppTypography.labelSmall.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Round avatar: photo when there is one, else initials on a stable tint.
class BillAvatar extends StatelessWidget {
  const BillAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.tintKey,
    this.size = 36,
  });

  final String name;
  final String? photoUrl;
  final String? tintKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final image = ImageUtils.getAvatarImage(photoUrl);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.avatarTintFor(tintKey ?? name),
          image: image == null
              ? null
              : DecorationImage(image: image, fit: BoxFit.cover),
        ),
        child: image == null
            ? Text(
                initialsOf(name),
                style: AppTypography.labelMedium.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }
}

/// One participant row in the host's bill card: avatar, name, share and
/// status pill. Presentational; the screen passes plain values.
class ParticipantTile extends StatelessWidget {
  const ParticipantTile({
    super.key,
    required this.name,
    required this.shareMinor,
    required this.currency,
    required this.status,
    this.photoUrl,
    this.tintKey,
    this.subtitle,
    this.showDivider = false,
    this.onTap,
  });

  final String name;
  final int shareMinor;
  final String currency;
  final PayStatus status;
  final String? photoUrl;
  final String? tintKey;

  /// Extra muted text after the amount ("reminded 3 days ago").
  final String? subtitle;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final amount = formatMoneyMinor(shareMinor, currency);
    final statusText = status.labelKey.tr();
    return Semantics(
      button: onTap != null,
      label: 'bf_bill_row_semantics'.tr(
        namedArgs: {'name': name, 'amount': amount, 'status': statusText},
      ),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          decoration: BoxDecoration(
            border: showDivider
                ? Border(top: BorderSide(color: p.borderSubtle))
                : null,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              BillAvatar(name: name, photoUrl: photoUrl, tintKey: tintKey),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle == null ? amount : '$amount · $subtitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.amountSmall.copyWith(
                        color: p.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              PayStatusPill(status: status),
            ],
          ),
        ),
      ),
    );
  }
}
