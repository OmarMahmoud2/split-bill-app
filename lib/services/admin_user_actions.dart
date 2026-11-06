/// Admin actions on one user, each written together with an `adminAudit`
/// entry `{adminUid, action, targetUid, at, details}`.
///
/// The action logic only builds [AdminWrite]s; an [AdminActionBackend]
/// commits them (Firestore batches in the app, a fake in tests). Until the
/// `adminAudit` rule is deployed the audit write is rejected; then the change
/// is retried without it and [AdminActionResult.auditLogged] is false, unless
/// the build sets `--dart-define=ADMIN_AUDIT_REQUIRED=true`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

const bool kAdminAuditRequired = bool.fromEnvironment(
  'ADMIN_AUDIT_REQUIRED',
  defaultValue: false,
);

/// Placeholder values the backend maps to Firestore sentinels.
enum AdminValue { serverTime, deleteField }

enum AdminWriteKind { set, update, delete }

/// One document write. [data] may contain [AdminValue]s.
class AdminWrite {
  const AdminWrite.set(this.path, this.data, {this.merge = true})
    : kind = AdminWriteKind.set;
  const AdminWrite.update(this.path, this.data)
    : kind = AdminWriteKind.update,
      merge = false;
  const AdminWrite.delete(this.path)
    : kind = AdminWriteKind.delete,
      data = const {},
      merge = false;

  final AdminWriteKind kind;
  final String path;
  final Map<String, Object?> data;
  final bool merge;

  @override
  String toString() => 'AdminWrite(${kind.name} $path $data)';
}

/// Storage operations the actions need.
abstract class AdminActionBackend {
  /// Commits [writes] atomically (implementations may chunk very large
  /// lists; the last chunk carries the audit entry).
  Future<void> commit(List<AdminWrite> writes);

  /// Paths of documents in [collection] where [field] == [value].
  Future<List<String>> queryPaths(
    String collection,
    String field,
    Object value,
  );

  /// Paths of all documents in the subcollection at [path].
  Future<List<String>> listCollection(String path);

  /// Data of the document at [path], or null.
  Future<Map<String, dynamic>?> getDoc(String path);

  /// A fresh id for a new document in [collection].
  String newId(String collection);

  /// Whether [error] means the security rules refused the write.
  bool isPermissionDenied(Object error);
}

enum AdminActionError { selfTarget, invalidAmount, confirmationMismatch }

class AdminActionException implements Exception {
  const AdminActionException(this.error);
  final AdminActionError error;
  @override
  String toString() => 'AdminActionException(${error.name})';
}

class AdminActionResult {
  const AdminActionResult({
    required this.auditLogged,
    this.authUpdated = false,
  });
  final bool auditLogged;

  /// For suspend/unsuspend: the backend also disabled or enabled the Firebase
  /// Auth account (and revoked sessions). False means only the Firestore flag
  /// was written.
  final bool authUpdated;
}

/// Disables or re-enables the Auth account via the backend, which also writes
/// the suspension flags and the audit entry. Returns true when it succeeded.
typedef AccountDisabler =
    Future<bool> Function(String uid, {required bool disabled, String? reason});

/// Points are clamped to this range.
const int adminMaxPoints = 999999;

/// The typed confirmation for "delete user data" must equal the user's
/// email (case-insensitive) or, when there is none, their uid.
bool isDeleteConfirmationValid({
  required String typed,
  required String uid,
  String? email,
}) {
  final t = typed.trim();
  if (t.isEmpty) return false;
  final e = email?.trim() ?? '';
  if (e.isNotEmpty) return t.toLowerCase() == e.toLowerCase();
  return t == uid;
}

/// What the delete confirmation asks the admin to type.
String deleteConfirmationTarget({required String uid, String? email}) {
  final e = email?.trim() ?? '';
  return e.isNotEmpty ? e : uid;
}

class AdminUserActions {
  AdminUserActions({
    required this.backend,
    required this.adminUid,
    this.accountDisabler,
  });

  final AdminActionBackend backend;
  final String adminUid;
  final AccountDisabler? accountDisabler;

  static const _batchLimit = 400;

  String _user(String uid) => 'users/$uid';

