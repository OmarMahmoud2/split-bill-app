import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// The signed-in user's own photo: only what they chose in Evens
/// (`users/{uid}.photoUrl`, a data URL). The Google/Apple sign-in photo is
/// never used on its own; the photo sheet offers it as an explicit choice.
class MyPhoto {
  MyPhoto._();

  /// Null means "show the pal avatar".
  static final ValueNotifier<String?> notifier = ValueNotifier<String?>(null);
  static String? _loadedFor;

  static String? chosen(Object? url) =>
      url is String && url.startsWith('data:') ? url : null;

  /// Called after the user picks or removes a photo.
  static void set(String? url) => notifier.value = chosen(url);

  /// Reads the stored photo once per user (and again after [reset]).
  static Future<void> load(String uid) async {
    if (_loadedFor == uid) return;
    _loadedFor = uid;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (_loadedFor == uid) set(doc.data()?['photoUrl']);
    } catch (_) {
      _loadedFor = null;
    }
  }

  /// On sign-out.
  static void reset() {
    _loadedFor = null;
    notifier.value = null;
  }
}
