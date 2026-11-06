import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/screens/account/notification_permission_screen.dart';
import 'package:split_bill_app/screens/account/tracking_permission_screen.dart';
import 'package:split_bill_app/services/permission_flow.dart';

import 'account_harness.dart';

class _Fake {
  int notifRequests = 0;
  int trackingRequests = 0;
  DateTime? deferredAt;
  int finished = 0;

  PermissionChecks checks({
    bool ios = true,
    bool askNotifications = true,
    bool trackingUndetermined = true,
  }) => PermissionChecks(
    isIOS: ios,
    shouldAskNotifications: () async => askNotifications,
    requestNotifications: () async {
      notifRequests++;
      return true;
    },
    trackingUndetermined: () async => trackingUndetermined,
    requestTracking: () async => trackingRequests++,
    readDeferredAt: () async => deferredAt,
    writeDeferredAt: (at) async => deferredAt = at,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    PermissionGate.debugReset();
  });

  group('permissionStepsToShow', () {
    final now = DateTime(2026, 11, 5);

    test('iOS fresh install asks notifications then tracking', () {
      expect(
        permissionStepsToShow(
          notificationsAskable: true,
          now: now,
          isIOS: true,
          trackingUndetermined: true,
        ),
        [PermissionStep.notifications, PermissionStep.tracking],
      );
    });

    test('Android never shows the ATT explainer', () {
      expect(
        permissionStepsToShow(
          notificationsAskable: true,
          now: now,
          isIOS: false,
          trackingUndetermined: true,
        ),
        [PermissionStep.notifications],
      );
    });

    test('"Maybe later" hides notifications for 14 days only', () {
      List<PermissionStep> at(int daysAgo) => permissionStepsToShow(
        notificationsAskable: true,
        notificationsDeferredAt: now.subtract(Duration(days: daysAgo)),
        now: now,
        isIOS: false,
        trackingUndetermined: false,
      );
      expect(at(3), isEmpty);
      expect(at(13), isEmpty);
      expect(at(14), [PermissionStep.notifications]);
    });

    test('answered prompts show nothing', () {
      expect(
        permissionStepsToShow(
          notificationsAskable: false,
          now: now,
          isIOS: true,
          trackingUndetermined: false,
        ),
        isEmpty,
      );
    });

    test('failing checks skip their step', () async {
      final checks = PermissionChecks(
        isIOS: true,
        shouldAskNotifications: () async => throw StateError('no fcm'),
        requestNotifications: () async => false,
        trackingUndetermined: () async => true,
        requestTracking: () async {},
        readDeferredAt: () async => null,
        writeDeferredAt: (_) async {},
      );
      expect(await checks.resolveSteps(now), [PermissionStep.tracking]);
    });
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('gate walks notifications, ATT, then home ($mode)', (
      tester,
    ) async {
      final fake = _Fake();
      await pumpAccount(
        tester,
        PermissionGate(
          checks: fake.checks(),
          onFinished: () => fake.finished++,
          child: const Text('HOME'),
        ),
        themeMode: mode,
      );
      expect(find.byType(NotificationPermissionScreen), findsOneWidget);
      expect(find.text('Know when you get paid'), findsOneWidget);
      expect(find.text('Maybe later'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('notif-allow')));
      await tester.pumpAndSettle();
      expect(fake.notifRequests, 1);
      expect(find.byType(TrackingPermissionScreen), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('att-continue')));
      await tester.pumpAndSettle();
      expect(fake.trackingRequests, 1);
      expect(find.text('HOME'), findsOneWidget);
      expect(fake.finished, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('"Maybe later" records deferral without the OS prompt', (
    tester,
  ) async {
    final fake = _Fake();
    await pumpAccount(
      tester,
      PermissionGate(
        checks: fake.checks(ios: false),
        onFinished: () => fake.finished++,
        child: const Text('HOME'),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('notif-later')));
    await tester.pumpAndSettle();
    expect(fake.notifRequests, 0);
    expect(fake.deferredAt, isNotNull);
    expect(find.text('HOME'), findsOneWidget);
    expect(fake.finished, 1);
  });

  testWidgets('nothing to ask goes straight home, once per run', (
    tester,
  ) async {
    final fake = _Fake();
    await pumpAccount(
      tester,
      PermissionGate(
        checks: fake.checks(
          askNotifications: false,
          trackingUndetermined: false,
        ),
        onFinished: () => fake.finished++,
        child: const Text('HOME'),
      ),
    );
    expect(find.text('HOME'), findsOneWidget);
    expect(fake.finished, 1);

    // A rebuilt gate (auth_wrapper rebuild) never re-asks.
    await pumpAccount(
      tester,
      PermissionGate(
        key: UniqueKey(),
        checks: fake.checks(),
        onFinished: () => fake.finished++,
        child: const Text('HOME'),
      ),
    );
    expect(find.byType(NotificationPermissionScreen), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
  });

  test('startup never warms up ads before the permission gate', () {
    // The warm-up runs from PermissionGate.onFinished (after the ATT answer).
    final main = File('lib/main.dart').readAsStringSync();
    expect(main.contains('warmUpIfEligible'), isFalse);
  });
}
