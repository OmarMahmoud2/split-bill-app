import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:split_bill_app/config/backend_config.dart';

class BillIntelligenceService {
  /// Analyzes the voice transcript and assigns items to participants.
  ///
  /// [receiptItems] should contain: "name" and "price" (and optionally "id" if available, else index).
  /// [participants] should contain: "id" and "name".
  /// [transcript] is the text from Whisper.
  ///
  /// Returns a Map where keys are item indices (or IDs) and values are lists of participant IDs.
  Future<Map<String, List<String>>> assignItemsByVoice({
    required List<Map<String, dynamic>> receiptItems,
    required List<Map<String, dynamic>> participants,
    required String transcript,
  }) async {
    try {
      final authToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        BackendConfig.voiceAssignmentUri,
        headers: {
          'Content-Type': 'application/json',
          if (authToken != null && authToken.isNotEmpty)
            'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'receiptItems': receiptItems,
          'participants': participants,
          'transcript': transcript,
        }),
      );

      final payload = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final rawAssignments = payload['assignments'] as Map<String, dynamic>?;
        if (rawAssignments == null) {
          throw Exception('Voice assignment returned no assignments payload.');
        }

        final result = <String, List<String>>{};
        rawAssignments.forEach((key, value) {
          if (value is List) {
            result[key] = value.map((entry) => entry.toString()).toList();
          }
        });

        return result;
      }

      final errorMessage =
          payload['error'] as String? ??
          'Voice assignment failed with status ${response.statusCode}.';
      throw Exception(errorMessage);
    } catch (e) {
      debugPrint('Error in BillIntelligenceService: $e');
      rethrow;
    }
  }
}
