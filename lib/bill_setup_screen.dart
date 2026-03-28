import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:split_bill_app/scan_receipt_screen.dart';
import 'package:split_bill_app/manual_entry_screen.dart';
import 'package:split_bill_app/widgets/multi_contact_picker.dart';
import 'package:split_bill_app/widgets/custom_app_header.dart';
import 'package:split_bill_app/services/friend_scanner_service.dart';
import 'package:split_bill_app/services/group_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/widgets/loading_state_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_bill_app/services/contact_service.dart';
import 'dart:convert';

class BillSetupScreen extends StatefulWidget {
  const BillSetupScreen({super.key});

  @override
  State<BillSetupScreen> createState() => _BillSetupScreenState();
}

class _BillSetupScreenState extends State<BillSetupScreen> {
  final GroupService _groupService = GroupService();
  final ContactService _contactService = ContactService();

  // Structure: { 'type': 'host'|'app_user'|'guest', 'data': { 'uid', 'displayName', 'phoneNumber', ... } }
  final List<Map<String, dynamic>> _participants = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeHost();
  }

  // --- HELPER METHODS ---
  ImageProvider? _getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (e) {
        return null; // Fallback or handle error
      }
    }
    return NetworkImage(url);
  }

  // --- ADD METHODS ---

  void _showAddParticipantsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add People",
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAddOption(
                  icon: Icons.contacts_rounded,
                  label: "Contacts",
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickContactsHelper();
                  },
                ),
                _buildAddOption(
                  icon: Icons.groups_rounded,
                  label: "Groups",
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _showGroupPicker();
                  },
                ),
                _buildAddOption(
                  icon: Icons.qr_code_rounded,
                  label: "Scan QR",
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _scanFriendQR();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // 1. Pick Contacts
  Future<void> _pickContactsHelper() async {
    // We only pass pre-selected IDs for visual feedback in picker,
    // assuming picker uses 'id' which maps to local contact ID.
    // This part might be tricky since we now have generalized participants.
    // For now, let's pass an empty list or try to map if possible.

    final List<Contact>? pickedContacts = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiContactPicker(alreadySelectedIds: []),
      ),
    );

    if (pickedContacts != null && pickedContacts.isNotEmpty) {
      setState(() => _isLoading = true);

      // Identify them (App User vs Guest)
      final identified = await _contactService.identifyUsers(pickedContacts);

      setState(() {
        for (var person in identified) {
          _addParticipantIfNotExists(person);
        }
        _isLoading = false;
      });
    }
  }

  void _addParticipantIfNotExists(Map<String, dynamic> newPerson) {
    final newData = newPerson['data'];
    final String newPhone = newData['phoneNumber']?.toString() ?? "";
    final String newUid = newData['uid']?.toString() ?? "";

    // Check duplicates by UID (if app user) or Phone
    bool exists = _participants.any((p) {
      final pData = p['data'];
      if (newUid.isNotEmpty && pData['uid'] == newUid) return true;
      if (newPhone.isNotEmpty && pData['phoneNumber'] == newPhone) return true;
      return false;
    });

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${newData['displayName']} is already added.")),
      );
    } else {
      _participants.add(newPerson);
    }
  }

  // 2. Scan QR
  Future<void> _scanFriendQR() async {
    final String? scannedUid = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScanFriendScreen()),
    );

    if (scannedUid != null) {
      _fetchAndAddUserByUid(scannedUid);
    }
  }

  Future<void> _fetchAndAddUserByUid(String uid) async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        data['uid'] = uid; // Ensure UID is in data

        final person = {'type': 'app_user', 'data': data};

        setState(() {
          _addParticipantIfNotExists(person);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("User not found")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 3. Pick Group
  void _showGroupPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select a Group",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _groupService.getMyGroups(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No groups found. Create one first!"),
                      );
                    }

                    final groups = snapshot.data!.docs;

                    return ListView.separated(
                      itemCount: groups.length,
                      separatorBuilder: (c, i) => const Divider(),
                      itemBuilder: (context, index) {
                        final groupData =
                            groups[index].data() as Map<String, dynamic>;
                        final members = groupData['members'] as List<dynamic>;

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.group,
                              color: Colors.purple,
                            ),
                          ),
                          title: Text(groupData['name'] ?? "Unnamed Group"),
                          subtitle: Text("${members.length} members"),
                          onTap: () {
                            Navigator.pop(context);
                            _addMembersFromGroup(members);
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), // Light premium background
      appBar: const CustomAppHeader(
        title: "Who's Splitting?",
        subtitle: "SETUP BILL",
      ),
      body: _isLoading
          ? const LoadingStateWidget(message: "Syncing contacts...")
          : Column(
              children: [
                // 1. PARTICIPANTS LIST
                Expanded(
                  child:
                      _participants.length <=
                          1 // Only host
                      ? _buildEmptyState()
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${_participants.length} PEOPLE",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.grey[400],
                                      letterSpacing: 1.2,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _showAddParticipantsModal,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                    ),
                                    icon: const Icon(
                                      Icons.add_circle_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      "Add More",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                itemCount: _participants.length,
                                separatorBuilder: (c, i) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _buildParticipantTile(index);
                                },
                              ),
                            ),
                          ],
                        ),
                ),

                // 2. BOTTOM ACTIONS
                _buildBottomActions(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_rounded,
              size: 64,
              color: Colors.blue.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "It's just you... for now",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Add friends to split the bill with",
            style: TextStyle(color: Colors.grey[500], fontSize: 15),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showAddParticipantsModal,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text("Add People"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(int index) {
    final person = _participants[index];
    final data = person['data'];
    final type = person['type']; // 'host', 'app_user', 'guest'
    final isHost = type == 'host';
    final isAppUser = type == 'app_user';
    final isPro = data['isPro'] == true;

    // Design Variables
    final Color cardColor = isHost
        ? Colors.blue.shade50
        : (isAppUser
              ? const Color(0xFFF3E5F5)
              : Colors.white); // Purple tint for App User
    final Color borderColor = isHost
        ? Colors.blue.withValues(alpha: 0.3)
        : (isAppUser ? Colors.purple.withValues(alpha: 0.2) : Colors.transparent);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHost
                        ? Colors.blue
                        : (isAppUser ? Colors.purple : Colors.grey.shade300),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade100,
                  backgroundImage: _getAvatarImage(data['photoUrl']),
                  child: _getAvatarImage(data['photoUrl']) == null
                      ? Text(
                          (data['displayName'] ?? "?")[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isHost
                                ? Colors.blue
                                : (isAppUser
                                      ? Colors.purple
                                      : Colors.grey.shade700),
                          ),
                        )
                      : null,
                ),
              ),
              if (isAppUser || isHost)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: isHost ? Colors.blue : Colors.purple,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  data['displayName'] ?? "Unknown",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isHost)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "HOST",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              if (isPro)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    "PRO",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 8,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  Icons.phone_iphone_rounded,
                  size: 14,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  data['phoneNumber'] ?? "No number",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          trailing: isHost
              ? null
              : IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  color: Colors.red[300],
                  onPressed: () => _removeContact(index),
                ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_participants.length <= 1)
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ManualEntryScreen(
                                  participants: _participants,
                                ),
                              ),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      foregroundColor: Colors.black87,
                    ),
                    child: const Text(
                      "Enter Manually",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_participants.length <= 1)
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScanReceiptScreen(
                                  participants: _participants,
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text(
                      "Scan Receipt",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            if (_participants.length <= 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  "Add at least one friend to proceed",
                  style: TextStyle(
                    color: Colors.red[300],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- UPDATED METHODS FOR HOST & GROUP ---

  Future<void> _initializeHost() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch fresh data from Firestore to ensure we have the latest image/phone
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      Map<String, dynamic> userData;
      if (doc.exists) {
        userData = doc.data()!;
        userData['uid'] = user.uid; // Ensure UID is set
      } else {
        // Fallback if no Firestore doc
        userData = {
          'uid': user.uid,
          'displayName': user.displayName ?? "Me",
          'phoneNumber': user.phoneNumber ?? "",
          'photoUrl': user.photoURL,
          'isPro': false,
        };
      }

      setState(() {
        _participants.add({'type': 'host', 'data': userData});
      });
    } catch (e) {
      debugPrint("Error fetching host data: $e");
      // Fallback
      final userData = {
        'uid': user.uid,
        'displayName': user.displayName ?? "Me",
        'phoneNumber': user.phoneNumber ?? "",
        'photoUrl': user.photoURL,
      };
      setState(() {
        _participants.add({'type': 'host', 'data': userData});
      });
    }
  }

  Future<void> _addMembersFromGroup(List<dynamic> groupMembers) async {
    setState(() => _isLoading = true);

    // We need to verify each member.
    // Group members usually stored as {id, name, phoneNumber, photoUrl}
    // We will check if 'id' (uid) exists in 'users' collection to confirm 'app_user' status.

    try {
      final db = FirebaseFirestore.instance;

      for (var m in groupMembers) {
        String uid = m['id'];

        // 1. Check if user exists in DB
        final doc = await db.collection('users').doc(uid).get();

        if (doc.exists) {
          // Confirmed App User
          final data = doc.data()!;
          data['uid'] = uid;

          _addParticipantIfNotExists({'type': 'app_user', 'data': data});
        } else {
          // Not found in DB -> Treat as GUEST
          // Even if they were in a group, if they don't have a user account now, they are a guest.
          final guestData = {
            'uid':
                uid, // Keep the ID from group, or gen new one? Group ID is fine.
            'displayName': m['name'] ?? "Guest",
            'phoneNumber': m['phoneNumber'] ?? "",
            'photoUrl':
                null, // Don't show old avatar if they aren't a user? Or show what we have?
            // User requested "non app users are not with blue check mark".
            // If we use m['photoUrl'], we can, but type must be 'guest'.
          };
          _addParticipantIfNotExists({'type': 'guest', 'data': guestData});
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error adding group: $e")));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _removeContact(int index) {
    if (_participants[index]['type'] == 'host') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You cannot remove yourself from the bill."),
        ),
      );
      return;
    }
    setState(() {
      _participants.removeAt(index);
    });
  }
}
