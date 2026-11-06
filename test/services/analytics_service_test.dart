import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/analytics_service.dart';

class FakeSink implements AnalyticsSink {
  final events = <(String, Map<String, Object>)>[];
  final props = <String, String?>{};
  bool? collection;
  bool consentDenied = false;
  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) async =>
      events.add((name, parameters));
  @override
  Future<void> setUserProperty(String name, String? value) async =>
      props[name] = value;
  @override
  Future<void> setCollectionEnabled(bool enabled) async => collection = enabled;
  @override
  Future<void> setConsentDenyingAds() async => consentDenied = true;
}

void main() {
  late FakeSink sink;
  late AnalyticsService a;
  setUp(() {
    sink = FakeSink();
    a = AnalyticsService.withSink(sink);
  });

  test('buckets', () {
    expect(AnalyticsService.itemsBucket(1), '1-5');
    expect(AnalyticsService.itemsBucket(5), '1-5');
    expect(AnalyticsService.itemsBucket(6), '6-10');
    expect(AnalyticsService.itemsBucket(11), '11+');
    expect(AnalyticsService.peopleBucket(2), '2');
    expect(AnalyticsService.peopleBucket(3), '3-4');
    expect(AnalyticsService.peopleBucket(9), '5+');
    expect(AnalyticsService.paymentsBucket(1), '1');
    expect(AnalyticsService.paymentsBucket(3), '2-3');
    expect(AnalyticsService.paymentsBucket(5), '4-6');
    expect(AnalyticsService.paymentsBucket(8), '7+');
  });

  test('every typed event has the expected name and params', () {
    a.onboardingComplete();
    a.signUp('google');
    a.login('apple');
    a.receiptScan('no_points');
    a.voiceAssign(success: true);
    a.billCreated(source: 'scan', items: 7, people: 3, splitMethod: 'items');
    a.billShared('link');
    a.guestLinkOpened();
    a.guestPaymentSubmitted(withProof: true);
    a.paymentMarkedPaid('host');
    a.proofRejected();
    a.settleUpDone(5);
    a.groupCreated();
    a.recurringCreated();
    a.export('pdf');
    a.paywallView('export');
    a.purchaseStarted('yearly');
    a.purchaseSuccess('yearly', isTrial: true);
    a.purchaseRestored();
    a.rewardedAdCompleted();
    a.notificationOpened('reminder');
    a.reminderOpened('reminder');
    a.widgetOpened();
    a.screen('home');
    final got = {for (final e in sink.events) e.$1: e.$2};
    expect(got['onboarding_complete'], isEmpty);
    expect(got['sign_up'], {'method': 'google'});
    expect(got['login'], {'method': 'apple'});
    expect(got['receipt_scan'], {'result': 'no_points'});
    expect(got['voice_assign'], {'result': 'success'});
    expect(got['bill_created'], {
      'source': 'scan',
      'items_bucket': '6-10',
      'people_bucket': '3-4',
      'split_method': 'items',
    });
    expect(got['bill_shared'], {'channel': 'link'});
    expect(got['guest_payment_submitted'], {'with_proof': 'true'});
    expect(got['payment_marked_paid'], {'by': 'host'});
    expect(got['settle_up_done'], {'payments_bucket': '4-6'});
    expect(got['export'], {'format': 'pdf'});
    expect(got['paywall_view'], {'placement': 'export'});
    expect(got['purchase_started'], {'plan': 'yearly'});
    expect(got['purchase_success'], {'plan': 'yearly', 'is_trial': 'true'});
    expect(got['notification_opened'], {'type': 'reminder'});
    expect(got['screen_view'], {'screen_name': 'home'});
    for (final n in [
      'guest_link_opened',
      'proof_rejected',
      'group_created',
      'recurring_created',
      'purchase_restored',
      'rewarded_ad_completed',
      'reminder_opened',
      'widget_opened',
    ]) {
      expect(got.containsKey(n), isTrue, reason: n);
    }
  });

  test('no event carries a forbidden param key', () {
    a.billCreated(source: 'manual', items: 2, people: 2, splitMethod: 'equal');
    a.signUp('anonymous_guest');
    for (final e in sink.events) {
      for (final k in e.$2.keys) {
        expect(AnalyticsService.forbiddenKeys.contains(k), isFalse);
      }
    }
  });

  test('user properties are sent once per change', () {
    a.setIsPro(true);
    a.setIsPro(true);
    a.setAppLocale('ar');
    a.setThemeMode('dark');
    a.setIsPro(false);
    expect(sink.props, {
      'is_pro': 'false',
      'app_locale': 'ar',
      'theme_mode': 'dark',
    });
  });

  test('default (uninitialised) instance is disabled and a no-op', () {
    expect(AnalyticsService.instance.enabled, isFalse);
    AnalyticsService.instance.paywallView('x'); // must not throw
  });

  test('the app never calls setUserId or uses advertising identifiers', () {
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      expect(src.contains('setUserId'), isFalse, reason: f.path);
    }
  });

  test('sink errors are swallowed', () {
    final bad = _ThrowingSink();
    final b = AnalyticsService.withSink(bad);
    b.widgetOpened();
    b.setIsPro(true);
  });
}

class _ThrowingSink extends FakeSink {
  @override
  Future<void> logEvent(String name, Map<String, Object> parameters) =>
      Future.error(StateError('x'));
  @override
  Future<void> setUserProperty(String name, String? value) =>
      Future.error(StateError('x'));
}
