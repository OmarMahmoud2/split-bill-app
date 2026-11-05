import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/screens/split_bill/widgets/add_people_screen.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assign_widgets.dart';
import 'package:split_bill_app/screens/split_bill/widgets/assignment_sheets.dart';
import 'package:split_bill_app/services/group_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';

/// The host's groups as [AddPeopleGroup]s (for `AddPeopleScreen`).
Stream<List<AddPeopleGroup>> addPeopleGroupsFrom(GroupService service) =>
    service.getMyGroups().map(
      (snapshot) => [
        for (final doc in snapshot.docs)
          if (doc.data() is Map)
            _groupFrom(doc.id, Map<String, dynamic>.from(doc.data() as Map)),
      ],
    );

AddPeopleGroup _groupFrom(String id, Map<String, dynamic> data) =>
    AddPeopleGroup(
      id: id,
      name: (data['name'] ?? '').toString(),
      members: [
        for (final m in (data['members'] as List?) ?? const [])
          if (m is Map && m['id'] != null) Map<String, dynamic>.from(m),
      ],
    );

/// Pick one of the host's groups; calls [onGroupSelected] with its members.
/// [onGroupPicked] also gets the group id so the bill can be filed into the
/// group's ledger.
class GroupSelectionSheet extends StatelessWidget {
  final GroupService groupService;
  final Function(List<dynamic>) onGroupSelected;
  final void Function(String groupId, LedgerGroup group)? onGroupPicked;

  const GroupSelectionSheet({
    super.key,
    required this.groupService,
    required this.onGroupSelected,
    this.onGroupPicked,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'select_group'.tr(),
          style: AppTypography.headlineMedium.copyWith(color: p.textPrimary),
        ),
        const SizedBox(height: AppSpacing.lg),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.5,
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: groupService.getMyGroups(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState.inline(
                  title: 'bf_assign_groups_error_title'.tr(),
                  message: 'bf_assign_groups_error_message'.tr(),
                );
              }
              if (!snapshot.hasData) {
                return const SkeletonShimmer(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [SkeletonListTile(), SkeletonListTile()],
                  ),
                );
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return EmptyState(
                  icon: Icons.groups_outlined,
                  title: 'no_groups_found'.tr(),
                  compact: true,
                );
              }
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: p.border),
                  borderRadius: AppRadii.cardRadius,
                ),
                child: ClipRRect(
                  borderRadius: AppRadii.cardRadius,
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = Map<String, dynamic>.from(
                        docs[index].data() as Map,
                      );
                      final members = (data['members'] as List?) ?? const [];
                      return Material(
                        color: p.surface,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            final id = docs[index].id;
                            onGroupPicked?.call(
                              id,
                              LedgerGroup.fromMap(id, data),
                            );
                            onGroupSelected(members);
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 62),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              border: index > 0
                                  ? Border(
                                      top: BorderSide(color: p.borderSubtle),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: p.accentSoft,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.groups_rounded,
                                    size: 20,
                                    color: p.onAccentSoft,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (data['name'] ?? '').toString(),
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: p.textPrimary,
                                            ),
                                      ),
                                      Text(
                                        'members_count'.tr(
                                          namedArgs: {
                                            'count': '${members.length}',
                                          },
                                        ),
                                        style: AppTypography.caption.copyWith(
                                          color: p.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.adaptive.arrow_forward_rounded,
                                  size: 18,
                                  color: p.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Choose which members of a group join the bill.
class GroupMemberSelectionDialog extends StatefulWidget {
  final List<dynamic> groupMembers;
  final Function(List<dynamic>) onMembersConfirmed;

  const GroupMemberSelectionDialog({
    super.key,
    required this.groupMembers,
    required this.onMembersConfirmed,
  });

  @override
  State<GroupMemberSelectionDialog> createState() =>
      _GroupMemberSelectionDialogState();
}

class _GroupMemberSelectionDialogState
    extends State<GroupMemberSelectionDialog> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.groupMembers.map((m) => m['id'].toString()).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.cardRadius,
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'select_members'.tr(),
              style: AppTypography.headlineMedium.copyWith(
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.groupMembers.length,
                itemBuilder: (context, index) {
                  final m = Map<String, dynamic>.from(
                    widget.groupMembers[index] as Map,
                  );
                  final id = m['id'].toString();
                  final selected = _selectedIds.contains(id);
                  return Semantics(
                    checked: selected,
                    button: true,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          selected
                              ? _selectedIds.remove(id)
                              : _selectedIds.add(id);
                        });
                        AppHaptics.selection();
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 56),
                        child: Row(
                          children: [
                            PersonAvatar(participant: m, size: 36),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                (m['name'] ?? '').toString(),
                                style: AppTypography.titleMedium.copyWith(
                                  fontSize: 15,
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                            AssignCheckbox(checked: selected),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AssignPillButton(
                    label: 'common_cancel'.tr(),
                    secondary: true,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AssignPillButton(
                    label: 'add_selected'.tr(),
                    onPressed: () {
                      final finalSelection = widget.groupMembers
                          .where(
                            (m) => _selectedIds.contains(m['id'].toString()),
                          )
                          .toList();
                      widget.onMembersConfirmed(finalSelection);
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
