import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/participant_list.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

/// Signature of a confirmed assignment: [units] is non-empty for a per-unit
/// assignment (quantity > 1), otherwise [people] share the line equally.
typedef AssignmentConfirm =
    void Function(List<String> people, Map<String, int> units);

/// Who had this item. For a quantity above 1 the host can also give units
/// to people ("Ali 2, Sara 1 of 3"); the + button stops at the quantity so
/// an item can never be over-assigned.
class EditAssignmentSheet extends StatefulWidget {
  const EditAssignmentSheet({
    super.key,
    required this.itemName,
    required this.quantity,
    required this.participants,
    required this.currentPeople,
    required this.currentUnits,
    required this.onConfirm,
  });

  final String itemName;
  final int quantity;
  final List<BillParticipantInfo> participants;
  final List<String> currentPeople;
  final Map<String, int> currentUnits;
  final AssignmentConfirm onConfirm;

  static Future<void> show(
    BuildContext context, {
    required String itemName,
    required int quantity,
    required List<BillParticipantInfo> participants,
    required List<String> currentPeople,
    Map<String, int> currentUnits = const {},
    required AssignmentConfirm onConfirm,
  }) {
    return PremiumBottomSheet.show<void>(
      context: context,
      isScrollable: true,
      child: EditAssignmentSheet(
        itemName: itemName,
        quantity: quantity,
        participants: participants,
        currentPeople: currentPeople,
        currentUnits: currentUnits,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<EditAssignmentSheet> createState() => _EditAssignmentSheetState();
}

class _EditAssignmentSheetState extends State<EditAssignmentSheet> {
  late bool _byUnit;
  late Set<String> _selected;
  late Map<String, int> _units;

  bool get _canSplitUnits => widget.quantity > 1;

  int get _assignedUnits => _units.values.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    final known = {for (final p in widget.participants) p.id};
    _units = {
      for (final e in widget.currentUnits.entries)
        if (known.contains(e.key) && e.value > 0) e.key: e.value,
    };
    // Never start over-assigned: trim from the end.
    var over = _assignedUnits - widget.quantity;
    for (final id in _units.keys.toList().reversed) {
      if (over <= 0) break;
      final take = over < _units[id]! ? over : _units[id]!;
      _units[id] = _units[id]! - take;
      over -= take;
      if (_units[id] == 0) _units.remove(id);
    }
    _byUnit = _canSplitUnits && _units.isNotEmpty;
    _selected = {
      for (final id in widget.currentPeople)
        if (known.contains(id)) id,
    };
  }

  bool get _valid =>
      _byUnit ? _assignedUnits == widget.quantity : _selected.isNotEmpty;

  void _toggle(String id) {
    AppHaptics.selection();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _step(String id, int delta) {
    final current = _units[id] ?? 0;
    final next = current + delta;
    if (next < 0) return;
    if (delta > 0 && _assignedUnits >= widget.quantity) return;
    AppHaptics.selection();
    setState(() {
      if (next == 0) {
        _units.remove(id);
      } else {
        _units[id] = next;
      }
    });
  }

  void _confirm() {
    if (!_valid) return;
    AppHaptics.success();
    if (_byUnit) {
      widget.onConfirm(_units.keys.toList(), Map.of(_units));
    } else {
      final ordered = [
        for (final p in widget.participants)
          if (_selected.contains(p.id)) p.id,
      ];
      widget.onConfirm(ordered, const {});
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final everyone = _selected.length == widget.participants.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'bf_edit_assign_title'.tr(namedArgs: {'item': widget.itemName}),
          style: AppTypography.headlineSmall.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _byUnit
              ? 'bf_edit_assign_units_hint'.tr(
                  namedArgs: {'qty': '${widget.quantity}'},
                )
              : 'bf_edit_assign_share_hint'.tr(),
          style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
        ),
        if (_canSplitUnits) ...[
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text('bf_edit_assign_mode_share'.tr()),
              ),
              ButtonSegment(
                value: true,
                label: Text('bf_edit_assign_mode_units'.tr()),
              ),
            ],
            selected: {_byUnit},
            showSelectedIcon: false,
            onSelectionChanged: (v) {
              AppHaptics.selection();
              setState(() => _byUnit = v.first);
            },
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (!_byUnit)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () {
                AppHaptics.selection();
                setState(() {
                  _selected = everyone
                      ? <String>{}
                      : {for (final x in widget.participants) x.id};
                });
              },
              child: Text(
                (everyone ? 'bf_edit_assign_clear' : 'bf_edit_assign_everyone')
                    .tr(),
              ),
            ),
          ),
        EditCard(
          children: [
            for (final person in widget.participants)
              _byUnit ? _unitRow(person) : _shareRow(person),
          ],
        ),
        if (_byUnit) ...[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              _assignedUnits == widget.quantity
                  ? 'bf_edit_assign_all_units'.tr(
                      namedArgs: {'qty': '${widget.quantity}'},
                    )
                  : 'bf_edit_units_assigned'.tr(
                      namedArgs: {
                        'assigned': '$_assignedUnits',
                        'qty': '${widget.quantity}',
                      },
                    ),
              textAlign: TextAlign.center,
              style: AppTypography.labelMedium.copyWith(
                color: _assignedUnits == widget.quantity
                    ? p.owedInk
                    : p.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FilledButton(
          onPressed: _valid ? _confirm : null,
          child: Text('bf_edit_assign_confirm'.tr()),
        ),
      ],
    );
  }

  Widget _shareRow(BillParticipantInfo person) {
    final p = context.palette;
    final on = _selected.contains(person.id);
    return Semantics(
      checked: on,
      button: true,
      label: person.name,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _toggle(person.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
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
                  child: Text(
                    person.name,
                    style: AppTypography.titleMedium.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: AppMotion.durationFor(context, AppMotion.fast),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? p.accent : p.surface,
                    border: Border.all(
                      color: on ? p.accent : p.borderStrong,
                      width: 1.5,
                    ),
                  ),
                  child: on
                      ? Icon(AppIcons.check, size: 16, color: p.onAccent)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _unitRow(BillParticipantInfo person) {
    final p = context.palette;
    final count = _units[person.id] ?? 0;
    final full = _assignedUnits >= widget.quantity;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.xs,
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
              child: Text(
                person.name,
                style: AppTypography.titleMedium.copyWith(color: p.textPrimary),
              ),
            ),
            IconButton(
              onPressed: count > 0 ? () => _step(person.id, -1) : null,
              tooltip: 'bf_edit_assign_less'.tr(
                namedArgs: {'name': person.name},
              ),
              icon: const Icon(AppIcons.remove),
            ),
            SizedBox(
              width: 28,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: AppTypography.amount.copyWith(
                  color: count > 0 ? p.textPrimary : p.textTertiary,
                ),
              ),
            ),
            IconButton(
              onPressed: full ? null : () => _step(person.id, 1),
              tooltip: 'bf_edit_assign_more'.tr(
                namedArgs: {'name': person.name},
              ),
              icon: const Icon(AppIcons.add),
            ),
          ],
        ),
      ),
    );
  }
}
