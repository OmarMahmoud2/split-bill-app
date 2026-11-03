import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Guests opening a shared bill sign in anonymously so Firestore rules can
/// require auth. Anonymous sessions are never treated as app members.
class GuestSession {
  GuestSession._();

  static Future<User?>? _pending;

  /// Returns the current user, signing in anonymously if nobody is signed in.
  static Future<User?> ensureSignedIn() {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return Future.value(current);
    return _pending ??= _signInAnonymously().whenComplete(() => _pending = null);
  }

  static Future<User?> _signInAnonymously() async {
    try {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      return credential.user;
    } catch (e) {
      debugPrint('Guest anonymous sign-in failed: $e');
      return null;
    }
  }
}

/// The signed-in app member, or null for signed-out and anonymous guests.
User? memberOrNull(User? user) =>
    (user == null || user.isAnonymous) ? null : user;
