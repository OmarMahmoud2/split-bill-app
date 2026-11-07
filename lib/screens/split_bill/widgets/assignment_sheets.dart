import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assign_widgets.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_logic.dart';
import 'package:split_bill_app/theme/theme.dart';

/// Ink pill button (52 high), the v3 primary action.
class AssignPillButton extends StatelessWidget {
  const AssignPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.muted = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Outlined (ghost) variant.
  final bool secondary;

  /// Looks disabled but stays tappable (e.g. "1 item left" explains why).
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bg = secondary
        ? p.surface
        : muted
        ? p.border
        : p.inverseSurface;
    final fg = secondary
        ? p.textPrimary
        : muted
        ? p.textSecondary
        : p.onInverseSurface;
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: p.border,
          disabledForegroundColor: p.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: secondary
                ? BorderSide(color: p.borderStrong, width: 1.5)
                : BorderSide.none,
          ),
          elevation: 0,
          textStyle: AppTypography.labelLarge.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.headlineMedium.copyWith(
                  color: p.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class _PersonName extends StatelessWidget {
  const _PersonName({required this.participant});

  final Map<String, dynamic> participant;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Flexible(
          child: Text(
            (participant['name'] ?? '').toString(),
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
            ),
          ),
        ),
        if (participant['isPro'] == true) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: p.premium,
              borderRadius: AppRadii.chipRadius,
            ),
            child: Text(
              'pro'.tr(),
              style: AppTypography.labelSmall.copyWith(
                fontSize: 10,
                color: p.onPremium,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Who split this item?": pick the people who share a single item equally.
class SimpleAssignmentSheet extends StatefulWidget {
  final List<dynamic> participants;
  final List<String> currentSelection;
  final Function(List<String>) onConfirm;

  /// Shown under the title.
  final String? itemName;

  const SimpleAssignmentSheet({
    super.key,
    required this.participants,
    required this.currentSelection,
    required this.onConfirm,
    this.itemName,
  });

  @override
  State<SimpleAssignmentSheet> createState() => _SimpleAssignmentSheetState();
}

class _SimpleAssignmentSheetState extends State<SimpleAssignmentSheet> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.currentSelection);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final people = [
      for (final x in widget.participants)
        if (x is Map) Map<String, dynamic>.from(x),
    ];
    final allIds = people.map((x) => x['id'].toString()).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(
          title: 'who_split_this_item'.tr(),
          subtitle: widget.itemName,
        ),
        const SizedBox(height: AppSpacing.lg),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: p.border),
              borderRadius: AppRadii.cardRadius,
            ),
            child: ClipRRect(
              borderRadius: AppRadii.cardRadius,
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final person = people[index];
                  final id = person['id'].toString();
                  final selected = _selectedIds.contains(id);
                  return _CheckRow(
                    key: ValueKey('bf_assign_simple_$id'),
                    showTopBorder: index > 0,
                    participant: person,
                    selected: selected,
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedIds.remove(id);
                        } else {
                          _selectedIds.add(id);
                        }
                      });
                      AppHaptics.selection();
                    },
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: AssignPillButton(
                label: 'for_all'.tr(),
                secondary: true,
                onPressed: () {
                  AppHaptics.selection();
                  widget.onConfirm(allIds);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AssignPillButton(
                label: 'done'.tr(),
                onPressed: () {
                  AppHaptics.light();
                  widget.onConfirm(List.of(_selectedIds));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    super.key,
    required this.participant,
    required this.selected,
    required this.onTap,
    this.showTopBorder = true,
  });

  final Map<String, dynamic> participant;
  final bool selected;
  final VoidCallback onTap;
  final bool showTopBorder;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      checked: selected,
      button: true,
      child: Material(
        color: p.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 62),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              border: showTopBorder
                  ? Border(top: BorderSide(color: p.borderSubtle))
                  : null,
            ),
            child: Row(
              children: [
                PersonAvatar(participant: participant),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _PersonName(participant: participant)),
                const SizedBox(width: AppSpacing.md),
                AssignCheckbox(checked: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 24 px rounded-square checkbox from the boards.
class AssignCheckbox extends StatelessWidget {
  const AssignCheckbox({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: AppMotion.durationFor(context, AppMotion.fast),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: checked ? p.accent : p.surface,
        borderRadius: AppRadii.chipRadius,
        border: Border.all(
          color: checked ? p.accent : p.borderStrong,
          width: 1.5,
        ),
      ),
      child: checked ? Icon(AppIcons.check, size: 16, color: p.onAccent) : null,
    );
  }
}

/// Per-unit assignment for an item with quantity > 1. The total can never
/// go above [maxQty]: "+" is disabled once every unit is taken, and an
/// over-assigned [initialMap] (legacy data) is trimmed on open.
class ComplexAssignmentSheet extends StatefulWidget {
  final List<dynamic> participants;
  final Map<String, int> initialMap;
  final int maxQty;
  final Function(Map<String, int>) onConfirm;

  /// Shown under the title.
  final String? itemName;

  const ComplexAssignmentSheet({
    super.key,
    required this.participants,
    required this.initialMap,
    required this.maxQty,
    required this.onConfirm,
    this.itemName,
  });

  @override
  State<ComplexAssignmentSheet> createState() => _ComplexAssignmentSheetState();
}

class _ComplexAssignmentSheetState extends State<ComplexAssignmentSheet> {
  late Map<String, int> _units;

  @override
  void initState() {
    super.initState();
    _units = UnitCap.clamp(widget.initialMap, widget.maxQty);
  }

  void _add(String id) {
    if (!UnitCap.canAdd(_units, widget.maxQty)) {
      AppHaptics.warning();
      return;
    }
    setState(() => _units = UnitCap.increment(_units, id, widget.maxQty));
    AppHaptics.selection();
  }

  void _remove(String id) {
    if ((_units[id] ?? 0) == 0) return;
    setState(() => _units = UnitCap.decrement(_units, id));
    AppHaptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final remaining = UnitCap.remaining(_units, widget.maxQty);
    final canAdd = remaining > 0;
    final people = [
      for (final x in widget.participants)
        if (x is Map) Map<String, dynamic>.from(x),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetTitle(
          title: 'assign_quantities'.tr(),
          subtitle: widget.itemName,
          trailing: Semantics(
            liveRegion: true,
            child: Container(
              key: const ValueKey('bf_assign_units_remaining'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: remaining == 0 ? p.accentSoft : p.oweSoft,
                borderRadius: AppRadii.fullRadius,
              ),
              child: Text(
                'bf_assign_units_remaining'.tr(
                  namedArgs: {
                    'left': remaining.toString(),
                    'total': widget.maxQty.toString(),
                  },
                ),
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: remaining == 0 ? p.onAccentSoft : p.oweInk,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: p.border),
              borderRadius: AppRadii.cardRadius,
            ),
            child: ClipRRect(
              borderRadius: AppRadii.cardRadius,
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final person = people[index];
                  final id = person['id'].toString();
                  final qty = _units[id] ?? 0;
                  final name = (person['name'] ?? '').toString();
                  return Container(
                    key: ValueKey('bf_assign_units_row_$id'),
                    constraints: const BoxConstraints(minHeight: 62),
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: qty > 0 ? p.surfaceVariant : p.surface,
                      border: index > 0
                          ? Border(top: BorderSide(color: p.borderSubtle))
                          : null,
                    ),
                    child: Row(
                      children: [
                        PersonAvatar(participant: person),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: _PersonName(participant: person)),
                        IconButton(
                          key: ValueKey('bf_assign_units_minus_$id'),
                          tooltip: 'bf_assign_units_minus'.tr(
                            namedArgs: {'name': name},
                          ),
                          onPressed: qty > 0 ? () => _remove(id) : null,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          icon: Icon(
                            AppIcons.remove,
                            color: qty > 0 ? p.textPrimary : p.textDisabled,
                          ),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$qty',
                            key: ValueKey('bf_assign_units_count_$id'),
                            textAlign: TextAlign.center,
                            style: AppTypography.amount.copyWith(
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          key: ValueKey('bf_assign_units_plus_$id'),
                          tooltip: 'bf_assign_units_plus'.tr(
                            namedArgs: {'name': name},
                          ),
                          onPressed: canAdd ? () => _add(id) : null,
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          icon: Icon(
                            AppIcons.add,
                            color: canAdd ? p.textPrimary : p.textDisabled,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AssignPillButton(
          label: 'confirm_quantities'.tr(),
          onPressed: () {
            AppHaptics.light();
            widget.onConfirm(UnitCap.clamp(_units, widget.maxQty));
          },
        ),
      ],
    );
  }
}
