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

  static Uri get billAddedUri =>
      Uri.parse('$baseUrl/api/split-bill/notifications/bill-added/');

  static Uri get iouAddedUri =>
      Uri.parse('$baseUrl/api/split-bill/notifications/iou-added/');

  static Uri get receiptScanUri =>
      Uri.parse('$baseUrl/api/split-bill/receipts/scan/');

  static Uri get voiceTranscriptionUri =>
      Uri.parse('$baseUrl/api/split-bill/voice/transcribe/');

  static Uri get voiceAssignmentUri =>
      Uri.parse('$baseUrl/api/split-bill/voice/assign/');

  static Uri get premiumSyncUri =>
      Uri.parse('$baseUrl/api/split-bill/premium/sync/');

  /// Marks one participant's payment on a bill (web guests and members).
  static Uri guestPaymentUri(String billId) => Uri.parse(
    '$baseUrl/api/split-bill/bills/${Uri.encodeComponent(billId)}/guest-payment/',
  );

  /// Admin-only: disables or re-enables a user's Firebase Auth account and
  /// sets the Firestore suspension flags.
  static Uri adminDisableUserUri(String uid) => Uri.parse(
    '$baseUrl/api/split-bill/admin/users/${Uri.encodeComponent(uid)}/disable',
  );

  /// Admin-only AI usage aggregation (proposed endpoint, see
  /// `AdminAiUsageService`).
  static Uri adminAiUsageUri({int days = 7}) =>
      Uri.parse('$baseUrl/api/split-bill/admin/ai-usage/?days=$days');
}