  AdminWrite _audit(String action, String targetUid, Map<String, Object?> d) =>
      AdminWrite.set('adminAudit/${backend.newId('adminAudit')}', {
        'adminUid': adminUid,
        'action': action,
        'targetUid': targetUid,
        'at': AdminValue.serverTime,
        'details': d,
      }, merge: false);

  Future<AdminActionResult> _run(
    List<AdminWrite> changes,
    AdminWrite audit,
  ) async {
    try {
      await backend.commit([...changes, audit]);
      return const AdminActionResult(auditLogged: true);
    } catch (e) {
      if (kAdminAuditRequired || !backend.isPermissionDenied(e)) rethrow;
      // The audit rule may not be deployed yet: keep the action working and
      // tell the caller nothing was logged. A real rule refusal of the
      // change itself rethrows here.
      await backend.commit(changes);
      return const AdminActionResult(auditLogged: false);
    }
  }

  /// Sets the balance to [newPoints] (0..[adminMaxPoints]).
  Future<AdminActionResult> setPoints(
    String uid, {
    required int currentPoints,
    required int newPoints,
  }) {
    if (newPoints < 0 || newPoints > adminMaxPoints) {
      throw const AdminActionException(AdminActionError.invalidAmount);
    }
    return _run(
      [
        AdminWrite.update(_user(uid), {'points': newPoints}),
      ],
      _audit('points.set', uid, {
        'from': currentPoints,
        'to': newPoints,
        'delta': newPoints - currentPoints,
      }),
    );
  }

  /// Manual Pro override. Uses only rule-protected fields so users can't
  /// fake it; `premiumStore: 'admin_override'` marks it for the backend.
  Future<AdminActionResult> setPremium(String uid, {required bool grant}) {
    final fields = grant
        ? <String, Object?>{
            'isPremium': true,
            'premiumExpiresAt': null,
            'premiumEntitlementId': 'premium',
            'premiumProductId': 'admin_granted_lifetime',
            'premiumStore': 'admin_override',
            'premiumWillRenew': false,
            'premiumUpdatedAt': AdminValue.serverTime,
          }
        : <String, Object?>{
            'isPremium': false,
            'premiumWillRenew': false,
            'premiumUpdatedAt': AdminValue.serverTime,
          };
    return _run([
      AdminWrite.set(_user(uid), fields),
    ], _audit(grant ? 'premium.grant' : 'premium.revoke', uid, const {}));
  }

  /// Grants or removes admin. An admin can't remove their own role.
  Future<AdminActionResult> setAdmin(String uid, {required bool admin}) {
    if (!admin && uid == adminUid) {
      throw const AdminActionException(AdminActionError.selfTarget);
    }
    return _run([
      AdminWrite.update(_user(uid), {'isAdmin': admin}),
    ], _audit(admin ? 'admin.grant' : 'admin.revoke', uid, const {}));
  }

  /// Suspends or unsuspends. With an [accountDisabler] the backend disables
  /// the Firebase Auth account too (sessions are revoked, so a suspended user
  /// cannot keep using a live token); it also writes the flags and the audit
  /// entry. If it is unavailable, the Firestore flag is written here instead
  /// ([AdminActionResult.authUpdated] is then false).
  Future<AdminActionResult> setSuspended(
    String uid, {
    required bool suspended,
    String? reason,
  }) async {
    if (suspended && uid == adminUid) {
      throw const AdminActionException(AdminActionError.selfTarget);
    }
    if (accountDisabler != null &&
        await accountDisabler!(uid, disabled: suspended, reason: reason)) {
      return const AdminActionResult(auditLogged: true, authUpdated: true);
    }
    return _run(
      [
        AdminWrite.set(
          _user(uid),
          suspended
              ? {
                  'suspended': true,
                  'suspendedAt': AdminValue.serverTime,
                  'suspendedBy': adminUid,
                }
              : {
                  'suspended': false,
                  'suspendedAt': AdminValue.deleteField,
                  'suspendedBy': AdminValue.deleteField,
                },
        ),
      ],
      _audit(suspended ? 'user.suspend' : 'user.unsuspend', uid, {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      }),
    );
  }

