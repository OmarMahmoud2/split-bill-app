import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_logic.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Round avatar: photo when there is one, else the initial on the person's
/// palette tint.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.participant, this.size = 40});

  /// Legacy participant map (`id`, `name`, `photoUrl`).
  final Map<String, dynamic> participant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return PalAvatar(
      seed: (participant['id'] ?? participant['name'] ?? '')
          .toString()
          .toLowerCase(),
      name: participant['name']?.toString(),
      photoUrl: participant['photoUrl']?.toString(),
      size: size,
    );
  }
}

/// One person in the live totals strip: avatar + their preview total.
class PersonTotalCard extends StatelessWidget {
  const PersonTotalCard({
    super.key,
    required this.participant,
    required this.amountMinor,
    required this.currency,
    this.highlighted = false,
    this.onTap,
    this.onLongPress,
  });

  final Map<String, dynamic> participant;
  final int amountMinor;
  final String currency;

  /// On the item being assigned right now.
  final bool highlighted;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = (participant['name'] ?? '').toString();
    final amount = formatMoneyMinor(amountMinor, currency);
    return Semantics(
      button: onTap != null,
      selected: highlighted,
      label: 'bf_assign_person_total_semantics'.tr(
        namedArgs: {'name': name, 'amount': amount},
      ),
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardRadius,
          side: BorderSide(
            color: highlighted ? p.accent : p.border,
            width: highlighted ? 1.5 : AppRadii.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PersonAvatar(participant: participant, size: 32),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: MoneyText(
                      minor: amountMinor,
                      currency: currency,
                      tone: MoneyTone.neutral,
                      size: MoneySize.small,
                      showSymbol: false,
                      animate: true,
                      animateFromZero: false,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip of per-person totals under the header. Four or fewer people
/// share the width; more scroll sideways.
class PersonTotalsStrip extends StatelessWidget {
  const PersonTotalsStrip({
    super.key,
    required this.participants,
    required this.totals,
    required this.currency,
    this.highlightedIds = const {},
    this.onPersonTap,
    this.onPersonLongPress,
    this.onAddPeople,
  });

  final List<Map<String, dynamic>> participants;
  final Map<String, int> totals;
  final String currency;
  final Set<String> highlightedIds;
  final ValueChanged<Map<String, dynamic>>? onPersonTap;
  final ValueChanged<Map<String, dynamic>>? onPersonLongPress;
  final VoidCallback? onAddPeople;

  @override
  Widget build(BuildContext context) {
    Widget card(Map<String, dynamic> person) {
      final id = person['id'].toString();
      return PersonTotalCard(
        key: ValueKey('bf_assign_total_$id'),
        participant: person,
        amountMinor: totals[id] ?? 0,
        currency: currency,
        highlighted: highlightedIds.contains(id),
        onTap: onPersonTap == null ? null : () => onPersonTap!(person),
        onLongPress: onPersonLongPress == null
            ? null
            : () => onPersonLongPress!(person),
      );
    }

    final add = onAddPeople == null
        ? null
        : _AddPersonCard(onTap: onAddPeople!);
    final count = participants.length + (add == null ? 0 : 1);
    if (count <= 5) {
      return Row(
        children: [
          for (var i = 0; i < participants.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: card(participants[i])),
          ],
          if (add != null) ...[
            if (participants.isNotEmpty) const SizedBox(width: AppSpacing.sm),
            SizedBox(width: 56, child: add),
          ],
        ],
      );
    }
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => i < participants.length
            ? SizedBox(width: 76, child: card(participants[i]))
            : SizedBox(width: 56, child: add),
      ),
    );
  }
}

class _AddPersonCard extends StatelessWidget {
  const _AddPersonCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'add_people'.tr(),
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: AppRadii.cardShape(p.border),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Icon(AppIcons.personAdd, color: p.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// A person on an item: tinted pill with the first name (and units).
class AssigneeChip extends StatelessWidget {
  const AssigneeChip({super.key, required this.participant, this.units});

  final Map<String, dynamic> participant;

  /// Units taken, for per-unit items; shown when more than one.
  final int? units;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final id = participant['id'].toString();
    final name = firstNameOf(participant['name']);
    final label = (units ?? 0) > 1
        ? 'bf_assign_chip_units'.tr(
            namedArgs: {'name': name, 'count': units.toString()},
          )
        : name;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.avatarTintFor(id),
        borderRadius: AppRadii.fullRadius,
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

/// A tappable face in the active row's picker.
class AssignFaceToggle extends StatelessWidget {
  const AssignFaceToggle({
    super.key,
    required this.participant,
    required this.selected,
    required this.onTap,
    this.units,
  });

  final Map<String, dynamic> participant;
  final bool selected;
  final VoidCallback onTap;
  final int? units;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = firstNameOf(participant['name']);
    return Semantics(
      button: true,
      toggled: selected,
      label: (units ?? 0) > 1
          ? 'bf_assign_chip_units'.tr(
              namedArgs: {'name': name, 'count': units.toString()},
            )
          : name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rowRadius,
        child: SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.durationFor(context, AppMotion.fast),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? p.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: PersonAvatar(participant: participant, size: 36),
                    ),
                    if (selected)
                      PositionedDirectional(
                        end: -2,
                        bottom: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.surface, width: 1.5),
                          ),
                          child: (units ?? 0) > 1
                              ? Text(
                                  units.toString(),
                                  style: AppTypography.labelSmall.copyWith(
                                    fontSize: 10,
                                    color: p.onAccent,
                                    letterSpacing: 0,
                                  ),
                                )
                              : Icon(
                                  AppIcons.check,
                                  size: 12,
                                  color: p.onAccent,
                                ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    color: selected ? p.textPrimary : p.textSecondary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One receipt line on the assignment screen: name, price, the people on it
/// (chips that hop in), a short note, and, while [active], a face picker.
class AssignItemRow extends StatelessWidget {
  const AssignItemRow({
    super.key,
    required this.item,
    required this.state,
    required this.participants,
    required this.currency,
    this.active = false,
    this.showTopBorder = true,
    this.onTap,
    this.onLongPress,
    this.onFaceTap,
    this.onEveryone,
    this.onAdjustUnits,
  });

  final DraftItem item;
  final ItemAssignmentState state;
  final List<Map<String, dynamic>> participants;
  final String currency;
  final bool active;
  final bool showTopBorder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<String>? onFaceTap;
  final VoidCallback? onEveryone;

  /// Opens the per-unit sheet (quantity items only).
  final VoidCallback? onAdjustUnits;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final note = itemNoteFor(state);
    final noteKey = note.key;
    final byId = {for (final x in participants) x['id'].toString(): x};
    final assigned = [
      for (final id in state.people)
        if (byId[id] != null) byId[id]!,
    ];
    final title = item.quantity > 1
        ? 'bf_assign_item_qty'.tr(
            namedArgs: {'name': item.name, 'qty': item.quantity.toString()},
          )
        : item.name;
    final background = note.needsAttention
        ? p.oweSoft
        : active
        ? p.surfaceVariant
        : p.surface;

    return AnimatedContainer(
      duration: AppMotion.durationFor(context, AppMotion.medium),
      decoration: BoxDecoration(
        color: background,
        border: showTopBorder
            ? Border(top: BorderSide(color: p.borderSubtle))
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    MoneyText(
                      minor: item.lineTotalMinor,
                      currency: currency,
                      tone: MoneyTone.neutral,
                      size: MoneySize.small,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final person in assigned)
                      AvatarHop(
                        key: ValueKey('bf_assign_chip_${person['id']}'),
                        child: AssigneeChip(
                          participant: person,
                          units: state.unitAssignments[person['id']],
                        ),
                      ),
                    if (noteKey != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          noteKey.tr(namedArgs: {'count': '${note.count}'}),
                          style: AppTypography.caption.copyWith(
                            fontSize: 12,
                            color: note.needsAttention
                                ? p.oweInk
                                : p.textSecondary,
                            fontWeight: note.needsAttention
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                if (active) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final person in participants)
                        AssignFaceToggle(
                          key: ValueKey('bf_assign_face_${person['id']}'),
                          participant: person,
                          selected: state.people.contains(
                            person['id'].toString(),
                          ),
                          units: state.unitAssignments[person['id']],
                          onTap: () => onFaceTap?.call(person['id'].toString()),
                        ),
                    ],
                  ),
                  if (onEveryone != null || onAdjustUnits != null)
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        if (onEveryone != null)
                          _RowAction(
                            icon: AppIcons.groups,
                            label: 'bf_assign_everyone'.tr(),
                            onTap: onEveryone!,
                          ),
                        if (onAdjustUnits != null)
                          _RowAction(
                            icon: AppIcons.filter,
                            label: 'bf_assign_adjust_units'.tr(),
                            onTap: onAdjustUnits!,
                          ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: p.primaryStrong,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: AppTypography.labelMedium.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
