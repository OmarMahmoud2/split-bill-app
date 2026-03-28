import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserPreferencesService {
  UserPreferencesService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _authOverride = auth,
       _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const String defaultCurrencyCode = 'USD';
  static const String defaultLocaleCode = 'en';
  static const String defaultThemeMode = 'system';

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> ensureDefaults(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'displayName': user.displayName ?? 'User',
      'email': user.email,
      'photoUrl': user.photoURL,
      'themeMode': defaultThemeMode,
      'localeCode': defaultLocaleCode,
      'currencyCode': defaultCurrencyCode,
    }, SetOptions(merge: true));
  }

  Future<void> updatePreference(String key, dynamic value) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set({
      key: value,
    }, SetOptions(merge: true));
  }

  ThemeMode parseThemeMode(String? rawValue) {
    switch (rawValue) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
