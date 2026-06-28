// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
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
import 'services/notification_service.dart';
import 'utils/app_theme.dart';
import 'auth_wrapper.dart';
import 'package:split_bill_app/widgets/custom_upgrader.dart';
import 'services/revenue_cat_service.dart'; // Premium purchases
import 'helpers/rewarded_ad_helper.dart';
import 'config/supported_preferences.dart';
import 'providers/app_settings_provider.dart';

// Global Navigator Key for Deep Linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
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

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  debugPrint("🚀 App Launch: Calling runApp()");
  runApp(
    EasyLocalization(
      supportedLocales: supportedLocaleOptions
          .map((option) => option.locale)
          .toList(),
      path: 'assets/translations',
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
      title: 'Split Bill',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
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
                      'We could not start Split Bill',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please refresh the page. If this keeps happening, contact support.',
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
    super.dispose();
  }

  // --- DEEP LINK HANDLING ---
  Map<String, String?> _extractBillLinkData(Uri uri) {
    String? billId = uri.queryParameters['billId'];
    final uid = uri.queryParameters['uid'];

    if (billId == null) {
      final index = uri.pathSegments.indexOf('bill');
      if (index != -1 && index + 1 < uri.pathSegments.length) {
        billId = uri.pathSegments[index + 1];
      }
    }

    return {'billId': billId, 'uid': uid};
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // 1. Listen for Links (Background/Warm Start)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // 3. LISTEN TO FIREBASE NOTIFICATIONS (Important!)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['billId'] != null) {
        _handleBillNavigation(message.data['billId'], uid: message.data['uid']);
      }
    });

    // 4. CHECK INITIAL NOTIFICATION (Terminated state)
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null && initialMessage.data['billId'] != null) {
      _handleBillNavigation(
        initialMessage.data['billId'],
        uid: initialMessage.data['uid'],
      );
    }
  }

  // Unified Handler for both Deep Links and Notifications
  Future<void> _handleDeepLink(Uri uri) async {
    if (_isHandlingLink) return;
    final linkData = _extractBillLinkData(uri);
    final billId = linkData['billId'];
    final uid = linkData['uid'];

    if (billId != null) {
      _handleBillNavigation(billId, uid: uid);
    }
  }

  Future<void> _handleBillNavigation(String billId, {String? uid}) async {
    if (_isHandlingLink) return;
    _isHandlingLink = true;

    // Small delay to prevent double-handling
    Future.delayed(const Duration(seconds: 1), () => _isHandlingLink = false);

    // Wait for frame to ensure navigator keys are ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;

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

        if (doc.exists) {
          final data = doc.data()!;
          bool amIHost = data['hostId'] == user.uid;
          String billName = data['storeName'] ?? "Bill";

          if (amIHost) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) =>
                    BillDetailsScreen(billId: billId, billName: billName),
              ),
            );
          } else {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) =>
                    ParticipantBillScreen(billId: billId, billName: billName),
              ),
            );
          }
        } else {
          debugPrint("Bill not found: $billId");
        }
      } catch (e) {
        debugPrint("Error navigating to bill: $e");
      }
    });
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
            context.locale.languageCode != appSettings.locale.languageCode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              context.setLocale(appSettings.locale);
            }
          });
        }

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Split Bill',
          onGenerateTitle: (context) => 'app_title'.tr(),
          debugShowCheckedModeBanner: false,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          theme: AppTheme.lightTheme,

          home: CustomUpgrader(
            child: billIdFromUrl != null
                ? GuestBillScreen(
                    billId: billIdFromUrl,
                    initialParticipantId: uidFromUrl,
                  )
                : const AuthWrapper(),
          ),
        );
      },
    );
  }
}
