/// "You were added" pushes. The backend (`notifications/bill-added/`,
/// `notifications/iou-added/`) loads the bill or IOU itself, checks the caller
/// created it, skips guests and people already notified, and writes the push
/// in each recipient's language. Fire and forget: failures are only logged.
library;

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:split_bill_app/config/backend_config.dart';

/// Registered members in [after] that were not in [before]: never
/// [selfUid], never a guest (`guest_*`), never empty or duplicate ids.
List<String> newlyAddedMembers({
  required Iterable<Object?> before,
  required Iterable<Object?> after,
  required String selfUid,
}) {
  final old = before.map((e) => e.toString()).toSet();
  return {
        for (final e in after)
          if (e != null) e.toString(),
      }
      .where(
        (id) =>
            id.isNotEmpty &&
            id != selfUid &&
            !id.startsWith('guest_') &&
            !old.contains(id),
      )
      .toList();
}

Future<void> _post(
  Uri uri,
  Map<String, String> body, {
  http.Client? client,
  Future<String?> Function()? idToken,
}) async {
  try {
    final token = await (idToken != null
        ? idToken()
        : FirebaseAuth.instance.currentUser?.getIdToken());
    if (token == null || token.isEmpty) {
      return;
    }
    final c = client ?? http.Client();
    try {
      final r = await c
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode >= 300 && kDebugMode)
        debugPrint('added push ${r.statusCode}');
    } finally {
      if (client == null) c.close();
    }
  } catch (e) {
    if (kDebugMode) debugPrint('added push failed: $e');
  }
}

/// Call after a bill is saved. Does nothing when nobody new was added.
Future<void> notifyBillAdded({
  required String billId,
  required String selfUid,
  required Iterable<Object?> before,
  required Iterable<Object?> after,
  http.Client? client,
  Future<String?> Function()? idToken,
}) async {
  if (newlyAddedMembers(before: before, after: after, selfUid: selfUid).isEmpty)
    return;
  await _post(
    BackendConfig.billAddedUri,
    {'billId': billId},
    client: client,
    idToken: idToken,
  );
}

/// Call after a Quick IOU is saved; the backend picks the other party.
Future<void> notifyIouAdded({
  required String paymentId,
  String? groupId,
  http.Client? client,
  Future<String?> Function()? idToken,
}) => _post(
  BackendConfig.iouAddedUri,
  {'paymentId': paymentId, if (groupId != null) 'groupId': groupId},
  client: client,
  idToken: idToken,
);
