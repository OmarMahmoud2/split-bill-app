import 'dart:io';

import 'package:flutter/foundation.dart';

class BackendConfig {
  static const String _overrideBaseUrl = String.fromEnvironment(
    'SPLIT_BILL_API_BASE_URL',
    defaultValue: '',
  );
  static const String _productionBaseUrl = 'https://omarmali.net';

  static String get baseUrl {
    if (_overrideBaseUrl.isNotEmpty) {
      return _overrideBaseUrl;
    }

    if (!kDebugMode) {
      return _productionBaseUrl;
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static Uri get notificationUri =>
      Uri.parse('$baseUrl/api/split-bill/notifications/send/');

  static Uri get receiptScanUri =>
      Uri.parse('$baseUrl/api/split-bill/receipts/scan/');

  static Uri get voiceTranscriptionUri =>
      Uri.parse('$baseUrl/api/split-bill/voice/transcribe/');

  static Uri get voiceAssignmentUri =>
      Uri.parse('$baseUrl/api/split-bill/voice/assign/');
}
