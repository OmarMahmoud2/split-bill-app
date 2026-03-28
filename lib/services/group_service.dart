import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Create a new Group
  Future<void> createGroup(
    String groupName,
    List<Map<String, dynamic>> members,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // We must include the creator in the members list if not already there
    bool creatorExists = members.any((m) => m['id'] == user.uid);
    if (!creatorExists) {
      members.add({
        'id': user.uid,
        'name': user.displayName ?? "Me",
        'phoneNumber': user.phoneNumber,
        'photoUrl': user.photoURL,
        'isGuest': false,
      });
    }

    // Save simple list of UIDs for querying
    List<String> memberIds = members.map((m) => m['id'] as String).toList();

    await _firestore.collection('groups').add({
      'name': groupName,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'members': members, // Full details (for display)
      'memberIds': memberIds, // Simple list (for searching "My Groups")
    });
  }

  // 3. Update Group Members
  Future<void> updateGroup(
    String groupId,
    List<Map<String, dynamic>> newMembers,
  ) async {
    // Also update the simple ID list
    List<String> memberIds = newMembers.map((m) => m['id'] as String).toList();

    await _firestore.collection('groups').doc(groupId).update({
      'members': newMembers,
      'memberIds': memberIds,
    });
  }

  // 4. Delete Group
  Future<void> deleteGroup(String groupId) async {
    await _firestore.collection('groups').doc(groupId).delete();
  }

  // 2. Get "My Groups"
  Stream<QuerySnapshot> getMyGroups() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('groups')
        .where('memberIds', arrayContains: user.uid)
        // .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
