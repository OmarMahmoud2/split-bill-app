// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart';
import 'guest_bill_screen.dart';
import 'bill_details_screen.dart';
import 'participant_bill_screen.dart';
import 'notifications_screen.dart';
import 'services/notification_payload.dart';
import 'services/guest_session.dart';
import 'services/web_translations_loader.dart';
import 'services/notification_service.dart';
import 'services/home_widget_service.dart';
import 'services/home_widget_data.dart' show WidgetLaunchDeduper;
import 'scan_receipt_screen.dart';
import 'utils/app_theme.dart';
import 'theme/app_typography.dart';
import 'theme/font_licenses.dart';
import 'auth_wrapper.dart';
import 'services/bill_link_routing.dart';
import 'screens/bill_link_error_screen.dart';
import 'widgets/bill_details/bill_view_logic.dart' show billErrorKey;
import 'package:split_bill_app/widgets/brand/brand_intro.dart';
import 'package:split_bill_app/widgets/custom_upgrader.dart';
import 'services/revenue_cat_service.dart'; // Premium purchases
import 'helpers/rewarded_ad_helper.dart';
import 'config/supported_preferences.dart';
import 'providers/app_settings_provider.dart';
import 'web_download_screen.dart';
import 'screens/debug/foundation_gallery_screen.dart';
import 'screens/guest_bill/guest_bill_model.dart' show parseGuestLink;
import 'screens/guest_bill/guest_locale.dart';

// Global Navigator Key for Deep Linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  registerFontLicenses();
  debugPrint("🚀 App Launch: Widgets Initialized");

  Object? firebaseInitializationError;

  try {
    final firebaseOptions = DefaultFirebaseOptions.currentPlatformOrNull;

    if (firebaseOptions != null) {
      await Firebase.initializeApp(options: firebaseOptions);
    } else if (kIsWeb) {
      throw StateError(
        'Firebase web options are missing. Build with FIREBASE_WEB_* dart-defines.',
      );
    } else {
      await Firebase.initializeApp();
    }
    debugPrint("✅ App Launch: Firebase Initialized");
  } catch (e) {
    debugPrint("❌ App Launch: Firebase Error: $e");
    firebaseInitializationError = e;
  }

  // Initialize notifications without awaiting (non-blocking).
  if (!kIsWeb) {
    unawaited(NotificationService().init());
    debugPrint("✅ App Launch: Notifications Init Triggered");
  }

  // Initialize Google Mobile Ads SDK early so rewarded ads can preload
  if (!kIsWeb) {
    unawaited(
      MobileAds.instance.initialize().then((_) {
        debugPrint('✅ App Launch: Google Mobile Ads Initialized');
        // Preload a rewarded ad for free users as soon as SDK is ready
        RewardedAdHelper.warmUpIfEligible();
      }),
    );
  }

  if (!kIsWeb) {
    debugPrint("⏳ App Launch: Initializing RevenueCat...");
    unawaited(RevenueCatService.initialize());

    // Initial style until the first frame; afterwards the AnnotatedRegion in
    // MyApp (and AppBarTheme.systemOverlayStyle) follow the active theme.
    SystemChrome.setSystemUIOverlayStyle(
      AppTheme.overlayStyleFor(PlatformDispatcher.instance.platformBrightness),
    );
  }

  // Guest pages are used with screen readers and keyboards: build the web
  // accessibility tree up front instead of behind Flutter's opt-in button.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();

  debugPrint("🚀 App Launch: Calling runApp()");
  runApp(
    EasyLocalization(
      supportedLocales: supportedLocaleOptions
          .map((option) => option.locale)
          .toList(),
      path: 'assets/translations',
      assetLoader: const VersionedTranslationsLoader(),
      fallbackLocale: const Locale('en'),
      useOnlyLangCode: true,
      child: firebaseInitializationError == null
          ? MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) => AppSettingsProvider()..initialize(),
                ),
              ],
              child: const MyApp(),
            )
          : FirebaseStartupErrorApp(error: firebaseInitializationError),
    ),
  );
}

