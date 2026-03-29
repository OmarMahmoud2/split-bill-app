import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> ensureDefaults(
    User user, {
    String? localeCode,
    String? currencyCode,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    final data = snapshot.data() ?? <String, dynamic>{};

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
    };

    if (updates.isNotEmpty) {
      await docRef.set(updates, SetOptions(merge: true));
    }
  }

  Future<void> updatePreference(String key, dynamic value) async {
    final uid = currentUserId;
    if (uid == null) return;

    await _firestore.collection('users').doc(uid).set({
      key: value,
    }, SetOptions(merge: true));
  }
}
