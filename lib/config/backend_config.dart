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
    return _productionBaseUrl;
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
