import 'package:split_bill_app/services/analytics_service.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:split_bill_app/config/api_keys.dart';
import 'package:split_bill_app/services/revenue_cat_service.dart';
import 'dart:io' show Platform;

/// Helper for loading and showing rewarded ads to earn points
class RewardedAdHelper {
  // Test Ad Unit IDs (use these for testing)
  // Test Ad Unit IDs (use these for testing)
  static const String _testAndroidAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testIosAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  // Production Ad Unit IDs from ApiKeys
  static const String _prodAndroidAdUnitId = ApiKeys.adMobAndroidRewarded;
  static const String _prodIosAdUnitId = ApiKeys.adMobIosRewarded;

  static RewardedAd? _rewardedAd;
  static bool _isAdReady = false;
  static bool _isLoading = false;
  static DateTime? _lastLoadAttempt;

  /// Get the appropriate Ad Unit ID based on platform and mode
  static String get _adUnitId {
    if (kIsWeb) return ''; // No ads on web
    if (kDebugMode) {
      // Use test IDs in debug mode
      return Platform.isAndroid ? _testAndroidAdUnitId : _testIosAdUnitId;
    } else {
      // Use production IDs in release mode
      return Platform.isAndroid ? _prodAndroidAdUnitId : _prodIosAdUnitId;
    }
  }

  /// Load a rewarded ad
  static Future<void> loadAd() async {
    if (kIsWeb) return; // Disable on web
    if (_isLoading || _isAdReady) return;
    if (_lastLoadAttempt != null &&
        DateTime.now().difference(_lastLoadAttempt!) <
            const Duration(seconds: 15)) {
      return;
    }

    _isLoading = true;
    _lastLoadAttempt = DateTime.now();

    await RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (kDebugMode) debugPrint('✅ Rewarded Ad loaded successfully');
          // Points are granted by the backend from AdMob's server-side
          // verification callback, keyed by this uid.
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            ad.setServerSideOptions(ServerSideVerificationOptions(userId: uid));
          }
          _rewardedAd = ad;
          _isAdReady = true;
          _isLoading = false;

          // Set callbacks
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              if (kDebugMode) debugPrint('Rewarded Ad dismissed');
              ad.dispose();
              _rewardedAd = null;
              _isAdReady = false;
              // Preload next ad
              loadAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              if (kDebugMode) debugPrint('Rewarded Ad failed to show: $error');
              ad.dispose();
              _rewardedAd = null;
              _isAdReady = false;
              loadAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) debugPrint('❌ Rewarded Ad failed to load: $error');
          _isAdReady = false;
          _isLoading = false;
        },
      ),
    );
  }

  static Future<void> warmUpIfEligible() async {
    if (kIsWeb) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isPremium =
          RevenueCatService.isUserActivePremium(userDoc.data());
      if (!isPremium) {
        await loadAd();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Rewarded ad warm-up skipped: $e');
    }
  }

  /// Show rewarded ad and award points
  /// Returns true if ad was shown successfully
  static Future<bool> showAdAndReward({
    required Function() onRewardEarned,
    required Function() onAdFailed,
  }) async {
    if (!_isAdReady || _rewardedAd == null) {
      if (kDebugMode) debugPrint('⚠️ Rewarded ad not ready yet, loading...');
      await warmUpIfEligible();
      onAdFailed();
      return false;
    }

    bool rewardEarned = false;
    final pointsBefore = await _currentPoints();

    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        if (kDebugMode) {
          debugPrint('🎉 User earned reward: ${reward.amount} ${reward.type}');
        }
        rewardEarned = true;
        AnalyticsService.instance.rewardedAdCompleted();

        // The backend adds the point; wait briefly so the UI shows it.
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _waitForServerPoint(user.uid, pointsBefore);
          onRewardEarned();
        }
      },
    );

    _isAdReady = false;
    _rewardedAd = null;

    return rewardEarned;
  }

  static Future<int> _currentPoints() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return (doc.data()?['points'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _waitForServerPoint(String uid, int before) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      await userRef
          .snapshots()
          .map((doc) => (doc.data()?['points'] as num?)?.toInt() ?? 0)
          .firstWhere((points) => points > before)
          .timeout(const Duration(seconds: 10));
      if (kDebugMode) debugPrint('✅ Server granted rewarded point to $uid');
    } catch (e) {
      // AdMob callbacks can lag; the point still lands on the server.
      if (kDebugMode) debugPrint('Rewarded point not visible yet: $e');
    }
  }

  /// Check if ad is ready to show
  static bool get isReady => _isAdReady;

  /// Dispose of current ad
  static void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdReady = false;
  }
}
