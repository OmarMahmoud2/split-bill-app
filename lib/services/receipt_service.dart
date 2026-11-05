import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:split_bill_app/config/backend_config.dart';
import 'package:uuid/uuid.dart';

/// Why a receipt scan failed, so the UI can say what to do next.
enum ReceiptScanFailure {
  /// 422: the photo is not a receipt (menu, random photo). Credit refunded.
  notAReceipt,

  /// 413: the image is too large.
  tooLarge,

  /// 415: unsupported image format.
  unsupportedFormat,

  /// 402 / 403: not enough points or not allowed.
  noCredits,

  /// 429: too many scans.
  rateLimited,

  /// 502/503/504 or a timeout.
  timeout,

  /// No connection.
  offline,

  /// Anything else.
  unknown,
}

class ReceiptScanException implements Exception {
  const ReceiptScanException(
    this.failure, {
    this.statusCode,
    this.errorCode,
    this.refunded = false,
    this.serverMessage,
  });

  final ReceiptScanFailure failure;
  final int? statusCode;
  final String? errorCode;

  /// The server refunded the scan credit.
  final bool refunded;

  /// Raw server text; for logs only, never shown to the user.
  final String? serverMessage;

  @override
  String toString() =>
      'ReceiptScanException($failure, status: $statusCode, code: $errorCode)';
}

/// Classifies a non-2xx scan response.
ReceiptScanException classifyScanError(
  int statusCode,
  Map<String, dynamic> payload,
) {
  final code = payload['errorCode']?.toString() ?? payload['error_code']?.toString();
  final refundedRaw = payload['refunded'] ?? payload['credit_refunded'];
  final message = payload['error']?.toString();
  ReceiptScanFailure failure;
  switch (statusCode) {
    case 422:
      failure = ReceiptScanFailure.notAReceipt;
    case 413:
      failure = ReceiptScanFailure.tooLarge;
    case 415:
      failure = ReceiptScanFailure.unsupportedFormat;
    case 402:
    case 403:
      failure = ReceiptScanFailure.noCredits;
    case 429:
      failure = ReceiptScanFailure.rateLimited;
    case 408:
    case 502:
    case 503:
    case 504:
      failure = ReceiptScanFailure.timeout;
    default:
      failure = ReceiptScanFailure.unknown;
  }
  return ReceiptScanException(
    failure,
    statusCode: statusCode,
    errorCode: code,
    // A rejected non-receipt is always refunded by the backend.
    refunded: refundedRaw == true || failure == ReceiptScanFailure.notAReceipt,
    serverMessage: message,
  );
}

class ReceiptService {
  ReceiptService({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String Function()? requestIdFactory,
  }) : _client = client,
       _tokenProvider = tokenProvider,
       _requestIdFactory = requestIdFactory ?? (() => const Uuid().v4());

  final http.Client? _client;
  final Future<String?> Function()? _tokenProvider;
  final String Function() _requestIdFactory;

