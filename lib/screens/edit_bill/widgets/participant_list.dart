import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Round avatar: the photo when there is one, else the initial on a
/// stable tint.
class EditAvatar extends StatelessWidget {
  const EditAvatar({
    super.key,
    required this.id,
    required this.name,
    this.photoUrl,
    this.size = 36,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final image = ImageUtils.getAvatarImage(photoUrl);
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: p.avatarTintFor(id.isEmpty ? name : id),
          image: image == null
              ? null
              : DecorationImage(image: image, fit: BoxFit.cover),
        ),
        child: image == null
            ? Text(
                initial,
                style: AppTypography.labelSmall.copyWith(
                  color: p.textPrimary,
                  fontSize: size * 0.36,
                ),
              )
            : null,
      ),
    );
  }
}

/// A hairline card, the v3 container for grouped rows.
class EditCard extends StatelessWidget {
  const EditCard({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, thickness: 1, color: p.borderSubtle));
      }
      rows.add(children[i]);
    }
    return Material(
      color: p.surface,
      shape: AppRadii.cardShape(p.border),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// Small status chip ("Paid", "Not yet").
class EditStatusChip extends StatelessWidget {
  const EditStatusChip({super.key, required this.paid});

  final bool paid;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: paid ? p.owedSoft : p.oweSoft,
        borderRadius: AppRadii.chipRadius,
      ),
      child: Text(
        (paid ? 'bf_edit_status_paid' : 'bf_edit_status_not_yet').tr(),
        style: AppTypography.labelSmall.copyWith(
          color: paid ? p.owedInk : p.oweInk,
        ),
      ),
    );
  }
}

/// The people on the bill with their recomputed share and payment status.
class ParticipantList extends StatelessWidget {
  const ParticipantList({
    super.key,
    required this.participants,
    required this.sharesMinor,
    required this.currency,
    required this.paidIds,
    required this.hostId,
    required this.onParticipantTap,
    this.currentUid,
  });

  final List<BillParticipantInfo> participants;
  final Map<String, int> sharesMinor;
  final String currency;
  final Set<String> paidIds;
  final String hostId;
  final String? currentUid;
  final ValueChanged<String> onParticipantTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return EditCard(
      children: [
        for (final person in participants)
          InkWell(
            onTap: () => onParticipantTap(person.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    EditAvatar(
                      id: person.id,
                      name: person.name,
                      photoUrl: person.photoUrl,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.id == currentUid
                                ? 'bf_edit_you_name'.tr(
                                    namedArgs: {'name': person.name},
                                  )
                                : person.name,
                            style: AppTypography.titleMedium.copyWith(
                              color: p.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (person.id == hostId)
                            Text(
                              'bf_edit_paid_the_bill'.tr(),
                              style: AppTypography.bodySmall.copyWith(
                                color: p.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    EditStatusChip(paid: paidIds.contains(person.id)),
                    const SizedBox(width: AppSpacing.md),
                    MoneyText(
                      minor: sharesMinor[person.id] ?? 0,
                      currency: currency,
                      tone: MoneyTone.neutral,
                      animate: true,
                      animateFromZero: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
