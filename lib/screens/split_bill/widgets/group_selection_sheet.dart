import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/services/group_service.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:easy_localization/easy_localization.dart';

class GroupSelectionSheet extends StatelessWidget {
  final GroupService groupService;
  final Function(List<dynamic>) onGroupSelected;

  const GroupSelectionSheet({
    super.key,
    required this.groupService,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'select_group',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                ),
              ).tr(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: groupService.getMyGroups(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return LoadingStateWidget(message: 'loading_groups'.tr());
              }
              if (snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_outlined,
                          size: 64,
                          color: colorScheme.outline.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'no_groups_found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          textAlign: TextAlign.center,
                        ).tr(),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                itemCount: snapshot.data!.docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  final memberCount = (data['members'] as List).length;
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      onTap: () {
                        Navigator.pop(context); // Close sheet
                        onGroupSelected(data['members']);
                      },
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        data['name'],
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "members_count".tr(namedArgs: {'count': memberCount.toString()}),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
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
    _selectedIds = widget.groupMembers.map((m) => m['id'] as String).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('select_members').tr(),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.groupMembers.length,
          itemBuilder: (context, index) {
            var m = widget.groupMembers[index];
            bool isSelected = _selectedIds.contains(m['id']);
            return CheckboxListTile(
              value: isSelected,
              title: Text(m['name']),
              secondary: CircleAvatar(child: Text(m['name'][0])),
              onChanged: (bool? val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.add(m['id']);
                  } else {
                    _selectedIds.remove(m['id']);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('common_cancel').tr(),
        ),
        ElevatedButton(
          onPressed: () {
            List<dynamic> finalSelection = widget.groupMembers
                .where((m) => _selectedIds.contains(m['id']))
                .toList();
            widget.onMembersConfirmed(finalSelection);
            Navigator.pop(context);
          },
          child: Text('add_selected').tr(),
        ),
      ],
    );
  }
}
