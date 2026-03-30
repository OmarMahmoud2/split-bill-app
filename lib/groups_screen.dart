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
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

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

    PremiumBottomSheet.show(
      context: context,
      child: StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('create_new_group',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ).tr(),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'group_name'.tr(),
                  prefixIcon: Icon(Icons.group_work_rounded, color: colorScheme.primary),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedMembers.length,
                    itemBuilder: (context, index) {
                      final m = selectedMembers[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: CircleAvatar(
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
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    m['name'],
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
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
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 10,
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
                    elevation: 4,
                    shadowColor: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  child: Text('create_group',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ).tr(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openQRScanner(Function(Map<String, dynamic>) onUserFound) {
    PremiumBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      showPullHandle: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
      ),
    );
  }

  void _showGroupDetails(String groupId, Map<String, dynamic> data) {
    List members = data['members'] ?? [];

    PremiumBottomSheet.show(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            data['name'],
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            'members_count'.tr(
              namedArgs: {'count': members.length.toString()},
            ),
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),

          ListView.builder(
              shrinkWrap: true,
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
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('owner',
                            style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold),
                          ).tr(),
                        )
                      : null,
                );
              },
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
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    );
  }

  void _showEditModal(String groupId, Map<String, dynamic> data) {
    List<Map<String, dynamic>> editedMembers = List<Map<String, dynamic>>.from(
      data['members'] ?? [],
    );

    PremiumBottomSheet.show(
      context: context,
      child: StatefulBuilder(
        builder: (context, setEditState) {
          final theme = Theme.of(context);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('edit_group_members',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
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
              ListView.builder(
                  shrinkWrap: true,
                  itemCount: editedMembers.length,
                  itemBuilder: (context, index) {
                    final m = editedMembers[index];
                    bool isSameAsMe =
                        m['id'] == FirebaseAuth.instance.currentUser?.uid;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: ImageUtils.getAvatarImage(
                          m['photoUrl'],
                        ),
                      ),
                      title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 24),
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
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ).tr(),
                ),
              ),
            ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline.withValues(alpha: 0.08)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