  /// Frees `phoneClaims/{phone}` so the number can be used again; with
  /// [clearPhone] also removes it from the profile (the user is asked for a
  /// phone again on next launch, which they can skip).
  Future<AdminActionResult> resetPhoneClaim(
    String uid, {
    required String phone,
    bool clearPhone = false,
  }) {
    return _run(
      [
        AdminWrite.delete('phoneClaims/$phone'),
        if (clearPhone)
          AdminWrite.set(_user(uid), {
            'phoneNumber': AdminValue.deleteField,
            'isoCode': AdminValue.deleteField,
          }),
      ],
      _audit('phone.reset', uid, {
        'phone': phone,
        'clearedProfile': clearPhone,
      }),
    );
  }

  /// Audit-only entry after a push was sent from the notification sheet.
  Future<AdminActionResult> logNotificationSent(
    String uid, {
    required String title,
  }) => _run(const [], _audit('notification.send', uid, {'title': title}));

  /// Deletes the user's Firestore data: notifications, hosted bills, groups
  /// they created, public profile, their phone claim and the user doc. The
  /// Firebase Auth account is NOT deleted (needs the Admin SDK backend).
  Future<AdminActionResult> deleteUserData(
    String uid, {
    required String typedConfirmation,
    String? email,
    String? phone,
  }) async {
    if (!isDeleteConfirmationValid(
      typed: typedConfirmation,
      uid: uid,
      email: email,
    )) {
      throw const AdminActionException(AdminActionError.confirmationMismatch);
    }
    final paths = <String>{
      ...await backend.listCollection('users/$uid/notifications'),
      ...await backend.queryPaths('bills', 'hostId', uid),
      ...await backend.queryPaths('groups', 'createdBy', uid),
      ...await backend.queryPaths('groups', 'ownerId', uid),
      'publicProfiles/$uid',
    };
    final p = phone?.trim() ?? '';
    if (p.isNotEmpty) {
      final claim = await backend.getDoc('phoneClaims/$p');
      if (claim != null && claim['uid'] == uid) paths.add('phoneClaims/$p');
    }
    final deletes = [for (final path in paths) AdminWrite.delete(path)];
    final audit = _audit('user.deleteData', uid, {
      'deletedDocs': deletes.length + 1,
      'email': ?email,
    });
    // Large accounts: commit everything but the user doc in chunks, then the
    // user doc with the audit entry last.
    for (var i = 0; i < deletes.length; i += _batchLimit) {
      final end = (i + _batchLimit).clamp(0, deletes.length);
      await backend.commit(deletes.sublist(i, end));
    }
    return _run([AdminWrite.delete(_user(uid))], audit);
  }
}

/// Firestore implementation of [AdminActionBackend].
class FirestoreAdminActionBackend implements AdminActionBackend {
  FirestoreAdminActionBackend([FirebaseFirestore? db])
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Object? _value(Object? v) => switch (v) {
    AdminValue.serverTime => FieldValue.serverTimestamp(),
    AdminValue.deleteField => FieldValue.delete(),
    Map<String, Object?> m => {
      for (final e in m.entries) e.key: _value(e.value),
    },
    _ => v,
  };

  Map<String, Object?> _data(Map<String, Object?> d) => {
    for (final e in d.entries) e.key: _value(e.value),
  };

  @override
  Future<void> commit(List<AdminWrite> writes) async {
    if (writes.isEmpty) return;
    final batch = _db.batch();
    for (final w in writes) {
      final ref = _db.doc(w.path);
      switch (w.kind) {
        case AdminWriteKind.set:
          batch.set(ref, _data(w.data), SetOptions(merge: w.merge));
        case AdminWriteKind.update:
          batch.update(ref, _data(w.data));
        case AdminWriteKind.delete:
          batch.delete(ref);
      }
    }
    await batch.commit();
  }

  @override
  Future<List<String>> queryPaths(
    String collection,
    String field,
    Object value,
  ) async {
    final snap = await _db
        .collection(collection)
        .where(field, isEqualTo: value)
        .get();
    return [for (final d in snap.docs) d.reference.path];
  }

  @override
  Future<List<String>> listCollection(String path) async {
    final snap = await _db.collection(path).get();
    return [for (final d in snap.docs) d.reference.path];
  }

  @override
  Future<Map<String, dynamic>?> getDoc(String path) async =>
      (await _db.doc(path).get()).data();

  @override
  String newId(String collection) => _db.collection(collection).doc().id;

  @override
  bool isPermissionDenied(Object error) =>
      error is FirebaseException && error.code == 'permission-denied';
}
