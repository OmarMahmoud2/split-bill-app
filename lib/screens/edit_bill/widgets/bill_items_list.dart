import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/participant_list.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// The bill's items: name, quantity x unit price, who had it, line total.
/// Tapping a row assigns it; the pencil edits name / price / quantity.
class BillItemsList extends StatelessWidget {
  const BillItemsList({
    super.key,
    required this.draft,
    required this.names,
    required this.onAssign,
    required this.onEdit,
    this.showAssignments = true,
  });

  final BillDraft draft;

  /// Participant id -> display name.
  final Map<String, String> names;
  final ValueChanged<int> onAssign;
  final ValueChanged<int> onEdit;

  /// False for whole-bill split methods, where items are not assigned.
  final bool showAssignments;

  String _assignedLabel(ItemAssignmentState s) {
    String n(String id) => names[id] ?? id;
    if (s.unitAssignments.isNotEmpty) {
      return s.unitAssignments.entries
          .map(
            (e) => 'bf_edit_units_of'.tr(
              namedArgs: {'name': n(e.key), 'count': '${e.value}'},
            ),
          )
          .join(', ');
    }
    if (s.people.length == names.length && names.length > 1) {
      return 'bf_edit_everyone'.tr();
    }
    return s.people.map(n).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (draft.items.isEmpty) {
      return EditCard(
        children: [
          Padding(
            padding: AppSpacing.allLg,
            child: Text(
              'bf_edit_no_items'.tr(),
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
          ),
        ],
      );
    }
    return EditCard(
      children: [
        for (var i = 0; i < draft.items.length; i++)
          _ItemRow(
            item: draft.items[i],
            state: draft.assignmentOf(i),
            currency: draft.currency,
            assignedLabel: showAssignments
                ? _assignedLabel(draft.assignmentOf(i))
                : null,
            onTap: showAssignments ? () => onAssign(i) : () => onEdit(i),
            onEdit: () => onEdit(i),
          ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.state,
    required this.currency,
    required this.assignedLabel,
    required this.onTap,
    required this.onEdit,
  });

  final DraftItem item;
  final ItemAssignmentState state;
  final String currency;
  final String? assignedLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final problem = assignedLabel != null && (!state.isComplete);
    final unit = formatMoneyMinor(item.unitPriceMinor, currency);
    final String subtitle;
    if (assignedLabel == null) {
      subtitle = 'bf_edit_qty_times'.tr(
        namedArgs: {'qty': '${item.quantity}', 'price': unit},
      );
    } else if (state.isOver) {
      subtitle = 'bf_edit_item_over'.tr();
    } else if (state.isEmpty) {
      subtitle = 'bf_edit_item_choose'.tr();
    } else if (!state.isComplete) {
      subtitle = 'bf_edit_units_assigned'.tr(
        namedArgs: {
          'assigned': '${state.assignedUnits}',
          'qty': '${state.quantity}',
        },
      );
    } else {
      subtitle = assignedLabel!;
    }

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.quantity > 1
                          ? 'bf_edit_item_with_qty'.tr(
                              namedArgs: {
                                'qty': '${item.quantity}',
                                'name': item.name,
                              },
                            )
                          : item.name,
                      style: AppTypography.titleMedium.copyWith(
                        color: p.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (problem) ...[
                          Icon(
                            AppIcons.error,
                            size: 14,
                            color: p.owe,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            subtitle,
                            style: AppTypography.bodySmall.copyWith(
                              color: problem ? p.oweInk : p.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              MoneyText(
                minor: item.lineTotalMinor,
                currency: currency,
                tone: MoneyTone.neutral,
              ),
              IconButton(
                onPressed: onEdit,
                tooltip: 'bf_edit_edit_item'.tr(),
                icon: Icon(
                  AppIcons.edit,
                  size: 20,
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
