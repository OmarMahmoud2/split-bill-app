import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:split_bill_app/services/guest_session.dart';

/// What other people may see about a user: name, avatar and payment handles.
/// Full user docs (phone, tokens, points) stay private to their owner.
class PublicProfileService {
  PublicProfileService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static bool _syncedThisSession = false;

  /// Mirrors the signed-in user's public fields into publicProfiles/{uid}
  /// and makes sure their phone number is claimed.
  static Future<void> syncFromUserDoc({bool force = false}) async {
    final user = memberOrNull(FirebaseAuth.instance.currentUser);
    if (user == null || (_syncedThisSession && !force)) return;
    _syncedThisSession = true;

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) return;

      await _db.collection('publicProfiles').doc(user.uid).set({
        'displayName': data['displayName'] ?? user.displayName,
        'photoUrl': data['photoUrl'] ?? user.photoURL,
        'customPaymentMethods': data['customPaymentMethods'] ?? const [],
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final phone = data['phoneNumber']?.toString() ?? '';
      if (phone.isNotEmpty) await claimPhone(phone);
    } catch (e) {
      debugPrint('Public profile sync failed: $e');
    }
  }

  /// Reads another user's public profile, shaped like a user doc
  /// (uid, displayName, photoUrl, customPaymentMethods).
  static Future<Map<String, dynamic>?> fetch(String uid) async {
    try {
      final doc = await _db.collection('publicProfiles').doc(uid).get();
      if (doc.exists) return {...doc.data()!, 'uid': uid};
    } catch (e) {
      debugPrint('Public profile read failed for $uid: $e');
    }

    // Users who haven't opened 1.2.0 yet have no public profile. The full doc
    // is still readable until the Stage B rules ship.
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return null;
      return {
        'uid': uid,
        'displayName': data['displayName'],
        'photoUrl': data['photoUrl'],
        'customPaymentMethods': data['customPaymentMethods'],
        'paymentMethods': data['paymentMethods'],
      };
    } catch (e) {
      debugPrint('Legacy profile read failed for $uid: $e');
      return null;
    }
  }

  /// Claims [phone] for the signed-in user. Returns false when another
  /// account already owns it.
  static Future<bool> claimPhone(String phone) async {
    final user = memberOrNull(FirebaseAuth.instance.currentUser);
    if (user == null || phone.isEmpty) return false;

    final ref = _db.collection('phoneClaims').doc(phone);
    return _db.runTransaction((transaction) async {
      final claim = await transaction.get(ref);
      if (claim.exists) return claim.data()?['uid'] == user.uid;
      transaction.set(ref, {
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  /// Frees a number the signed-in user no longer uses.
  static Future<void> releasePhone(String phone) async {
    final user = memberOrNull(FirebaseAuth.instance.currentUser);
    if (user == null || phone.isEmpty) return;

    final ref = _db.collection('phoneClaims').doc(phone);
    try {
      final claim = await ref.get();
      if (claim.data()?['uid'] == user.uid) await ref.delete();
    } catch (e) {
      debugPrint('Phone claim release failed: $e');
    }
  }
}
