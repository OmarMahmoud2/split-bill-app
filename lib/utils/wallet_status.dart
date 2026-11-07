import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';

/// Pro status and points of the signed-in user; null when unknown (signed
/// out, offline, Firebase not set up in a test).
Future<({bool pro, int points})?> loadWalletStatus() async {
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final data =
        (await FirebaseFirestore.instance.collection('users').doc(uid).get())
            .data();
    return (
      pro: RevenueCatService.isUserActivePremium(data),
      points: (data?['points'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    return null;
  }
}
