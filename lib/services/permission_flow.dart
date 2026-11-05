/// Decides which permission explainers to show after account setup, and the
/// [PermissionGate] widget that shows them before Home.
///
/// Order: notifications explainer (when the OS prompt was never answered and
/// the user didn't pick "Maybe later" in the last 14 days), then the App
/// Tracking Transparency explainer (iOS only, when ATT is undetermined).
/// Each explainer leads to the real system prompt; nothing is requested at
/// app launch.
library;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/helpers/rewarded_ad_helper.dart';
import 'package:split_bill_app/screens/account/notification_permission_screen.dart';
import 'package:split_bill_app/screens/account/tracking_permission_screen.dart';
import 'package:split_bill_app/services/notification_service.dart';
import 'package:split_bill_app/theme/theme.dart';

enum PermissionStep { notifications, tracking }

/// shared_preferences key: when the user tapped "Maybe later" (ms epoch).
const String notificationPromptDeferredKey = 'notif_prompt_deferred_at';

/// How long "Maybe later" keeps the notifications explainer away.
const Duration notificationPromptDeferral = Duration(days: 14);

/// Pure decision: the explainers to show, in order.
List<PermissionStep> permissionStepsToShow({
  required bool notificationsAskable,
  required DateTime now,
  DateTime? notificationsDeferredAt,
  required bool isIOS,
  required bool trackingUndetermined,
  Duration deferral = notificationPromptDeferral,
}) {
  final deferred =
      notificationsDeferredAt != null &&
      now.difference(notificationsDeferredAt) < deferral;
  return [
    if (notificationsAskable && !deferred) PermissionStep.notifications,
    if (isIOS && trackingUndetermined) PermissionStep.tracking,
  ];
}

/// Device permission calls, injectable for tests.
class PermissionChecks {
  const PermissionChecks({
    required this.isIOS,
    required this.shouldAskNotifications,
    required this.requestNotifications,
    required this.trackingUndetermined,
    required this.requestTracking,
    required this.readDeferredAt,
    required this.writeDeferredAt,
  });

  /// Real platform implementations.
  factory PermissionChecks.device() {
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return PermissionChecks(
      isIOS: ios,
      shouldAskNotifications: () => NotificationService().shouldAskPermission(),
      requestNotifications: () => NotificationService().requestPermission(),
      trackingUndetermined: () async =>
          ios &&
          await AppTrackingTransparency.trackingAuthorizationStatus ==
              TrackingStatus.notDetermined,
      requestTracking: () async {
        // The system dialog needs the app to be active; a short pause after
        // the explainer's tap avoids it being dropped.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await AppTrackingTransparency.requestTrackingAuthorization();
      },
      readDeferredAt: () async {
        final prefs = await SharedPreferences.getInstance();
        final ms = prefs.getInt(notificationPromptDeferredKey);
        return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
      },
      writeDeferredAt: (at) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          notificationPromptDeferredKey,
          at.millisecondsSinceEpoch,
        );
      },
    );
  }

  final bool isIOS;
  final Future<bool> Function() shouldAskNotifications;
  final Future<bool> Function() requestNotifications;
  final Future<bool> Function() trackingUndetermined;
  final Future<void> Function() requestTracking;
  final Future<DateTime?> Function() readDeferredAt;
  final Future<void> Function(DateTime at) writeDeferredAt;

  /// Resolves the steps; any failing check just skips its step.
  Future<List<PermissionStep>> resolveSteps(DateTime now) async {
    Future<T> safe<T>(Future<T> Function() f, T fallback) async {
      try {
        return await f();
      } catch (e) {
        debugPrint('Permission check failed: $e');
        return fallback;
      }
    }

    return permissionStepsToShow(
      notificationsAskable: await safe(shouldAskNotifications, false),
      notificationsDeferredAt: await safe<DateTime?>(readDeferredAt, null),
      now: now,
      isIOS: isIOS,
      trackingUndetermined: await safe(trackingUndetermined, false),
    );
  }
}

/// Shows the pending permission explainers once, then [child].
///
/// Wraps Home in auth_wrapper and after phone setup. [onFinished] runs once
/// all steps are done (defaults to warming up the rewarded ad, so ad
/// requests happen after the ATT answer).
class PermissionGate extends StatefulWidget {
  const PermissionGate({
    super.key,
    required this.child,
    this.checks,
    this.onFinished,
  });

  final Widget child;
  final PermissionChecks? checks;
  final VoidCallback? onFinished;

  /// Set once per app run so rebuilds never re-open an explainer.
  static bool _doneThisRun = false;

  @visibleForTesting
  static void debugReset() => _doneThisRun = false;

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  late final PermissionChecks _checks =
      widget.checks ?? PermissionChecks.device();
  List<PermissionStep>? _steps;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (PermissionGate._doneThisRun) {
      _steps = const [];
    } else {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final steps = await _checks.resolveSteps(DateTime.now());
    if (!mounted) return;
    setState(() => _steps = steps);
    if (steps.isEmpty) _finish();
  }

  void _finish() {
    if (PermissionGate._doneThisRun) return;
    PermissionGate._doneThisRun = true;
    (widget.onFinished ?? RewardedAdHelper.warmUpIfEligible)();
  }

  void _advance() {
    if (!mounted) return;
    setState(() => _index++);
    if (_index >= (_steps?.length ?? 0)) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final Widget current;
    if (steps == null) {
      current = Scaffold(
        key: const ValueKey('permission-gate-loading'),
        backgroundColor: context.palette.canvas,
      );
    } else if (_index >= steps.length) {
      current = KeyedSubtree(
        key: const ValueKey('permission-gate-child'),
        child: widget.child,
      );
    } else {
      current = switch (steps[_index]) {
        PermissionStep.notifications => NotificationPermissionScreen(
          key: const ValueKey('permission-gate-notifications'),
          onRequest: _checks.requestNotifications,
          onDefer: () => _checks.writeDeferredAt(DateTime.now()),
          onDone: _advance,
        ),
        PermissionStep.tracking => TrackingPermissionScreen(
          key: const ValueKey('permission-gate-tracking'),
          onRequest: _checks.requestTracking,
          onDone: _advance,
        ),
      };
    }
    return AnimatedSwitcher(
      duration: AppMotion.durationFor(context, AppMotion.slow),
      child: current,
    );
  }
}
