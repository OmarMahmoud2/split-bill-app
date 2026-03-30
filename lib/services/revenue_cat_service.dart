import 'dart:io';
import 'dart:async';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/config/api_keys.dart';

/// Service to manage RevenueCat integration and premium status
class RevenueCatService {
  static final String _apiKey = kIsWeb
      ? ''
      : (Platform.isIOS
            ? ApiKeys.revenueCatAppleKey
            : ApiKeys.revenueCatGoogleKey);

  static const String _entitlementId = 'premium';
  static bool _isConfigured = false;
  static StreamSubscription<User?>? _authSubscription;

  /// Initialize RevenueCat SDK
  /// Call this in main.dart before runApp()
  static Future<void> initialize() async {
    if (kIsWeb || _isConfigured) return;
    if (_apiKey.startsWith('goog_DoNot') || _apiKey.startsWith('appl_DoNot')) {
      if (kDebugMode) {
        debugPrint('⚠️ RevenueCat not configured in ApiKeys');
      }
      return;
    }

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);

    final configuration = PurchasesConfiguration(_apiKey);
    await Purchases.configure(configuration);
    _isConfigured = true;

    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChange,
    );
    await _handleAuthChange(FirebaseAuth.instance.currentUser);
  }

  /// Check if current user has active premium entitlement
  static Future<bool> isPremium() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isActive =
          customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
      return isActive;
    } catch (e) {
      if (kDebugMode) debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  /// Get available premium packages
  static Future<List<Package>> getPremiumPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        return offerings.current!.availablePackages;
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching packages: $e');
      return [];
    }
  }

  /// Purchase premium package
  static Future<bool> purchasePremium(Package package) async {
    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final customerInfo = purchaseResult.customerInfo;
      final isPremiumActive =
          customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;

      if (isPremiumActive) {
        await _syncPremiumStatus();
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        if (kDebugMode) debugPrint('Purchase error: $e');
      }
      return false;
    }
  }

  /// Restore previous purchases
  static Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPremiumActive =
          customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;

      await _syncPremiumStatus();
      return isPremiumActive;
    } catch (e) {
      if (kDebugMode) debugPrint('Error restoring purchases: $e');
      return false;
    }
  }

  /// Sync premium status between RevenueCat and Firestore
  static Future<void> _syncPremiumStatus([User? currentUser]) async {
    try {
      final user = currentUser ?? FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final isPremiumActive = await isPremium();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'isPremium': isPremiumActive,
      }, SetOptions(merge: true));

      if (kDebugMode) debugPrint('✅ Synced premium status: $isPremiumActive');
    } catch (e) {
      if (kDebugMode) debugPrint('Error syncing premium status: $e');
    }
  }

  static Future<void> _handleAuthChange(User? user) async {
    if (!_isConfigured) return;

    try {
      if (user == null) {
        await Purchases.logOut();
        return;
      }

      await Purchases.logIn(user.uid);
      if (user.email != null && user.email!.isNotEmpty) {
        await Purchases.setEmail(user.email!);
      }
      await _syncPremiumStatus(user);
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat auth sync error: $e');
    }
  }

  /// Call this when user logs in
  static Future<void> loginUser(String userId) async {
    try {
      if (!_isConfigured) {
        await initialize();
      }
      await Purchases.logIn(userId);
      await _syncPremiumStatus();
    } catch (e) {
      if (kDebugMode) debugPrint('Error logging in to RevenueCat: $e');
    }
  }

  /// Call this when user logs out
  static Future<void> logoutUser() async {
    try {
      if (!_isConfigured) return;
      await Purchases.logOut();
    } catch (e) {
      if (kDebugMode) debugPrint('Error logging out from RevenueCat: $e');
    }
  }

  static Future<void> syncCurrentUser() async {
    await _handleAuthChange(FirebaseAuth.instance.currentUser);
  }
}