  /// Request id of the latest attempt (idempotency key).
  String? lastRequestId;

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim()) ?? 0.0;
    return 0.0;
  }

  bool _isClose(double a, double b, {double tolerance = 0.01}) {
    return (a - b).abs() <= tolerance;
  }

  String _normalizeLabel(String? value) {
    if (value == null) return '';
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  bool _matchesAny(String label, List<String> patterns) {
    return patterns.any((pattern) => label.contains(pattern));
  }

  Map<String, dynamic> _normalizeReceipt(Map<String, dynamic> receipt) {
    final normalized = Map<String, dynamic>.from(receipt);
    final otherCharges = List<Map<String, dynamic>>.from(
      (normalized['other_charges'] as List? ?? const []).map(
        (charge) => Map<String, dynamic>.from(charge as Map),
      ),
    );

    double taxAmount = _toDouble(normalized['tax_amount']);
    double serviceCharge = _toDouble(normalized['service_charge']);
    double tipAmount = _toDouble(normalized['tip_amount']);
    double discountAmount = _toDouble(normalized['discount_amount']);
    double deliveryFee = _toDouble(normalized['delivery_fee']);
    final subtotal = _toDouble(normalized['subtotal']);
    final totalAmount = _toDouble(normalized['total_amount']);

    final dedupedOtherCharges = <Map<String, dynamic>>[];

    for (final charge in otherCharges) {
      final label = _normalizeLabel(charge['label']?.toString());
      final amount = _toDouble(charge['amount']);
      if (label.isEmpty || amount == 0) {
        dedupedOtherCharges.add(charge);
        continue;
      }

      final isTax = _matchesAny(label, [
        'tax',
        'vat',
        'sales tax',
        'service tax',
      ]);
      final isService = _matchesAny(label, [
        'service charge',
        'service fee',
        'service',
      ]);
      final isTip = _matchesAny(label, ['tip', 'gratuity']);
      final isDelivery = _matchesAny(label, ['delivery', 'shipping']);
      final isDiscount = _matchesAny(label, ['discount', 'promo', 'coupon']);
      final isSubtotal = _matchesAny(label, ['subtotal', 'sub total']);
      final isTotal = _matchesAny(label, ['total due', 'grand total', 'total']);

      if (isTax) {
        if (taxAmount == 0.0) taxAmount = amount;
        if (_isClose(taxAmount, amount)) continue;
      }

      if (isService) {
        if (serviceCharge == 0.0) serviceCharge = amount;
        if (_isClose(serviceCharge, amount)) continue;
      }

      if (isTip) {
        if (tipAmount == 0.0) tipAmount = amount;
        if (_isClose(tipAmount, amount)) continue;
      }

      if (isDelivery) {
        if (deliveryFee == 0.0) deliveryFee = amount;
        if (_isClose(deliveryFee, amount)) continue;
      }

      if (isDiscount) {
        if (discountAmount == 0.0) discountAmount = amount;
        if (_isClose(discountAmount, amount)) continue;
      }

      if (isSubtotal && subtotal > 0 && _isClose(subtotal, amount)) {
        continue;
      }

      if (isTotal && totalAmount > 0 && _isClose(totalAmount, amount)) {
        continue;
      }

      dedupedOtherCharges.add(charge);
    }

    normalized['tax_amount'] = taxAmount;
    normalized['service_charge'] = serviceCharge;
    normalized['tip_amount'] = tipAmount;
    normalized['discount_amount'] = discountAmount;
    normalized['delivery_fee'] = deliveryFee;
    normalized['other_charges'] = dedupedOtherCharges;
    normalized['other_charges_total'] = dedupedOtherCharges.fold<double>(
      0.0,
      (runningTotal, charge) => runningTotal + _toDouble(charge['amount']),
    );

    return normalized;
  }

  Future<Map<String, dynamic>> scanReceiptImage(
    File imageFile, {
    String? localeCode,
    String? currencyCode,
    String? requestId,
  }) async {
    final authToken = _tokenProvider != null
        ? await _tokenProvider()
        : await FirebaseAuth.instance.currentUser?.getIdToken();

    final id = requestId ?? _requestIdFactory();
    lastRequestId = id;
    final request = http.MultipartRequest(
      'POST',
      BackendConfig.receiptScanUri,
    )..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    request.fields['requestId'] = id;
    request.headers['X-Request-Id'] = id;

    if (authToken != null && authToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    if (localeCode != null && localeCode.isNotEmpty) {
      request.fields['locale'] = localeCode;
    }
    if (currencyCode != null && currencyCode.isNotEmpty) {
      request.fields['currency'] = currencyCode;
    }

    http.Response response;
    try {
      final streamedResponse = await (_client?.send(request) ?? request.send())
          .timeout(const Duration(seconds: 90));
      response = await http.Response.fromStream(streamedResponse);
    } on SocketException {
      throw const ReceiptScanException(ReceiptScanFailure.offline);
    } on http.ClientException {
      throw const ReceiptScanException(ReceiptScanFailure.offline);
    } on TimeoutException {
      throw const ReceiptScanException(ReceiptScanFailure.timeout);
    }
    return parseScanResponse(response);
  }

  /// Parses a scan response (public for tests).
  Map<String, dynamic> parseScanResponse(http.Response response) {
    final contentType = response.headers['content-type'] ?? '';
    final isJsonResponse = contentType.toLowerCase().contains('application/json');
    Map<String, dynamic> payload = <String, dynamic>{};

    if (response.body.isNotEmpty && isJsonResponse) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) payload = decoded;
      } on FormatException {
        payload = <String, dynamic>{};
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw classifyScanError(response.statusCode, payload);
    }

    final receipt = payload['receipt'];
    if (receipt is! Map) {
      throw ReceiptScanException(
        ReceiptScanFailure.unknown,
        statusCode: response.statusCode,
      );
    }

    final normalized = _normalizeReceipt(Map<String, dynamic>.from(receipt));
    // 2.0 review fields may sit on the receipt or next to it.
    final reasons =
        receipt['needs_review_reasons'] ?? payload['needs_review_reasons'];
    if (reasons is List) {
      normalized['needs_review_reasons'] = [
        for (final r in reasons) r.toString(),
      ];
      if (reasons.isNotEmpty) normalized['needs_review'] = true;
    }
    final reconciliation =
        receipt['reconciliation'] ?? payload['reconciliation'];
    if (reconciliation is Map) {
      normalized['reconciliation'] = Map<String, dynamic>.from(reconciliation);
    }
    if (payload['requestId'] != null) {
      normalized['requestId'] = payload['requestId'].toString();
    }
    return normalized;
  }
}
