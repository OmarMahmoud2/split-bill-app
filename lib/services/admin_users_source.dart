import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/screens/admin/admin_user_filters.dart';

/// One page of users plus the cursor for the next one.
class AdminUsersPage {
  const AdminUsersPage(this.entries, {this.cursor, this.hasMore = false});

  final List<AdminUserEntry> entries;

  /// Opaque cursor (a DocumentSnapshot for Firestore).
  final Object? cursor;
  final bool hasMore;
}

/// Where the admin Users list reads from; swapped for a fake in tests.
abstract class AdminUsersSource {
  Future<AdminUsersPage> fetchPage({Object? cursor, int limit});

  /// Server-side lookups for an email/phone prefix or a uid.
  Future<List<AdminUserEntry>> search(String query);
}

/// Firestore: `users` ordered by document id (includes docs without
/// `createdAt`), cursor pagination with startAfterDocument.
class FirestoreAdminUsersSource implements AdminUsersSource {
  FirestoreAdminUsersSource([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Future<AdminUsersPage> fetchPage({
    Object? cursor,
    int limit = adminUsersPageSize,
  }) async {
    Query<Map<String, dynamic>> q = _users
        .orderBy(FieldPath.documentId)
        .limit(limit);
    if (cursor is DocumentSnapshot) q = q.startAfterDocument(cursor);
    final snap = await q.get();
    return AdminUsersPage(
      [for (final d in snap.docs) AdminUserEntry(d.id, d.data())],
      cursor: snap.docs.isEmpty ? cursor : snap.docs.last,
      hasMore: snap.docs.length == limit,
    );
  }

  @override
  Future<List<AdminUserEntry>> search(String query) async {
    final q = query.trim();
    switch (adminSearchKindFor(q)) {
      case AdminSearchKind.email:
        return _prefix('email', q.toLowerCase());
      case AdminSearchKind.phone:
        final digits = q.replaceAll(RegExp(r'\D'), '');
        return _prefix('phoneNumber', '+$digits');
      case AdminSearchKind.uid:
        final doc = await _users.doc(q).get();
        final data = doc.data();
        return data == null ? const [] : [AdminUserEntry(doc.id, data)];
      case AdminSearchKind.text:
      case AdminSearchKind.none:
        return const [];
    }
  }

  Future<List<AdminUserEntry>> _prefix(String field, String prefix) async {
    final snap = await _users
        .where(field, isGreaterThanOrEqualTo: prefix)
        .where(field, isLessThan: adminPrefixEnd(prefix))
        .limit(adminUsersPageSize)
        .get();
    return [for (final d in snap.docs) AdminUserEntry(d.id, d.data())];
  }
}
