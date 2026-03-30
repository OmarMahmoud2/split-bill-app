import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:split_bill_app/config/backend_config.dart';
import 'dart:async';

class NotificationService with WidgetsBindingObserver {
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

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    // 1. Request Permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('User declined or has not accepted permission');
      return;
    }

    // 2. Setup Local Notifications
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);

    // Create Android Notification Channel explicitly
    if (!kIsWeb && Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'split_bill_channel', // id
        'Split Bill Notifications', // title
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
      if (user != null) {
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSyncingToken) return;

    _isSyncingToken = true;
    try {
      String? apnsToken;
      if (!kIsWeb && Platform.isIOS) {
        apnsToken = await _fcm.getAPNSToken();
      }

      final token = tokenOverride ?? await _fcm.getToken();
      if (token == null || token.isEmpty) return;

      if (!force && _lastSyncedUid == user.uid && _lastSyncedToken == token) {
        return;
      }

      await _saveTokenToDatabase(
        uid: user.uid,
        token: token,
        apnsToken: apnsToken,
      );

      _lastSyncedUid = user.uid;
      _lastSyncedToken = token;
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
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'notificationsEnabled': true,
      'fcmPlatform': kIsWeb ? 'web' : Platform.operatingSystem,
      if (apnsToken != null && apnsToken.isNotEmpty) 'apnsToken': apnsToken,
    }, SetOptions(merge: true));
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
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'split_bill_channel',
          'Split Bill Notifications',
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
  Future<void> sendNotification({
    required String targetToken,
    required String title,
    required String body,
    String? targetUid,
    Map<String, dynamic>? data,
    String? historyTitleKey,
    String? historyBodyKey,
    Map<String, String>? historyTitleArgs,
    Map<String, String>? historyBodyArgs,
  }) async {
    // 1. SAVE TO HISTORY FIRST (Ensures history works even if push fails)
    if (targetUid != null) {
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
    } else {
      debugPrint(
        "⚠️ No targetUid provided, notification NOT saved to history.",
      );
    }

    // 2. SEND PUSH (Via Secure Backend)
    try {
      final authToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      Map<String, dynamic> fcmData = Map<String, dynamic>.from(data ?? {});
      fcmData['click_action'] = 'FLUTTER_NOTIFICATION_CLICK';
      if (fcmData['billId'] == null && data?['billId'] != null) {
        fcmData['billId'] = data!['billId'];
      }

      debugPrint("--- SENDING PUSH NOTIFICATION ---");
      debugPrint("Target: $targetToken");
      debugPrint("Payload: $fcmData");

      final response = await http.post(
        BackendConfig.notificationUri,
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null && authToken.isNotEmpty)
            'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'token': targetToken,
          'title': title,
          'body': body,
          'data': fcmData,
        }),
      );

      debugPrint("Backend Response: ${response.statusCode} - ${response.body}");
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint("❌ Notification backend rejected the request.");
      }
    } catch (e) {
      debugPrint("❌ Error calling notification backend: $e");
    }
  }
}
