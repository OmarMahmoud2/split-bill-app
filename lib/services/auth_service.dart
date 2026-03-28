import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';

class AuthService {
  // 1. Create instances of the tools we need
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 2. Stream to listen to user changes (LoggedIn vs LoggedOut)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 3. The "Sign In With Google" Function
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // A. Trigger the Google Pop-up
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If user cancelled the pop-up
      if (googleUser == null) return null;

      // B. Obtain the auth details (tokens) from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // C. Create a new credential for Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // D. Finally, sign in to Firebase with that credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      return null;
    }
  }

  // 4. Sign Out
  Future<void> signOut() async {
    await RevenueCatService.logoutUser();
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // 5. Delete Account (Irreversible) - WITH RE-AUTHENTICATION
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // STEP 1: Re-authenticate the user (required by Firebase)
      await _reauthenticateUser();

      final uid = user.uid;
      final db = FirebaseFirestore.instance;

      // STEP 2: Delete all user data from Firestore
      final batch = db.batch();

      // A. Delete bills where user is host
      final hostBills = await db
          .collection('bills')
          .where('hostId', isEqualTo: uid)
          .get();
      for (var doc in hostBills.docs) {
        batch.delete(doc.reference);
      }

      // B. Delete groups where user is owner
      final userGroups = await db
          .collection('groups')
          .where('ownerId', isEqualTo: uid)
          .get();
      for (var doc in userGroups.docs) {
        batch.delete(doc.reference);
      }

      // C. Delete user's notifications subcollection
      final notifications = await db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      // D. Delete user document
      batch.delete(db.collection('users').doc(uid));

      // Commit all deletions
      await batch.commit();

      // STEP 3: Delete from Firebase Auth
      await user.delete();

      // STEP 4: Sign out from all providers
      await RevenueCatService.logoutUser();
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow; // Re-throw so UI can handle it
    }
  }

  // --- EMAIL / PASSWORD METHODS ---

  // 6. Sign Up with Email
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await user.updateDisplayName(name);
        await user.reload();
        if (!user.emailVerified) {
          await user.sendEmailVerification();
        }
      }
      return result;
    } on FirebaseAuthException catch (e) {
      throw _formatAuthError(e);
    } catch (e) {
      throw 'An unknown error occurred';
    }
  }

  // 7. Sign In with Email
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _formatAuthError(e);
    } catch (e) {
      throw 'An unknown error occurred';
    }
  }

  // 8. Reset Password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _formatAuthError(e);
    } catch (e) {
      throw 'An unknown error occurred';
    }
  }

  // Helper: Friendly Error Messages
  String _formatAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user has been disabled.';
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'The email address is already in use by another account.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  // Helper: Re-authenticate user before sensitive operations
  Future<void> _reauthenticateUser() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user logged in');

    // Check the provider used to sign in
    final providerId = user.providerData.isNotEmpty
        ? user.providerData.first.providerId
        : 'unknown';

    if (providerId == 'google.com') {
      // GOOGLE RE-AUTH
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Re-authentication cancelled');
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } else if (providerId == 'apple.com') {
      // APPLE RE-AUTH
      await user.reauthenticateWithProvider(AppleAuthProvider());
    } else {
      // Fallback or Unknown
      // Try using AppleAuthProvider as default or throw error
      try {
        await user.reauthenticateWithProvider(AppleAuthProvider());
      } catch (e) {
        // If generic retry fails
        debugPrint("Re-auth failed for provider $providerId: $e");
        throw Exception("Please sign out and sign in again to proceed.");
      }
    }
  }
}
