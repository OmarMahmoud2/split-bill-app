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

  // NEW: Save Avatar as Text (Base64)
  // NEW: Save Avatar as Text (Base64) - FIRESTORE ONLY
  Future<String?> saveAvatarAsBase64(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      // 1. Convert Image Bytes to Base64 String
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      String finalString = "data:image/jpeg;base64,$base64Image";

      // 2. Save ONLY to Firestore (This works fine)
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': finalString,
      });
      await PublicProfileService.syncFromUserDoc(force: true);

      // REMOVED: await user.updatePhotoURL(finalString);
      // ^ This was causing the crash because the text is too long for Auth.

      return finalString;
    } catch (e) {
      debugPrint("Error saving avatar: $e");
      return null;
    }
  }
}

/// Thrown when a phone number already belongs to another account.
class PhoneNumberTakenException implements Exception {
  const PhoneNumberTakenException();

  @override
  String toString() => 'phone_number_already_exists';
}
