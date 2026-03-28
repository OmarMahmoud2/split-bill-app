import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/services/group_service.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';

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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            "Select Group",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: groupService.getMyGroups(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LoadingStateWidget(message: "Loading groups...");
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No groups found."));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data =
                        snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        child: const Icon(Icons.group, color: Colors.blue),
                      ),
                      title: Text(
                        data['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "${(data['members'] as List).length} members",
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        Navigator.pop(context); // Close sheet
                        onGroupSelected(data['members']);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
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
      title: const Text("Select Members"),
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
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            List<dynamic> finalSelection = widget.groupMembers
                .where((m) => _selectedIds.contains(m['id']))
                .toList();
            widget.onMembersConfirmed(finalSelection);
            Navigator.pop(context);
          },
          child: const Text("Add Selected"),
        ),
      ],
    );
  }
}
