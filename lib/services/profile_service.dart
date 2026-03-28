import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Update Name & Phone
  Future<void> updateProfile({String? name, String? phone}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (name != null) await user.updateDisplayName(name);

    Map<String, dynamic> data = {};
    if (name != null) data['displayName'] = name;
    if (phone != null) data['phoneNumber'] = phone;

    await _firestore.collection('users').doc(user.uid).update(data);
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

      // REMOVED: await user.updatePhotoURL(finalString);
      // ^ This was causing the crash because the text is too long for Auth.

      return finalString;
    } catch (e) {
      debugPrint("Error saving avatar: $e");
      return null;
    }
  }
}
