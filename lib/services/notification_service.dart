import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/config/backend_config.dart';
import 'package:split_bill_app/services/notification_payload.dart';
import 'package:split_bill_app/services/guest_session.dart';
import 'dart:async';

class NotificationService with WidgetsBindingObserver {
  /// Taps on notifications this app showed itself while in the foreground
  /// (system-shown pushes arrive through FirebaseMessaging.onMessageOpenedApp).
  static final StreamController<Map<String, dynamic>> _localTaps =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get localTaps => _localTaps.stream;

  NotificationService._internal();

  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;
  bool _isSyncingToken = false;
  String? _lastSyncedUid;
  String? _lastSyncedToken;
  String? _lastSyncedTimezone;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    // 1. Permission. Never show the OS prompt at launch: the
    // NotificationPermissionScreen explainer asks at the right moment via
    // [requestPermission]. Only refresh when already granted (no prompt).
    NotificationSettings settings = await _fcm.getNotificationSettings();
    if (_isGranted(settings)) {
      settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    }

    // 2. Setup Local Notifications (the Android channel must exist even
    // before permission is granted, so later campaign pushes use it).
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final data = decodeLocalPayload(response.payload);
        if (data != null) _localTaps.add(data);
      },
    );

    // Create Android Notification Channel explicitly
    if (!kIsWeb && Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'split_bill_channel', // id
        'Evens notifications', // title
        description: 'Notifications for bill splitting updates', // description
        importance: Importance.max,
        playSound: true,
      );

      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      await androidImplementation?.createNotificationChannel(channel);
    }

    if (!_isGranted(settings)) {
      debugPrint('User declined or has not accepted permission');
      // Keep the stored profile (timezone, notificationsEnabled=false) current.
      unawaited(syncTokenForCurrentUser(force: true));
      return;
    }

    await _startMessaging();
  }

  static const _askedPreferenceKey = 'notif_prompt_asked';
  bool _messagingStarted = false;

  static bool _isGranted(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  /// True when the OS prompt has not been answered yet. Android reports
  /// "denied" before the first POST_NOTIFICATIONS request, so there we also
  /// ask once if this app never asked.
  Future<bool> shouldAskPermission() async {
    if (kIsWeb) return false;
    final status = (await _fcm.getNotificationSettings()).authorizationStatus;
    if (status == AuthorizationStatus.notDetermined) return true;
    if (Platform.isAndroid && status == AuthorizationStatus.denied) {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_askedPreferenceKey) ?? false);
    }
    return false;
  }

  /// Shows the OS permission prompt (iOS, Android 13+). Returns whether
  /// notifications are now allowed; starts token sync when they are.
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedPreferenceKey, true);
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted = _isGranted(settings);
    if (granted) {
      await _startMessaging();
    } else {
      unawaited(syncTokenForCurrentUser(force: true));
    }
    return granted;
  }

  Future<void> _startMessaging() async {
    if (_messagingStarted) return;
    _messagingStarted = true;

    // 3. Get Token (With Retry Logic for iOS)
    if (!kIsWeb && Platform.isIOS) {
      String? apnsToken;
      for (int i = 0; i < 3; i++) {
        apnsToken = await _fcm.getAPNSToken();
        if (apnsToken != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }
      if (apnsToken == null) {
        debugPrint("Warning: APNS token not received (Simulator?)");
      }
    }

    // Listen for Auth Changes to Ensure Token Save
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      User? user,
    ) async {
      if (memberOrNull(user) != null) {
        await syncTokenForCurrentUser(force: true);
      } else if (_lastSyncedUid != null) {
        await clearStoredTokenForCurrentUser();
      }
    });

    // Fetch FCM Token (Initial fetch, will be updated by authStateChanges if user logs in later)
    try {
      await syncTokenForCurrentUser(force: true);
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
    }

    // 4. Listen for Token Refreshes
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _fcm.onTokenRefresh.listen((newToken) {
      _lastSyncedToken = newToken;
      syncTokenForCurrentUser(force: true, tokenOverride: newToken);
    });

    // 5. Listen for Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(syncTokenForCurrentUser());
    }
  }

  Future<void> syncTokenForCurrentUser({
    bool force = false,
    String? tokenOverride,
  }) async {
    final user = memberOrNull(FirebaseAuth.instance.currentUser);
    if (user == null || _isSyncingToken) return;

    _isSyncingToken = true;
    try {
      String? apnsToken;
      if (!kIsWeb && Platform.isIOS) {
        apnsToken = await _fcm.getAPNSToken();
      }

      final token = tokenOverride ?? await _fcm.getToken();
      if (token == null || token.isEmpty) return;

      final timezone = await _localTimezone();
      if (!force &&
          _lastSyncedUid == user.uid &&
          _lastSyncedToken == token &&
          _lastSyncedTimezone == timezone) {
        return;
      }

      await _saveTokenToDatabase(
        uid: user.uid,
        token: token,
        apnsToken: apnsToken,
        timezone: timezone,
      );

      _lastSyncedUid = user.uid;
      _lastSyncedToken = token;
      _lastSyncedTimezone = timezone;
    } catch (e) {
      debugPrint("Error syncing FCM token: $e");
    } finally {
      _isSyncingToken = false;
    }
  }

  Future<void> _saveTokenToDatabase({
    required String uid,
    required String token,
    String? apnsToken,
    String? timezone,
  }) async {
    final notificationSettings = await _fcm.getNotificationSettings();
    final permitted =
        notificationSettings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        notificationSettings.authorizationStatus ==
            AuthorizationStatus.provisional;
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final current = await transaction.get(userRef);
      final data = current.data() ?? <String, dynamic>{};
      // A token refresh must never undo an explicit user opt-out, but an
      // OS-permission-derived `false` is lifted once permission is granted.
      final enabled = notificationsEnabledUpdate(
        permitted: permitted,
        hasStoredValue: data.containsKey('notificationsEnabled'),
        storedValue: data['notificationsEnabled'],
        storedSource: data['notificationsEnabledSource'],
      );
      transaction.set(userRef, {
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        if (enabled != null) ...{
          'notificationsEnabled': enabled,
          'notificationsEnabledSource': notificationsEnabledSystemSource,
        },
        if (timezone != null) 'timezone': timezone,
        'fcmPlatform': kIsWeb ? 'web' : Platform.operatingSystem,
        if (apnsToken != null && apnsToken.isNotEmpty) 'apnsToken': apnsToken,
      }, SetOptions(merge: true));
    });
  }

  /// The device IANA zone (e.g. `Africa/Cairo`), or null when unavailable or
  /// not an IANA name; the server then uses its documented fallback.
  Future<String?> _localTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return normalizeIanaTimezone(info.identifier);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearStoredTokenForCurrentUser() async {
    final uid = _lastSyncedUid;
    final token = _lastSyncedToken;
    if (uid == null || token == null || token.isEmpty) {
      _lastSyncedUid = null;
      _lastSyncedToken = null;
      return;
    }

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final snapshot = await userRef.get();
      final currentStoredToken = snapshot.data()?['fcmToken'] as String?;
      if (currentStoredToken == token) {
        await userRef.set({
          'fcmToken': FieldValue.delete(),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error clearing FCM token: $e");
    } finally {
      _lastSyncedUid = null;
      _lastSyncedToken = null;
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    _localNotifications.show(
      message.hashCode,
      message.notification!.title,
      message.notification!.body,
      payload: jsonEncode(message.data),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'split_bill_channel',
          'Evens notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // --- ACTIONS: Manage History ---

  Future<void> markAsRead(String notificationId) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> markAllAsRead() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  Future<void> clearAll() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    var batch = FirebaseFirestore.instance.batch();
    var snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // --- HTTP BACKEND SENDING LOGIC ---
  /// Saves the notification to the target's history and asks the backend to
  /// push it. The backend looks up the target's FCM token itself and checks
  /// that the caller shares [billId] with them (admins may omit it).
  /// Returns true when the backend accepted the push.
  Future<bool> sendNotification({
    required String targetUid,
    required String title,
    required String body,
    String? billId,
    Map<String, dynamic>? data,
    String? historyTitleKey,
    String? historyBodyKey,
    Map<String, String>? historyTitleArgs,
    Map<String, String>? historyBodyArgs,
  }) async {
    final resolvedBillId = billId ?? data?['billId']?.toString();

    // 1. SAVE TO HISTORY FIRST (Ensures history works even if push fails)
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .add({
            'title': title,
            'body': body,
            if (historyTitleKey != null) 'titleKey': historyTitleKey,
            if (historyBodyKey != null) 'bodyKey': historyBodyKey,
            if (historyTitleArgs != null) 'titleArgs': historyTitleArgs,
            if (historyBodyArgs != null) 'bodyArgs': historyBodyArgs,
            'date': FieldValue.serverTimestamp(),
            'read': false,
            'data': data,
          });
      debugPrint("✅ Notification saved to history for UID: $targetUid");
    } catch (e) {
      debugPrint("❌ Error saving notification history: $e");
    }

    // 2. SEND PUSH (Via Secure Backend)
    try {
      final authToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      Map<String, dynamic> fcmData = Map<String, dynamic>.from(data ?? {});
      fcmData['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';
      if (resolvedBillId != null) fcmData['billId'] = resolvedBillId;

      debugPrint("--- SENDING PUSH NOTIFICATION ---");
      debugPrint("Target UID: $targetUid");
      debugPrint("Payload: $fcmData");

      final response = await http.post(
        BackendConfig.notificationUri,
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null && authToken.isNotEmpty)
            'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'targetUid': targetUid,
          if (resolvedBillId != null) 'billId': resolvedBillId,
          'title': title,
          'body': body,
          'data': fcmData,
        }),
      );

      debugPrint("Backend Response: ${response.statusCode} - ${response.body}");
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint("❌ Notification backend rejected the request.");
        return false;
      }
      return true;
    } catch (e) {
      debugPrint("❌ Error calling notification backend: $e");
      return false;
    }
  }
}

/// Payload of a locally shown notification back to the FCM data map.
Map<String, dynamic>? decodeLocalPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}
