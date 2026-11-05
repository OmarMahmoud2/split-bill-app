import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'package:split_bill_app/widgets/premium_modal.dart';

/// Gate for Pro-only features: Pro users pass straight through, everyone
/// else sees the paywall first.
class ProAccess {
  ProAccess({
    Future<Map<String, dynamic>?> Function()? loadUser,
    Future<bool?> Function(BuildContext context)? showPaywall,
  }) : _loadUser = loadUser ?? _currentUserDoc,
       _showPaywall = showPaywall ?? PremiumModal.show;

  static ProAccess instance = ProAccess();

  final Future<Map<String, dynamic>?> Function() _loadUser;
  final Future<bool?> Function(BuildContext context) _showPaywall;

  Future<bool> isPro() async {
    try {
      return RevenueCatService.isUserActivePremium(await _loadUser());
    } catch (_) {
      return false;
    }
  }

  /// True when the user is Pro, or becomes Pro from the paywall.
  Future<bool> ensure(BuildContext context) async {
    if (await isPro()) return true;
    if (!context.mounted) return false;
    final purchased = await _showPaywall(context);
    return purchased == true || await isPro();
  }

  static Future<Map<String, dynamic>?> _currentUserDoc() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return doc.data();
  }
}