class FirebaseStartupErrorApp extends StatelessWidget {
  const FirebaseStartupErrorApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Evens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'We could not start Evens',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      kIsWeb
                          ? 'Please refresh the page. If this keeps happening, contact support.'
                          : 'Check your connection, then close and reopen the app. If this keeps happening, contact support.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 16),
                      SelectableText(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<Uri?>? _widgetClickSubscription;
  final WidgetLaunchDeduper _widgetLaunchDeduper = WidgetLaunchDeduper();
  bool _isHandlingLink = false;

  @override
  void initState() {
    super.initState();
    // Web guest links are handled from Uri.base in build().
    if (!kIsWeb) {
      _initDeepLinks();
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  // --- DEEP LINK HANDLING ---
  Map<String, String?> _extractBillLinkData(Uri uri) {
    // `/bill/<id>`, `/b/<id>` or `?billId=`; personal links add `?p=`
    // (legacy `?uid=`).
    final link = parseGuestLink(uri);
    return {'billId': link?.billId, 'uid': link?.participantId};
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // 1. Listen for Links (Background/Warm Start)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // 2. HOME-SCREEN WIDGET TAPS (warm and cold start)
    _widgetClickSubscription = HomeWidgetService.instance.widgetClicks.listen((
      uri,
    ) {
      if (uri != null) _handleWidgetUri(uri);
    });
    unawaited(
      HomeWidgetService.instance.initialLaunchUri().then((uri) {
        if (uri != null) _handleWidgetUri(uri);
      }),
    );

    // 3. LISTEN TO FIREBASE NOTIFICATIONS (Important!)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    // Foreground pushes are shown by the app itself; route their taps too.
    NotificationService().localTaps.listen(_routeNotificationData);

    // 4. CHECK INITIAL NOTIFICATION (Terminated state)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleNotificationTap(RemoteMessage message) =>
      _routeNotificationData(message.data);

  void _routeNotificationData(Map<String, dynamic> data) {
    switch (notificationTapTarget(data)) {
      case NotificationTapTarget.bill:
        _handleBillNavigation(data['billId'] as String, uid: data['uid']);
      case NotificationTapTarget.notifications:
        // e.g. server engagement reminders: show the notification history.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (FirebaseAuth.instance.currentUser == null) return;
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        });
      case NotificationTapTarget.none:
        break;
    }
  }

  // Unified Handler for both Deep Links and Notifications
  Future<void> _handleDeepLink(Uri uri) async {
    if (WidgetRoute.tryParse(uri) != null) {
      // splitbill://widget/... can also reach app_links; route it once.
      _handleWidgetUri(uri);
      return;
    }
    if (_isHandlingLink) return;
    final linkData = _extractBillLinkData(uri);
    final billId = linkData['billId'];
    final uid = linkData['uid'];

    if (billId != null) {
      _handleBillNavigation(billId, uid: uid);
    }
  }

  /// Routes a home-screen widget tap (see lib/services/home_widget_data.dart).
  void _handleWidgetUri(Uri uri) {
    final route = WidgetRoute.tryParse(uri);
    if (route == null || !_widgetLaunchDeduper.shouldHandle(uri)) return;

    switch (route.kind) {
      case WidgetRouteKind.friend when route.billId != null:
        // Settling happens on the bill today; open the largest open bill
        // with that person.
        _handleBillNavigation(route.billId!);
      case WidgetRouteKind.scan:
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          // On a cold start the persisted session may still be loading.
          final user = memberOrNull(
            FirebaseAuth.instance.currentUser ??
                await FirebaseAuth.instance.authStateChanges().first.timeout(
                  const Duration(seconds: 5),
                  onTimeout: () => null,
                ),
          );
          if (user == null) return; // AuthWrapper shows sign-in.
          final navigator = navigatorKey.currentState;
          if (navigator == null) return;
          navigator.popUntil((route) => route.isFirst);
          navigator.push(
            MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
          );
        });
      case WidgetRouteKind.home:
      case WidgetRouteKind.friend:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
    }
  }

