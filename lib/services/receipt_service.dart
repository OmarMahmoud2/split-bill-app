import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:split_bill_app/config/backend_config.dart';

class ReceiptService {
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
    final payload = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorMessage =
          payload['error'] as String? ??
          'Receipt scan failed with status ${response.statusCode}.';
      throw Exception(errorMessage);
    }

    final receipt = payload['receipt'] as Map<String, dynamic>?;
    if (receipt == null) {
      throw Exception('Receipt scan returned no receipt data.');
    }

    return receipt;
  }
}
