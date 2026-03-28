import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'services/contact_service.dart';
import 'services/group_service.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';

class GroupDetailsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  final GroupService _groupService = GroupService();
  final ContactService _contactService = ContactService();

  void _addMember(List<dynamic> currentMembers) async {
    final result = await _contactService.pickAndFindUser();

    if (result != null) {
      final data = result['data'];
      String uid = data['uid'];

      // Prevent duplicates
      if (currentMembers.any((m) => m['id'] == uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("User already in group")),
          );
        }
        return;
      }

      // Add new member
      List<Map<String, dynamic>> updatedList = List<Map<String, dynamic>>.from(
        currentMembers,
      );
      updatedList.add({
        'name': data['displayName'] ?? "Unknown",
        'id': uid,
        'phoneNumber': data['phoneNumber'],
        'isGuest': result['type'] == 'guest',
      });

      await _groupService.updateGroup(widget.groupId, updatedList);
    }
  }

  void _removeMember(List<dynamic> currentMembers, int index) async {
    List<Map<String, dynamic>> updatedList = List<Map<String, dynamic>>.from(
      currentMembers,
    );
    updatedList.removeAt(index);
    await _groupService.updateGroup(widget.groupId, updatedList);
  }

  void _deleteGroup() async {
    final confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Group?"),
        content: const Text(
          "This cannot be undone. All members will be removed from this list.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _groupService.deleteGroup(widget.groupId);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Group Details"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            onPressed: _deleteGroup,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: "Delete Group",
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingStateWidget(
              message: "Loading squad members...",
            );
          }
          if (!snapshot.data!.exists) {
            return const Center(child: Text("Group deleted"));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          List<dynamic> members = data['members'] ?? [];

          return Column(
            children: [
              // 1. Header Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 30,
                  horizontal: 20,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Text(
                        widget.groupName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 28,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "${members.length} Members",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Members List Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Members",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _addMember(members),
                      icon: const Icon(Icons.person_add),
                      label: const Text("Add"),
                    ),
                  ],
                ),
              ),

              // 3. Members List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    var m = members[index];
                    bool isGuest = m['isGuest'] ?? true;

                    return Dismissible(
                      key: Key(m['id']),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (dir) => _removeMember(members, index),
                      child: Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isGuest
                                ? Colors.grey[300]
                                : Theme.of(context).colorScheme.primary,
                            child: Text(
                              m['name'][0],
                              style: TextStyle(
                                color: isGuest ? Colors.black54 : Colors.white,
                              ),
                            ),
                          ),
                          title: Text(
                            m['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            isGuest
                                ? "Guest · ${m['phoneNumber'] ?? ''}"
                                : "App User",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
