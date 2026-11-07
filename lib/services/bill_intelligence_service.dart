import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:split_bill_app/config/backend_config.dart';
import 'package:uuid/uuid.dart';

/// Result of `voice/assign/`.
class VoiceAssignResult {
  const VoiceAssignResult({
    required this.assignments,
    this.splits = const {},
    this.unassignedItemKeys = const [],
    this.ambiguous = const [],
    this.requestId,
  });

  /// Item key (index as string) -> participant ids sharing it equally.
  final Map<String, List<String>> assignments;

  /// Item key -> units per participant, for items with quantity > 1.
  final Map<String, Map<String, int>> splits;

  /// Items the transcript did not cover.
  final List<String> unassignedItemKeys;

  /// Things the backend was unsure about, as short texts.
  final List<VoiceAmbiguity> ambiguous;
  final String? requestId;

  bool get isEmpty => assignments.isEmpty && splits.isEmpty;

  /// Parses the response; tolerant of missing or extra fields.
  factory VoiceAssignResult.fromJson(Map<String, dynamic> json) {
    final assignments = <String, List<String>>{};
    final rawAssignments = json['assignments'];
    if (rawAssignments is Map) {
      rawAssignments.forEach((key, value) {
        if (value is List) {
          assignments[key.toString()] = [for (final v in value) v.toString()];
        }
      });
    }
    final splits = <String, Map<String, int>>{};
    final rawSplits = json['splits'];
    if (rawSplits is Map) {
      rawSplits.forEach((key, value) {
        if (value is Map) {
          final units = <String, int>{};
          value.forEach((pid, n) {
            if (n is num && n > 0) units[pid.toString()] = n.round();
          });
          if (units.isNotEmpty) splits[key.toString()] = units;
        }
      });
    } else if (rawSplits is List) {
      // [{itemKey, participantId, units}] or [{itemKey, units: {id: n}}]
      for (final entry in rawSplits) {
        if (entry is! Map) continue;
        final key = (entry['itemKey'] ?? entry['item'] ?? '').toString();
        if (key.isEmpty) continue;
        final units = entry['units'];
        if (units is Map) {
          final map = splits.putIfAbsent(key, () => {});
          units.forEach((pid, n) {
            if (n is num && n > 0) map[pid.toString()] = n.round();
          });
        } else if (units is num && entry['participantId'] != null) {
          splits.putIfAbsent(key, () => {})[entry['participantId']
                  .toString()] =
              units.round();
        }
      }
    }
    final unassigned = <String>[
      for (final k in (json['unassignedItemKeys'] as List?) ?? const [])
        k.toString(),
    ];
    final ambiguous = <VoiceAmbiguity>[];
    for (final a in (json['ambiguous'] as List?) ?? const []) {
      if (a is Map) {
        ambiguous.add(
          VoiceAmbiguity(
            itemKey: a['itemKey']?.toString(),
            text: (a['text'] ?? a['phrase'] ?? a['reason'] ?? '').toString(),
          ),
        );
      } else if (a != null) {
        ambiguous.add(VoiceAmbiguity(text: a.toString()));
      }
    }
    return VoiceAssignResult(
      assignments: assignments,
      splits: splits,
      unassignedItemKeys: unassigned,
      ambiguous: ambiguous,
      requestId: json['requestId']?.toString(),
    );
  }
}

class VoiceAmbiguity {
  const VoiceAmbiguity({this.itemKey, required this.text});
  final String? itemKey;
  final String text;
}

enum VoiceAssignFailure { offline, timeout, noCredits, rateLimited, unknown }

class VoiceAssignException implements Exception {
  const VoiceAssignException(this.failure, {this.statusCode});
  final VoiceAssignFailure failure;
  final int? statusCode;

  @override
  String toString() => 'VoiceAssignException($failure, $statusCode)';
}

class BillIntelligenceService {
  BillIntelligenceService({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String Function()? requestIdFactory,
  }) : _client = client,
       _tokenProvider = tokenProvider,
       _requestIdFactory = requestIdFactory ?? (() => const Uuid().v4());

  final http.Client? _client;
  final Future<String?> Function()? _tokenProvider;
  final String Function() _requestIdFactory;

  /// Builds the JSON body (public for tests).
  Map<String, dynamic> buildAssignBody({
    required List<Map<String, dynamic>> receiptItems,
    required List<Map<String, dynamic>> participants,
    required String transcript,
    required String requestId,
    String? currentUserId,
    Map<String, List<String>> aliases = const {},
    String transcriptSource = 'on_device',
  }) {
    return {
      'requestId': requestId,
      'receiptItems': [
        for (var i = 0; i < receiptItems.length; i++)
          {
            'key': '$i',
            'name': receiptItems[i]['name'],
            'price': receiptItems[i]['price'],
            'qty': receiptItems[i]['qty'],
          },
      ],
      'participants': [
        for (final p in participants) {'id': p['id'], 'name': p['name']},
      ],
      'transcript': transcript,
      'currentUserId': ?currentUserId,
      if (aliases.isNotEmpty) 'aliases': aliases,
      'transcriptSource': transcriptSource,
    };
  }

  /// Sends the TEXT transcript to `voice/assign/`.
  ///
  /// A fresh `requestId` is sent per attempt so a retried request is never
  /// charged twice.
  Future<VoiceAssignResult> assignItemsByVoice({
    required List<Map<String, dynamic>> receiptItems,
    required List<Map<String, dynamic>> participants,
    required String transcript,
    String? currentUserId,
    Map<String, List<String>> aliases = const {},
    String transcriptSource = 'on_device',
  }) async {
    final authToken = _tokenProvider != null
        ? await _tokenProvider()
        : await FirebaseAuth.instance.currentUser?.getIdToken();
    final requestId = _requestIdFactory();
    final body = buildAssignBody(
      receiptItems: receiptItems,
      participants: participants,
      transcript: transcript,
      requestId: requestId,
      currentUserId: currentUserId,
      aliases: aliases,
      transcriptSource: transcriptSource,
    );
    http.Response response;
    try {
      final headers = {
        'Content-Type': 'application/json',
        'X-Request-Id': requestId,
        if (authToken != null && authToken.isNotEmpty)
          'Authorization': 'Bearer $authToken',
      };
      final future = _client != null
          ? _client.post(
              BackendConfig.voiceAssignmentUri,
              headers: headers,
              body: jsonEncode(body),
            )
          : http.post(
              BackendConfig.voiceAssignmentUri,
              headers: headers,
              body: jsonEncode(body),
            );
      response = await future.timeout(const Duration(seconds: 45));
    } on SocketException {
      throw const VoiceAssignException(VoiceAssignFailure.offline);
    } on http.ClientException {
      throw const VoiceAssignException(VoiceAssignFailure.offline);
    } on TimeoutException {
      throw const VoiceAssignException(VoiceAssignFailure.timeout);
    }
    return parseAssignResponse(response);
  }

  VoiceAssignResult parseAssignResponse(http.Response response) {
    Map<String, dynamic> payload = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } on FormatException {
        payload = const {};
      }
    }
    if (response.statusCode == 200) {
      return VoiceAssignResult.fromJson(payload);
    }
    debugPrint('voice/assign failed: ${response.statusCode}');
    final failure = switch (response.statusCode) {
      402 || 403 => VoiceAssignFailure.noCredits,
      429 => VoiceAssignFailure.rateLimited,
      408 || 502 || 503 || 504 => VoiceAssignFailure.timeout,
      _ => VoiceAssignFailure.unknown,
    };
    throw VoiceAssignException(failure, statusCode: response.statusCode);
  }
}
