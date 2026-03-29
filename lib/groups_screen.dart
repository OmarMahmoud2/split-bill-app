import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:split_bill_app/services/group_service.dart';
import 'package:split_bill_app/services/contact_service.dart';
import 'package:split_bill_app/utils/image_utils.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:split_bill_app/widgets/empty_state_widget.dart';
import 'package:easy_localization/easy_localization.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final GroupService _groupService = GroupService();
  final ContactService _contactService = ContactService();
  bool _isCreating = false;

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('groups',
          style: TextStyle(fontWeight: FontWeight.bold),
        ).tr(),
        content: Text('create_squads_for_your_roommates_family_or_travel_buddies_groups_help_you_split_bills_faster_by_selecting_multiple_people_with_one_tap',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ).tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('got_it_3').tr(),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    List<Map<String, dynamic>> selectedMembers = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text('create_new_group',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ).tr(),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'group_name'.tr(),
                    prefixIcon: const Icon(Icons.group_work_rounded),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Add Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn(
                        icon: Icons.contacts_rounded,
                        label: "Contacts",
                        onTap: () async {
                          final result = await _contactService
                              .pickAndFindUser();
                          if (result != null) {
                            final data = result['data'];
                            if (!selectedMembers.any(
                              (m) => m['id'] == data['uid'],
                            )) {
                              setModalState(() {
                                selectedMembers.add({
                                  'id': data['uid'],
                                  'name': data['displayName'] ?? "Unknown",
                                  'photoUrl': data['photoUrl'],
                                  'phoneNumber': data['phoneNumber'],
                                  'isGuest': result['type'] == 'guest',
                                });
                              });
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionBtn(
                        icon: Icons.qr_code_scanner_rounded,
                        label: "Scan QR",
                        onTap: () => _openQRScanner((data) {
                          if (!selectedMembers.any(
                            (m) => m['id'] == data['uid'],
                          )) {
                            setModalState(() {
                              selectedMembers.add({
                                'id': data['uid'],
                                'name': data['displayName'] ?? "User",
                                'photoUrl': data['photoUrl'],
                                'phoneNumber': data['phoneNumber'],
                                'isGuest': false,
                              });
                            });
                          }
                        }),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                // Selected Members Horizontal List
                if (selectedMembers.isNotEmpty) ...[
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedMembers.length,
                      itemBuilder: (context, index) {
                        final m = selectedMembers[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Stack(
                            children: [
                              Column(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundImage: ImageUtils.getAvatarImage(
                                      m['photoUrl'],
                                    ),
                                    child:
                                        ImageUtils.getAvatarImage(
                                              m['photoUrl'],
                                            ) ==
                                            null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      m['name'],
                                      style: const TextStyle(fontSize: 10),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => setModalState(
                                    () => selectedMembers.removeAt(index),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isNotEmpty &&
                          selectedMembers.isNotEmpty) {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        setState(() => _isCreating = true);
                        await _groupService.createGroup(
                          nameController.text.trim(),
                          selectedMembers,
                        );
                        setState(() => _isCreating = false);
                        HapticFeedback.heavyImpact();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text('create_group',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ).tr(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openQRScanner(Function(Map<String, dynamic>) onUserFound) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) async {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? code = barcodes.first.rawValue;
                  if (code != null) {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(context);
                    // Fetch user details from Firestore
                    final doc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(code)
                        .get();
                    if (doc.exists) {
                      final data = doc.data()!;
                      data['uid'] = code;
                      onUserFound(data);
                    }
                  }
                }
              },
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Center(
              child: Icon(
                Icons.qr_code_scanner_rounded,
                color: Colors.white54,
                size: 200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupDetails(String groupId, Map<String, dynamic> data) {
    List members = data['members'] ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              data['name'],
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
            ),
            Text(
              'members_count'.tr(
                namedArgs: {'count': members.length.toString()},
              ),
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final m = members[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: ImageUtils.getAvatarImage(m['photoUrl']),
                      child: ImageUtils.getAvatarImage(m['photoUrl']) == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      m['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      m['phoneNumber'] ?? "No phone",
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    trailing: m['id'] == FirebaseAuth.instance.currentUser?.uid
                        ? Chip(
                            label: Text('owner',
                              style: TextStyle(fontSize: 10),
                            ).tr(),
                            backgroundColor: Colors.blueGrey,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : null,
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                        _deleteGroup(groupId);
                      },
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      label: Text('delete_group',
                        style: TextStyle(color: Colors.red),
                      ).tr(),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditModal(groupId, data);
                      },
                      icon: const Icon(Icons.edit_rounded, color: Colors.white),
                      label: Text('edit_members',
                        style: TextStyle(color: Colors.white),
                      ).tr(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditModal(String groupId, Map<String, dynamic> data) {
    List<Map<String, dynamic>> editedMembers = List<Map<String, dynamic>>.from(
      data['members'] ?? [],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setEditState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Text('edit_group_members',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ).tr(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionBtn(
                        icon: Icons.person_add_rounded,
                        label: "Add Contacts",
                        onTap: () async {
                          final result = await _contactService
                              .pickAndFindUser();
                          if (result != null) {
                            final userData = result['data'];
                            if (!editedMembers.any(
                              (m) => m['id'] == userData['uid'],
                            )) {
                              setEditState(() {
                                editedMembers.add({
                                  'id': userData['uid'],
                                  'name': userData['displayName'] ?? "Unknown",
                                  'photoUrl': userData['photoUrl'],
                                  'phoneNumber': userData['phoneNumber'],
                                  'isGuest': result['type'] == 'guest',
                                });
                              });
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionBtn(
                        icon: Icons.qr_code_scanner_rounded,
                        label: "Add via QR",
                        onTap: () => _openQRScanner((userData) {
                          if (!editedMembers.any(
                            (m) => m['id'] == userData['uid'],
                          )) {
                            setEditState(() {
                              editedMembers.add({
                                'id': userData['uid'],
                                'name': userData['displayName'] ?? "User",
                                'photoUrl': userData['photoUrl'],
                                'phoneNumber': userData['phoneNumber'],
                                'isGuest': false,
                              });
                            });
                          }
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: editedMembers.length,
                    itemBuilder: (context, index) {
                      final m = editedMembers[index];
                      bool isSameAsMe =
                          m['id'] == FirebaseAuth.instance.currentUser?.uid;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: ImageUtils.getAvatarImage(
                            m['photoUrl'],
                          ),
                        ),
                        title: Text(m['name']),
                        trailing: isSameAsMe
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.orange,
                                ),
                                onPressed: () => setEditState(
                                  () => editedMembers.removeAt(index),
                                ),
                              ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      await _groupService.updateGroup(groupId, editedMembers);
                      HapticFeedback.heavyImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text('scan_save_changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ).tr(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteGroup(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_group_2').tr(),
        content: Text('this_squad_will_be_gone_forever_sure').tr(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common_cancel').tr(),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('common_delete', style: TextStyle(color: Colors.red)).tr(),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _groupService.deleteGroup(groupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. PREMIUM HEADER
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text('my_squads',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ).tr(),
                          const Spacer(),
                          GestureDetector(
                            onTap: _showInfo,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: Theme.of(context).primaryColor,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. GROUPS LIST
              StreamBuilder<QuerySnapshot>(
                stream: _groupService.getMyGroups(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverFillRemaining(
                      child: LoadingStateWidget(
                        message: 'loading_your_squads'.tr(),
                      ),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return SliverFillRemaining(
                      child: EmptyStateWidget(
                        message: 'no_squads_yet_create_one'.tr(),
                        title: 'create_your_first_squad'.tr(),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildGroupCard(doc.id, data);
                      }, childCount: snapshot.data!.docs.length),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),

          if (_isCreating)
            LoadingStateWidget(message: 'creating_your_squad'.tr()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(
          Icons.group_add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildGroupCard(String id, Map<String, dynamic> data) {
    List members = data['members'] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showGroupDetails(id, data),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Group Avatars Stack
                SizedBox(
                  width: 60,
                  height: 40,
                  child: Stack(
                    children: List.generate(
                      members.length > 3 ? 3 : members.length,
                      (i) => Positioned(
                        left: i * 15.0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundImage: ImageUtils.getAvatarImage(
                              members[i]['photoUrl'],
                            ),
                            child:
                                ImageUtils.getAvatarImage(
                                      members[i]['photoUrl'],
                                    ) ==
                                    null
                                ? const Icon(Icons.person, size: 14)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'members_count'.tr(
                          namedArgs: {'count': members.length.toString()},
                        ),
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
