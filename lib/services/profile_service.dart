import 'package:split_bill_app/services/my_photo.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:split_bill_app/services/public_profile_service.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Update Name & Phone
  Future<void> updateProfile({String? name, String? phone}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (name != null) await user.updateDisplayName(name);

    final userRef = _firestore.collection('users').doc(user.uid);
    final previousPhone =
        (await userRef.get()).data()?['phoneNumber']?.toString() ?? '';
    final phoneChanged =
        phone != null && phone.isNotEmpty && phone != previousPhone;
    if (phoneChanged && !await PublicProfileService.claimPhone(phone)) {
      throw const PhoneNumberTakenException();
    }

    Map<String, dynamic> data = {};
    if (name != null) data['displayName'] = name;
    if (phone != null) data['phoneNumber'] = phone;

    await userRef.update(data);
    if (phoneChanged) await PublicProfileService.releasePhone(previousPhone);
    await PublicProfileService.syncFromUserDoc(force: true);
  }

  /// Largest stored photo (the data URL lives in the user doc).
  static const int maxAvatarBytes = 150 * 1024;

  /// Stores [imageFile] (already cropped, <= 512 px JPEG) as a base64 data
  /// URL in `users/{uid}.photoUrl`. Returns null on failure or if too big.
  Future<String?> saveAvatarAsBase64(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final bytes = await imageFile.readAsBytes();
      if (bytes.length > maxAvatarBytes) return null;
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      // Firestore only: Auth's photoURL is too short for a data URL.
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': dataUrl,
      });
      await PublicProfileService.syncFromUserDoc(force: true);
      MyPhoto.set(dataUrl);
      return dataUrl;
    } catch (e) {
      debugPrint('Error saving avatar: $e');
      return null;
    }
  }

  /// Clears the photo so the pal avatar shows again.
  Future<bool> removeAvatar() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': FieldValue.delete(),
      });
      MyPhoto.set(null);
      await PublicProfileService.syncFromUserDoc(force: true);
      return true;
    } catch (e) {
      debugPrint('Error removing avatar: $e');
      return false;
    }
  }
}

/// Thrown when a phone number already belongs to another account.
class PhoneNumberTakenException implements Exception {
  const PhoneNumberTakenException();

  @override
  String toString() => 'phone_number_already_exists';
}
