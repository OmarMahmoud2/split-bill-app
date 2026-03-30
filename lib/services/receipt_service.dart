import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:split_bill_app/config/backend_config.dart';

class ReceiptService {
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

  String _friendlyNonJsonError(http.Response response) {
    final statusCode = response.statusCode;
    if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
      return 'The scanner took too long to respond. Please try again in a moment.';
    }
    return 'The scan service returned an unexpected response. Please try again.';
  }

  Future<Map<String, dynamic>> scanReceiptImage(
    File imageFile, {
    String? localeCode,
    String? currencyCode,
  }) async {
    final authToken = await FirebaseAuth.instance.currentUser?.getIdToken();

    final request = http.MultipartRequest(
      'POST',
      BackendConfig.receiptScanUri,
    )..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    if (authToken != null && authToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    if (localeCode != null && localeCode.isNotEmpty) {
      request.fields['locale'] = localeCode;
    }
    if (currencyCode != null && currencyCode.isNotEmpty) {
      request.fields['currency'] = currencyCode;
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final contentType = response.headers['content-type'] ?? '';
    final isJsonResponse = contentType.toLowerCase().contains('application/json');
    Map<String, dynamic> payload = <String, dynamic>{};

    if (response.body.isNotEmpty && isJsonResponse) {
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } on FormatException {
        throw Exception('The scan service returned unreadable data. Please try again.');
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (!isJsonResponse) {
        throw Exception(_friendlyNonJsonError(response));
      }
      final errorMessage =
          payload['error'] as String? ??
          'Receipt scan failed with status ${response.statusCode}.';
      throw Exception(errorMessage);
    }

    if (!isJsonResponse) {
      throw Exception(_friendlyNonJsonError(response));
    }

    final receipt = payload['receipt'] as Map<String, dynamic>?;
    if (receipt == null) {
      throw Exception('Receipt scan returned no receipt data.');
    }

    return _normalizeReceipt(receipt);
  }
}