  Future<void> _handleBillNavigation(String billId, {String? uid}) async {
    if (_isHandlingLink) return;
    _isHandlingLink = true;

    // Small delay to prevent double-handling
    Future.delayed(const Duration(seconds: 1), () => _isHandlingLink = false);

    // Wait for frame to ensure navigator keys are ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = memberOrNull(FirebaseAuth.instance.currentUser);

      // SCENARIO A: Guest / Not Logged In
      if (user == null) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                GuestBillScreen(billId: billId, initialParticipantId: uid),
          ),
        );
        return;
      }

      // SCENARIO B: Logged In (Check Permissions/Details)
      try {
        final doc = await FirebaseFirestore.instance
            .collection('bills')
            .doc(billId)
            .get();

        final data = doc.data();
        final target = resolveBillLinkTarget(
          data: doc.exists ? data : null,
          uid: user.uid,
          personalId: uid,
        );
        final billName =
            (data?['storeName'] as String?) ?? 'bill'.tr();
        switch (target) {
          case BillLinkTarget.host:
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) =>
                    BillDetailsScreen(billId: billId, billName: billName),
              ),
            );
          case BillLinkTarget.participant:
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) =>
                    ParticipantBillScreen(billId: billId, billName: billName),
              ),
            );
          case BillLinkTarget.guestEntry:
            _openGuestEntry(billId, uid);
          case BillLinkTarget.notFound:
            debugPrint('Bill not found: $billId');
            navigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const BillLinkErrorScreen()),
            );
        }
      } catch (e) {
        debugPrint('Error navigating to bill: $e');
        // A personal link for someone else's entry may not be readable with
        // this account: the guest page still works.
        if (uid != null && uid != user.uid) {
          _openGuestEntry(billId, uid);
          return;
        }
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => BillLinkErrorScreen(
              notFound: false,
              message: billErrorKey(e).tr(),
            ),
          ),
        );
      }
    });
  }

  void _openGuestEntry(String billId, String? participantId) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) =>
            GuestBillScreen(billId: billId, initialParticipantId: participantId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const String forcedLocale = String.fromEnvironment(
      'LOCALE',
      defaultValue: '',
    );
    final initialWebLink = kIsWeb ? _extractBillLinkData(Uri.base) : null;
    final billIdFromUrl = initialWebLink?['billId'];
    final uidFromUrl = initialWebLink?['uid'];

    return Consumer<AppSettingsProvider>(
      builder: (context, appSettings, child) {
        if (forcedLocale.isNotEmpty &&
            context.locale.languageCode != forcedLocale.split('-')[0]) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.setLocale(Locale(forcedLocale.split('-')[0]));
            }
          });
        } else if (forcedLocale.isEmpty &&
            // A guest's own pick on the web page wins over the browser default.
            !GuestLocale.chosen &&
            context.locale.languageCode != appSettings.locale.languageCode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.setLocale(appSettings.locale);
            }
          });
        }

        if (!kIsWeb) {
          final widgetLocale = context.locale;
          final widgetCurrency = appSettings.currencyCode;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            HomeWidgetService.instance
              ..start(locale: widgetLocale, currency: widgetCurrency)
              ..updatePresentation(
                locale: widgetLocale,
                currency: widgetCurrency,
              );
          });
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Evens',
          onGenerateTitle: (context) => 'app_title'.tr(),
          debugShowCheckedModeBanner: false,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: appSettings.themeMode,
          // Debug-only QA gallery of the v3 foundation (never in release).
          routes: {
            if (kDebugMode)
              FoundationGalleryScreen.routeName: (_) =>
                  const FoundationGalleryScreen(),
          },
          // Status bar icons follow the active theme on screens without an
          // AppBar (AppBarTheme.systemOverlayStyle covers the rest).
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.overlayStyleFor(Theme.of(context).brightness),
            child: AppLocaleTypography(child: child ?? const SizedBox.shrink()),
          ),

          // Web has no store update prompt, so the upgrader (and its
          // packages) stays out of the web bundle.
          home: kIsWeb
              ? (billIdFromUrl != null
                    ? GuestBillScreen(
                        billId: billIdFromUrl,
                        initialParticipantId: uidFromUrl,
                      )
                    : const WebDownloadScreen())
              : const BrandIntro(child: CustomUpgrader(child: AuthWrapper())),
        );
      },
    );
  }
}
