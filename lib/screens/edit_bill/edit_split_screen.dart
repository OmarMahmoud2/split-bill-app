import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/screens/edit_bill/edit_bill_controller.dart';
import 'package:split_bill_app/screens/edit_bill/history_format.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/bill_items_list.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/edit_assignment_sheet.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/edit_bill_header.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/edit_item_sheet.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/participant_list.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/participant_options_sheet.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// "Items, people and split": the people on the bill, the items and who
/// had them, and the split method. Edits go straight into [controller];
/// the edit screen saves them.
class EditSplitScreen extends StatefulWidget {
  const EditSplitScreen({
    super.key,
    required this.controller,
    required this.onAddPeople,
  });

  final EditBillController controller;

  /// Opens the add-people flow (contacts / QR). Completes when done.
  final Future<void> Function() onAddPeople;

  @override
  State<EditSplitScreen> createState() => _EditSplitScreenState();
}

class _EditSplitScreenState extends State<EditSplitScreen> {
  bool _addingPeople = false;

  EditBillController get c => widget.controller;

  Future<void> _addPeople() async {
    if (_addingPeople) return;
    setState(() => _addingPeople = true);
    try {
      await widget.onAddPeople();
    } finally {
      if (mounted) setState(() => _addingPeople = false);
    }
  }

  void _assign(int index) {
    final item = c.draft.items[index];
    final state = c.draft.assignmentOf(index);
    EditAssignmentSheet.show(
      context,
      itemName: item.name,
      quantity: item.quantity,
      participants: c.participantInfos,
      currentPeople: state.people,
      currentUnits: state.unitAssignments,
      onConfirm: (people, units) =>
          c.assignItem(index, people: people, units: units),
    );
  }

  void _editItem(int index) {
    final item = c.draft.items[index];
    EditItemSheet.show(
      context,
      currency: c.currency,
      initial: item,
      onSave: (updated) => c.updateItem(index, updated),
      onRemove: () {
        c.removeItem(index);
        AppToast.show(
          context,
          message: 'bf_edit_item_removed_toast'.tr(
            namedArgs: {'item': item.name},
          ),
          type: AppToastType.info,
        );
      },
    );
  }

