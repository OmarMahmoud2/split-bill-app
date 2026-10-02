import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesService {
  UserPreferencesService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  static const String defaultCurrencyCode = 'USD';
  static const String defaultLocaleCode = 'en';
  static const String pendingPaymentMethodsKey =
      'pending_onboarding_payment_methods';

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> ensureDefaults(
    User user, {
    String? localeCode,
    String? currencyCode,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};
    final pendingPaymentMethods = await _loadPendingPaymentMethods();
    final remoteMethods = data['customPaymentMethods'];
    final hasRemotePaymentMethods =
        remoteMethods is List && remoteMethods.isNotEmpty;

    final updates = <String, dynamic>{
      if ((data['displayName'] as String?)?.trim().isEmpty ?? true)
        'displayName': user.displayName ?? 'User',
      if (!data.containsKey('email') && user.email != null) 'email': user.email,
      if ((data['photoUrl'] as String?)?.trim().isEmpty ?? true)
        'photoUrl': user.photoURL,
      if (!data.containsKey('localeCode'))
        'localeCode': localeCode ?? defaultLocaleCode,
      if (!data.containsKey('currencyCode'))
        'currencyCode': currencyCode ?? defaultCurrencyCode,
      if (pendingPaymentMethods.isNotEmpty && !hasRemotePaymentMethods)
        'customPaymentMethods': pendingPaymentMethods,
    };

    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }

    if (pendingPaymentMethods.isNotEmpty &&
        (updates.containsKey('customPaymentMethods') ||
            hasRemotePaymentMethods)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(pendingPaymentMethodsKey);
    }
  }

  Future<void> updatePreference(String key, dynamic value) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set({
      key: value,
    }, SetOptions(merge: true));
  }

  Future<List<Map<String, String>>> _loadPendingPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(pendingPaymentMethodsKey);
    if (rawValue == null || rawValue.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((entry) {
            final name = entry['name']?.toString().trim() ?? '';
            final value = entry['value']?.toString().trim() ?? '';
            if (name.isEmpty || value.isEmpty) return null;
            return {'name': name, 'value': value};
          })
          .whereType<Map<String, String>>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
