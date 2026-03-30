import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/services/notification_service.dart';

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
      final result = await _auth.signInWithCredential(credential);
      await _handlePostSignIn(result.user);
      return result;
    } on FirebaseAuthException catch (e) {
      throw _formatAuthError(e);
    } catch (e) {
      if (e.toString().toLowerCase().contains('canceled')) {
        return null;
      }
      debugPrint("Error signing in with Google: $e");
      throw 'Unable to sign in with Google right now.';
    }
  }

  Future<UserCredential?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oAuthProvider = OAuthProvider('apple.com');
      final authCredential = oAuthProvider.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );

      final result = await _auth.signInWithCredential(authCredential);
      await _handlePostSignIn(result.user);
      return result;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      throw 'Unable to sign in with Apple right now.';
    } on FirebaseAuthException catch (e) {
      throw _formatAuthError(e);
    } catch (e) {
      debugPrint("Error signing in with Apple: $e");
      throw 'Unable to sign in with Apple right now.';
    }
  }

  // 4. Sign Out
  Future<void> signOut() async {
    await _runBestEffortCleanup(
      NotificationService().clearStoredTokenForCurrentUser,
    );
    await _runBestEffortCleanup(RevenueCatService.logoutUser);
    await _runBestEffortCleanup(_googleSignIn.signOut);

    try {
      await _auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _formatAuthError(e);
    } catch (e) {
      debugPrint('Error signing out: $e');
      throw 'Unable to sign you out right now. Please try again.';
    }
  }

  // 5. Delete Account (Irreversible) - WITH RE-AUTHENTICATION
  Future<void> deleteAccount({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw 'No signed-in account was found.';
    }

    try {
      // STEP 1: Re-authenticate the user (required by Firebase)
      await _reauthenticateUser(password: password);

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
      await _runBestEffortCleanup(
        NotificationService().clearStoredTokenForCurrentUser,
      );
      await _runBestEffortCleanup(RevenueCatService.logoutUser);
      await _runBestEffortCleanup(_googleSignIn.signOut);
      await _runBestEffortCleanup(_auth.signOut);
    } on FirebaseAuthException catch (e) {
      throw _formatSensitiveAuthError(e);
    } on String {
      rethrow;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      throw 'Unable to delete your account right now. Please try again.';
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
      await _handlePostSignIn(result.user);
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
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _handlePostSignIn(result.user);
      return result;
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
      case 'invalid-credential':
        return 'That sign-in method could not be verified. Please try again.';
      case 'account-exists-with-different-credential':
        return 'This email is already linked to another sign-in method.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  // Helper: Re-authenticate user before sensitive operations
  String _formatSensitiveAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
      case 'credential-too-old-login-again':
        return 'Please sign in again before trying that action.';
      case 'wrong-password':
        return 'The password you entered is not correct.';
      default:
        return _formatAuthError(e);
    }
  }

  Future<void> _reauthenticateUser({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw 'No signed-in account was found.';

    final providers = user.providerData
        .map((provider) => provider.providerId)
        .where((providerId) => providerId.isNotEmpty)
        .toSet();

    if ((password?.trim().isNotEmpty ?? false) && providers.contains('password')) {
      final email = user.email;
      if (email == null || email.isEmpty) {
        throw 'This account is missing an email address. Please sign in again.';
      }
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password!.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (providers.contains('google.com')) {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw 'Re-authentication was cancelled.';
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return;
    }

    if (providers.contains('apple.com')) {
      await user.reauthenticateWithProvider(AppleAuthProvider());
      return;
    }

    if (providers.contains('password')) {
      throw 'Enter your current password to continue.';
    }

    throw 'Please sign out and sign in again to continue.';
  }

  Future<void> _handlePostSignIn(User? user) async {
    if (user == null) return;
    await NotificationService().syncTokenForCurrentUser(force: true);
    await RevenueCatService.syncCurrentUser();

    try {
      final platformStr = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'loginPlatform': platformStr,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error updating loginPlatform: $e");
    }
  }

  Future<void> _runBestEffortCleanup(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Auth cleanup step failed: $e');
    }
  }
}
