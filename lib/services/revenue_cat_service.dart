import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/config/api_keys.dart';
import 'package:split_bill_app/config/backend_config.dart';

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
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_handleAuthChange(user));
    });
    Purchases.addCustomerInfoUpdateListener((_) {
      unawaited(syncPremiumStatus());
    });
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
        await syncPremiumStatus();
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

      await syncPremiumStatus();
      return isPremiumActive;
    } catch (e) {
      if (kDebugMode) debugPrint('Error restoring purchases: $e');
      return false;
    }
  }

  /// Ask the backend to sync premium status from RevenueCat into Firestore.
  static Future<bool> syncPremiumStatus([User? currentUser]) async {
    try {
      final user = currentUser ?? FirebaseAuth.instance.currentUser;
      if (user == null || kIsWeb) return false;

      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) return false;

      final response = await http.post(
        BackendConfig.premiumSyncUri,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      final success = response.statusCode >= 200 && response.statusCode < 300;
      if (kDebugMode) {
        debugPrint('✅ Backend premium sync status: ${response.statusCode}');
      }
      return success;
    } catch (e) {
      if (kDebugMode) debugPrint('Error syncing premium status: $e');
      return false;
    }
  }

  static Future<bool> _handleAuthChange(User? user) async {
    if (!_isConfigured) return false;

    try {
      if (user == null) {
        await Purchases.logOut();
        return false;
      }

      await Purchases.logIn(user.uid);
      if (user.email != null && user.email!.isNotEmpty) {
        await Purchases.setEmail(user.email!);
      }
      return syncPremiumStatus(user);
    } catch (e) {
      if (kDebugMode) debugPrint('RevenueCat auth sync error: $e');
      return false;
    }
  }

  /// Call this when user logs in
  static Future<void> loginUser(String userId) async {
    try {
      if (!_isConfigured) {
        await initialize();
      }
      await Purchases.logIn(userId);
      await syncPremiumStatus();
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

  static Future<bool> syncCurrentUser() async {
    return _handleAuthChange(FirebaseAuth.instance.currentUser);
  }

  static Future<Uri?> subscriptionManagementUri() async {
    if (kIsWeb) return null;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final managementUrl = customerInfo.managementURL;
      if (managementUrl != null && managementUrl.trim().isNotEmpty) {
        return Uri.tryParse(managementUrl.trim());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading subscription management URL: $e');
      }
    }

    if (Platform.isIOS) {
      return Uri.parse('https://apps.apple.com/account/subscriptions');
    }
    if (Platform.isAndroid) {
      return Uri.parse(
        'https://play.google.com/store/account/subscriptions'
        '?package=${AppLinks.androidPackageName}',
      );
    }
    return null;
  }

  static Future<bool> openSubscriptionManagement() async {
    final uri = await subscriptionManagementUri();
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