  void _addItem() {
    EditItemSheet.show(
      context,
      currency: c.currency,
      onSave: (item) {
        c.addItem(item);
        if (c.draft.method == SplitMethod.items) {
          // Ask right away who had it so the bill stays complete.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _assign(c.draft.items.length - 1);
          });
        }
      },
    );
  }

  void _personOptions(String id) {
    final info = c.participantInfos.firstWhere((p) => p.id == id);
    ParticipantOptionsSheet.show(
      context,
      participant: info,
      isPaid: c.isPaid(id),
      canRemove: !c.isHost(id),
      onTogglePaid: () => c.togglePaid(id),
      onRemove: () {
        final result = c.removeParticipant(id);
        if (result == RemoveParticipantResult.isHost) {
          AppToast.show(
            context,
            message: 'bf_edit_host_cannot_remove'.tr(),
            type: AppToastType.warning,
          );
        }
      },
    );
  }

  Future<void> _everyoneSharesAll() async {
    final ok = await showAppDialog(
      context,
      icon: AppIcons.people,
      title: 'bf_edit_share_all_title'.tr(),
      message: 'bf_edit_share_all_body'.tr(),
      confirmLabel: 'bf_edit_share_all_confirm'.tr(),
    );
    if (ok) {
      AppHaptics.success();
      c.assignAllToEveryone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: AdaptiveBody.form(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final comp = c.computation;
              final draft = c.draft;
              final issues = c.issueMessages;
              final names = {
                for (final info in c.participantInfos) info.id: info.name,
              };
              return Column(
                children: [
                  EditBillHeader(
                    title: 'bf_edit_row_items'.tr(),
                    leadingIcon: AppIcons.back,
                    leadingTooltip: 'bf_edit_back'.tr(),
                    onLeading: () => Navigator.of(context).pop(),
                    actionLabel: 'bf_edit_done'.tr(),
                    onAction: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        AppSpacing.xl,
                        AppSpacing.lg,
                        AppSpacing.xl,
                        AppSpacing.huge,
                      ),
                      children: [
                        _MethodPicker(
                          method: draft.method,
                          original: c.originalDraft.method,
                          onChanged: (m) {
                            AppHaptics.selection();
                            c.setMethod(m);
                          },
                        ),
                        if (issues.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          EditIssuesBanner(messages: issues),
                        ],
                        _SectionHeader(
                          label: 'bf_edit_section_people'.tr(),
                          action: _addingPeople
                              ? const _SmallSpinner()
                              : TextButton.icon(
                                  onPressed: _addPeople,
                                  icon: const Icon(
                                    AppIcons.personAdd,
                                    size: 18,
                                  ),
                                  label: Text('bf_edit_add_people'.tr()),
                                ),
                        ),
                        ParticipantList(
                          participants: c.participantInfos,
                          sharesMinor: comp.totals,
                          currency: draft.currency,
                          paidIds: {
                            for (final info in c.participantInfos)
                              if (c.isPaid(info.id)) info.id,
                          },
                          hostId: c.hostUid,
                          currentUid: c.currentUid,
                          onParticipantTap: _personOptions,
                        ),
                        _SectionHeader(
                          label: 'bf_edit_section_items'.tr(),
                          action: TextButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(AppIcons.add, size: 18),
                            label: Text('bf_edit_add_item'.tr()),
                          ),
                        ),
                        BillItemsList(
                          draft: draft,
                          names: names,
                          showAssignments: draft.method == SplitMethod.items,
                          onAssign: _assign,
                          onEdit: _editItem,
                        ),
                        if (draft.method == SplitMethod.items &&
                            draft.items.isNotEmpty &&
                            c.participantInfos.length > 1) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: _everyoneSharesAll,
                              child: Text('bf_edit_share_all'.tr()),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'bf_edit_total'.tr(),
                                style: AppTypography.titleMedium.copyWith(
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                            MoneyText(
                              minor: comp.grandTotalMinor,
                              currency: draft.currency,
                              tone: MoneyTone.neutral,
                              size: MoneySize.large,
                              animate: true,
                              animateFromZero: false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Amber notice listing what blocks saving, each with its next step.
class EditIssuesBanner extends StatelessWidget {
  const EditIssuesBanner({super.key, required this.messages, this.max = 4});

  final List<IssueMessage> messages;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shown = messages.take(max).toList();
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          color: p.oweSoft,
          borderRadius: AppRadii.rowRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(AppIcons.error, size: 16, color: p.oweInk),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      shown[i].text,
                      style: AppTypography.bodySmall.copyWith(color: p.oweInk),
                    ),
                  ),
                ],
              ),
            ],
            if (messages.length > shown.length) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'bf_edit_issue_more'.tr(
                  namedArgs: {'count': '${messages.length - shown.length}'},
                ),
                style: AppTypography.labelSmall.copyWith(color: p.oweInk),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.action});

  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        top: AppSpacing.xl,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _SmallSpinner extends StatelessWidget {
  const _SmallSpinner();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: context.palette.accent,
        ),
      ),
    ),
  );
}

class _MethodPicker extends StatelessWidget {
  const _MethodPicker({
    required this.method,
    required this.original,
    required this.onChanged,
  });

  final SplitMethod method;
  final SplitMethod original;
  final ValueChanged<SplitMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final options = <SplitMethod>{
      SplitMethod.items,
      SplitMethod.equal,
      original,
      method,
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'bf_edit_section_split'.tr(),
          style: AppTypography.titleSmall.copyWith(color: p.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in options)
              ChoiceChip(
                label: Text(splitMethodKey(m.wireName).tr()),
                selected: m == method,
                showCheckmark: false,
                onSelected: (_) => onChanged(m),
              ),
          ],
        ),
      ],
    );
  }
}
