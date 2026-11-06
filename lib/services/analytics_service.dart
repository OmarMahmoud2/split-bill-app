import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Where analytics events go. The real one wraps Firebase Analytics; tests
/// inject a fake that records calls.
abstract class AnalyticsSink {
  Future<void> logEvent(String name, Map<String, Object> parameters);
  Future<void> setUserProperty(String name, String? value);
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> setConsentDenyingAds();
}

class FirebaseAnalyticsSink implements AnalyticsSink {
  FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) =>
      _fa.logEvent(name: name, parameters: parameters);

  @override
  Future<void> setUserProperty(String name, String? value) =>
      _fa.setUserProperty(name: name, value: value);

  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      _fa.setAnalyticsCollectionEnabled(enabled);

  @override
  Future<void> setConsentDenyingAds() => _fa.setConsent(
    adStorageConsentGranted: false,
    adUserDataConsentGranted: false,
    adPersonalizationSignalsConsentGranted: false,
    analyticsStorageConsentGranted: true,
  );
}

/// Thin, typed, PII-free wrapper over Firebase Analytics.
///
/// Rules: never call setUserId; never send names, emails, phones, bill
/// titles, exact amounts, uids, guest ids or free text. Numbers are bucketed.
/// Every method is fire-and-forget and swallows errors.
class AnalyticsService {
  AnalyticsService._(this._sink, {bool enabled = false}) : _enabled = enabled;

  /// A service with an injected sink, already enabled (tests).
  @visibleForTesting
  AnalyticsService.withSink(AnalyticsSink sink) : this._(sink, enabled: true);

  static AnalyticsService instance = AnalyticsService._(
    FirebaseAnalyticsSink(),
  );

  /// Parameter keys that must never be sent. Enforced at runtime (such a key
  /// is dropped) and checked by tests.
  static const Set<String> forbiddenKeys = {
    'name',
    'display_name',
    'email',
    'phone',
    'phone_number',
    'uid',
    'user_id',
    'guest_id',
    'bill_id',
    'group_id',
    'title',
    'store_name',
    'note',
    'text',
    'amount',
    'total',
    'price',
    'address',
  };

  final AnalyticsSink _sink;
  bool _enabled;
  bool get enabled => _enabled;
  final Map<String, String> _lastUserProps = {};

  /// Call once after Firebase.initializeApp. Enabled in release builds only,
  /// and on web only when a GA measurement id is configured.
  Future<void> init() async {
    if (kDebugMode) {
      _enabled = false;
    } else if (kIsWeb) {
      String? measurementId;
      try {
        measurementId = Firebase.app().options.measurementId;
      } catch (_) {}
      _enabled = measurementId != null && measurementId.isNotEmpty;
    } else {
      _enabled = true;
    }
    try {
      await _sink.setCollectionEnabled(_enabled);
      if (_enabled) await _sink.setConsentDenyingAds();
    } catch (e) {
      _enabled = false;
      if (kDebugMode) debugPrint('analytics init: $e');
    }
  }

  // ---- bucketing -------------------------------------------------------

  static String itemsBucket(int n) =>
      n <= 5 ? '1-5' : (n <= 10 ? '6-10' : '11+');
  static String peopleBucket(int n) => n <= 2 ? '2' : (n <= 4 ? '3-4' : '5+');
  static String paymentsBucket(int n) =>
      n <= 1 ? '1' : (n <= 3 ? '2-3' : (n <= 6 ? '4-6' : '7+'));

  // ---- core ------------------------------------------------------------

  void _log(String name, [Map<String, Object?> params = const {}]) {
    if (!_enabled) return;
    final clean = <String, Object>{};
    params.forEach((k, v) {
      if (v == null || forbiddenKeys.contains(k)) return;
      clean[k] = v is bool ? (v ? 'true' : 'false') : v;
    });
    unawaited(
      _sink.logEvent(name, clean).catchError((Object e) {
        if (kDebugMode) debugPrint('analytics $name: $e');
      }),
    );
  }

  void _prop(String name, String value) {
    if (!_enabled || _lastUserProps[name] == value) return;
    _lastUserProps[name] = value;
    unawaited(
      _sink.setUserProperty(name, value).catchError((Object e) {
        if (kDebugMode) debugPrint('analytics prop $name: $e');
      }),
    );
  }

  // ---- user properties -------------------------------------------------

  void setAppLocale(String languageCode) => _prop('app_locale', languageCode);
  void setThemeMode(String mode) => _prop('theme_mode', mode);
  void setIsPro(bool isPro) => _prop('is_pro', isPro ? 'true' : 'false');

  // ---- screens (main tabs only) ---------------------------------------

  void screen(String tab) => _log('screen_view', {'screen_name': tab});

  // ---- lifecycle -------------------------------------------------------

  void onboardingComplete() => _log('onboarding_complete');

  /// [method]: google | apple | anonymous_guest | email.
  void signUp(String method) => _log('sign_up', {'method': method});
  void login(String method) => _log('login', {'method': method});

  // ---- scanning / voice -----------------------------------------------

  /// [result]: success | fail | no_points.
  void receiptScan(String result) => _log('receipt_scan', {'result': result});
  void voiceAssign({required bool success}) =>
      _log('voice_assign', {'result': success ? 'success' : 'fail'});

  // ---- bills -----------------------------------------------------------

  /// [source]: scan | manual.
  void billCreated({
    required String source,
    required int items,
    required int people,
    required String splitMethod,
  }) => _log('bill_created', {
    'source': source,
    'items_bucket': itemsBucket(items),
    'people_bucket': peopleBucket(people),
    'split_method': splitMethod,
  });

  /// [channel]: link | system_share.
  void billShared(String channel) => _log('bill_shared', {'channel': channel});
  void guestLinkOpened() => _log('guest_link_opened');
  void guestPaymentSubmitted({required bool withProof}) =>
      _log('guest_payment_submitted', {'with_proof': withProof});

  /// [by]: host | member.
  void paymentMarkedPaid(String by) => _log('payment_marked_paid', {'by': by});
  void proofRejected() => _log('proof_rejected');
  void settleUpDone(int payments) =>
      _log('settle_up_done', {'payments_bucket': paymentsBucket(payments)});
  void groupCreated() => _log('group_created');
  void recurringCreated() => _log('recurring_created');

  /// [format]: pdf | csv.
  void export(String format) => _log('export', {'format': format});

  // ---- monetisation ----------------------------------------------------

  void paywallView(String placement) =>
      _log('paywall_view', {'placement': placement});

  /// [plan]: monthly | yearly | lifetime.
  void purchaseStarted(String plan) => _log('purchase_started', {'plan': plan});
  void purchaseSuccess(String plan, {required bool isTrial}) =>
      _log('purchase_success', {'plan': plan, 'is_trial': isTrial});
  void purchaseRestored() => _log('purchase_restored');
  void rewardedAdCompleted() => _log('rewarded_ad_completed');

  // ---- re-entry --------------------------------------------------------

  /// [type] is the notification/reminder type tag, never content.
  void notificationOpened(String type) =>
      _log('notification_opened', {'type': type});
  void reminderOpened(String type) => _log('reminder_opened', {'type': type});
  void widgetOpened() => _log('widget_opened');
}
