import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:split_bill_app/services/guest_session.dart';
import 'package:split_bill_app/services/home_widget_data.dart';

export 'package:split_bill_app/services/home_widget_data.dart'
    show WidgetRoute, WidgetRouteKind;

/// Keeps the home-screen widgets in sync with the signed-in member's bills.
///
/// - Listens to the same Firestore query as [HomeScreen] (bills where the
///   member is in `participants_uids`), so any bill change re-renders the
///   widgets while the app is alive.
/// - Pushes again on app start, on resume, and when the app language or the
///   display currency changes.
/// - Signed out (or anonymous guest): widgets show "Sign in to see balances".
///
/// Data goes through home_widget as one JSON payload (see
/// [buildWidgetPayload]); natives only render it.
class HomeWidgetService with WidgetsBindingObserver {
  HomeWidgetService._();

  static final HomeWidgetService instance = HomeWidgetService._();

  /// App Group shared by Runner and the SplitBillHomeWidget extension.
  static const String appGroupId = 'group.com.example.splitBillApp.widgets';

  /// WidgetKit `kind`s declared in ios/SplitBillHomeWidget.
  static const List<String> iOSKinds = [
    'SplitBillBalanceWidget',
    'SplitBillScanWidget',
    'SplitBillSettleWidget',
    'SplitBillBalanceAccessory',
  ];

  /// AppWidgetProviders in android/app/src/main/kotlin/.../widgets.
  static const List<String> androidProviders = [
    'net.omarmali.splitapp.widgets.BalanceWidgetProvider',
    'net.omarmali.splitapp.widgets.ScanWidgetProvider',
    'net.omarmali.splitapp.widgets.SettleWidgetProvider',
  ];

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool _started = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _billsSub;
  String? _uid;
  Map<String, Map<String, dynamic>>? _bills;
  Locale? _locale;
  String _currency = 'USD';
  String? _lastPayload;
  Timer? _debounce;

  /// Starts listening to auth and bills. Safe to call more than once.
  Future<void> start({required Locale locale, required String currency}) async {
    if (!_supported || _started) return;
    _started = true;
    _locale = locale;
    _currency = currency;
    WidgetsBinding.instance.addObserver(this);
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('HomeWidget: setAppGroupId failed: $e');
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (user) => _bindUser(memberOrNull(user)),
    );
  }

  /// Called from the app's build when the language or currency may have
  /// changed; re-renders only if something actually changed.
  void updatePresentation({required Locale locale, required String currency}) {
    if (_locale == locale && _currency == currency) return;
    _locale = locale;
    _currency = currency;
    _schedulePush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh "Updated hh:mm" and pick up changes made while suspended.
      _lastPayload = null;
      _schedulePush();
    }
  }

  void _bindUser(User? user) {
    if (user?.uid == _uid && (user == null || _billsSub != null)) {
      _schedulePush();
      return;
    }
    _billsSub?.cancel();
    _billsSub = null;
    _uid = user?.uid;
    _bills = null;

    if (user == null) {
      _schedulePush();
      return;
    }
    _billsSub = FirebaseFirestore.instance
        .collection('bills')
        .where('participants_uids', arrayContains: user.uid)
        .snapshots()
        .listen(
          (snapshot) {
            _bills = {for (final doc in snapshot.docs) doc.id: doc.data()};
            _schedulePush();
          },
          onError: (Object e) =>
              debugPrint('HomeWidget: bills stream error: $e'),
        );
  }

  void _schedulePush() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _push);
  }

  WidgetStrings _strings(String locale) {
    String time;
    try {
      time = DateFormat.Hm(locale).format(DateTime.now());
    } catch (_) {
      // Date symbols for this locale not loaded yet.
      time = DateFormat.Hm('en').format(DateTime.now());
    }
    return WidgetStrings(
      youAreOwed: 'widget_you_are_owed'.tr(),
      youOwe: 'widget_you_owe'.tr(),
      allSettled: 'widget_all_settled'.tr(),
      updatedAt: 'widget_updated_at'.tr(namedArgs: {'time': time}),
      scanReceipt: 'widget_scan_receipt'.tr(),
      settleWith: 'widget_settle_with'.tr(),
      noOpenBalances: 'widget_no_open_balances'.tr(),
      signInPrompt: 'widget_sign_in_prompt'.tr(),
      hideAmounts: 'widget_hide_amounts'.tr(),
      showAmounts: 'widget_show_amounts'.tr(),
    );
  }

  Future<void> _push() async {
    final uid = _uid;
    // Signed in but the first snapshot has not arrived: keep what the widget
    // shows rather than flashing an empty balance.
    if (uid != null && _bills == null) return;

    final locale = (_locale ?? const Locale('en')).toLanguageTag();
    String payload;
    try {
      payload = buildWidgetPayload(
        balances: uid == null
            ? null
            : computeWidgetBalances(
                bills: _bills!,
                uid: uid,
                currency: _currency,
              ),
        strings: _strings(locale),
        locale: locale,
      );
    } catch (e) {
      debugPrint('HomeWidget: could not build payload: $e');
      return;
    }
    if (payload == _lastPayload) return;
    _lastPayload = payload;

    try {
      await HomeWidget.saveWidgetData<String>(widgetPayloadKey, payload);
      for (final kind in iOSKinds) {
        if (defaultTargetPlatform != TargetPlatform.iOS) break;
        await HomeWidget.updateWidget(iOSName: kind);
      }
      for (final provider in androidProviders) {
        if (defaultTargetPlatform != TargetPlatform.android) break;
        await HomeWidget.updateWidget(qualifiedAndroidName: provider);
      }
    } catch (e) {
      // Widgets are a nice-to-have; never break the app over them.
      debugPrint('HomeWidget: update failed: $e');
      _lastPayload = null;
    }
  }

  /// Stops listening and forgets the cached payload.
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    await _authSub?.cancel();
    await _billsSub?.cancel();
    _authSub = null;
    _billsSub = null;
    _uid = null;
    _bills = null;
    _lastPayload = null;
  }

  /// The URI the app was cold-launched with from a widget, if any.
  Future<Uri?> initialLaunchUri() async {
    if (!_supported) return null;
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('HomeWidget: initial launch check failed: $e');
      return null;
    }
  }

  /// Widget taps while the app is running.
  Stream<Uri?> get widgetClicks =>
      _supported ? HomeWidget.widgetClicked : const Stream.empty();
}
