import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:split_bill_app/config/backend_config.dart';

/// Disables or re-enables the Firebase Auth account of [uid] through the
/// backend (`POST /api/split-bill/admin/users/<uid>/disable`). The backend
/// also revokes the user's sessions, sets or clears the `suspended` flags and
/// writes the audit entry itself.
///
/// Returns true when the backend did all of that; false when it could not be
/// reached or refused (the caller then falls back to the Firestore flag).
Future<bool> disableAccountViaBackend(
  String uid, {
  required bool disabled,
  String? reason,
  http.Client? client,
  Future<String?> Function()? idToken,
}) async {
  try {
    final token = await (idToken != null
        ? idToken()
        : FirebaseAuth.instance.currentUser?.getIdToken());
    if (token == null || token.isEmpty) return false;
    final c = client ?? http.Client();
    try {
      final response = await c
          .post(
            BackendConfig.adminDisableUserUri(uid),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'disabled': disabled,
              if (reason != null && reason.trim().isNotEmpty)
                'reason': reason.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      return response.statusCode >= 200 && response.statusCode < 300;
    } finally {
      if (client == null) c.close();
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Admin disable via backend failed: $e');
    return false;
  }
}
