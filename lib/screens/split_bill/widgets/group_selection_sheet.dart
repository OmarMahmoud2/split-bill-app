import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/services/group_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';

/// Pick a group to pull its members into a bill.
///
/// [onGroupSelected] receives the raw `members` maps (1.x contract).
/// [onGroupPicked] also gets the group id so the bill can be filed into the
/// group's ledger (`bills.groupId`).
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Semantics(
            header: true,
            child: Text(
              'select_group'.tr(),
              style: AppTypography.headlineSmall.copyWith(color: p.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
          child: StreamBuilder<QuerySnapshot>(
            stream: groupService.getMyGroups(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(padding: const EdgeInsets.all(20), child: ErrorState.inline(message: 'groups_load_failed'.tr()));
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SkeletonShimmer(child: Column(children: [SkeletonListTile(), SkeletonListTile()])),
                );
              }
              final docs = snapshot.data!.docs
                  .map((d) => (d.id, d.data() as Map<String, dynamic>))
                  .where((e) => e.$2['archived'] != true)
                  .toList();
              if (docs.isEmpty) {
                return EmptyState(compact: true, icon: Icons.group_outlined, title: 'no_groups_found'.tr());
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final (id, data) = docs[index];
                  final group = LedgerGroup.fromMap(id, data);
                  return LedgerCard(
                    onTap: () {
                      AppHaptics.selection();
                      Navigator.pop(context);
                      onGroupPicked?.call(id, group);
                      onGroupSelected(data['members'] as List? ?? const []);
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        AvatarStack(people: [for (final m in group.members) (m.id, m.name, m.photoUrl)], max: 3),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.name, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(
                                'members_count'.tr(namedArgs: {'count': '${group.members.length}'}),
                                style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                          color: p.textTertiary,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Choose which group members join this bill (everyone by default).
class GroupMemberSelectionDialog extends StatefulWidget {
  final List<dynamic> groupMembers;
  final Function(List<dynamic>) onMembersConfirmed;

  const GroupMemberSelectionDialog({
    super.key,
    required this.groupMembers,
    required this.onMembersConfirmed,
  });

  @override
  State<GroupMemberSelectionDialog> createState() => _GroupMemberSelectionDialogState();
}

class _GroupMemberSelectionDialogState extends State<GroupMemberSelectionDialog> {
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.groupMembers.map((m) => m['id'] as String).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      title: Text('select_members'.tr()),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.groupMembers.length,
          itemBuilder: (context, index) {
            final m = widget.groupMembers[index];
            final id = m['id'] as String;
            final name = (m['name'] as String?) ?? '';
            return CheckboxListTile(
              value: _selectedIds.contains(id),
              contentPadding: EdgeInsets.zero,
              activeColor: p.accent,
              title: Text(name.isEmpty ? 'someone_label'.tr() : name),
              secondary: LedgerAvatar(id: id, name: name, photoUrl: m['photoUrl'] as String?),
              onChanged: (val) {
                AppHaptics.selection();
                setState(() {
                  if (val == true) {
                    _selectedIds.add(id);
                  } else {
                    _selectedIds.remove(id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('common_cancel'.tr())),
        FilledButton(
          onPressed: _selectedIds.isEmpty
              ? null
              : () {
                  final finalSelection = widget.groupMembers.where((m) => _selectedIds.contains(m['id'])).toList();
                  widget.onMembersConfirmed(finalSelection);
                  Navigator.pop(context);
                },
          child: Text('add_selected'.tr()),
        ),
      ],
    );
  }
}
