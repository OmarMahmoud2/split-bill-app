import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../config/backend_config.dart';
import '../../services/guest_session.dart';
// Only needed after a payment; keep it out of the first web download.
import '../../services/notification_service.dart' deferred as notifications;

/// A payment screenshot ready to store on the bill.
class GuestProof {
  const GuestProof({required this.bytes, required this.dataUrl});

  final Uint8List bytes;

  /// `data:image/jpeg;base64,...`, the shape hosts already read.
  final String dataUrl;
}

/// The backend refused the payment update (HTTP [statusCode]).
class GuestPaymentRejected implements Exception {
  const GuestPaymentRejected(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'GuestPaymentRejected($statusCode)';
}

/// The screenshot would not fit in the bill document.
class GuestProofTooLarge implements Exception {
  const GuestProofTooLarge();
}

/// What the host gets told after a guest pays.
class GuestPaymentNotice {
  const GuestPaymentNotice({
    required this.billId,
    required this.hostId,
    required this.payerName,
    required this.storeName,
    required this.formattedAmount,
    required this.amount,
    required this.withProof,
    required this.title,
    required this.body,
  });

  final String billId;
  final String hostId;
  final String payerName;
  final String storeName;
  final String formattedAmount;
  final double amount;
  final bool withProof;

  /// Localized push title/body (the payer's language, as before 2.0).
  final String title;
  final String body;
}

/// Data access for the guest page. Tests swap in a fake.
abstract class GuestBillRepository {
  /// Live bill data; emits null when the bill does not exist.
  Stream<Map<String, dynamic>?> watch(String billId);

  /// Marks [participantId] as paid (status REVIEW) with an optional proof.
  Future<void> submitPayment({
    required String billId,
    required String participantId,
    String? proofDataUrl,
    String? method,
  });

  /// Best effort: never throws.
  Future<void> notifyHost(GuestPaymentNotice notice);

  /// Opens the gallery; null when cancelled.
  Future<GuestProof?> pickProof();
}

/// Proof images are stored inline as base64 in the bill document (1 MiB
/// limit for the whole document), so the encoded image is capped here.
const int maxProofDataUrlLength = 700 * 1024;

class FirestoreGuestBillRepository implements GuestBillRepository {
  FirestoreGuestBillRepository({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    Future<String?> Function()? idToken,
  }) : _firestore = firestore,
       _http = httpClient,
       _idToken = idToken;

  final FirebaseFirestore? _firestore;
  final http.Client? _http;
  final Future<String?> Function()? _idToken;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static const _timeout = Duration(seconds: 12);

  @override
  Stream<Map<String, dynamic>?> watch(String billId) async* {
    await GuestSession.ensureSignedIn().timeout(_timeout);
    yield* _db
        .collection('bills')
        .doc(billId)
        .snapshots()
        .map((s) => s.exists ? s.data() : null);
  }

  /// Guests never write the bill document (rules deny it). Signed-in members
  /// use the same endpoint for their own entry, so bills of any size work.
  /// The backend validates the participant, the status and the proof, then updates the
  /// one entry (POST .../guest-payment/).
  @override
  Future<void> submitPayment({
    required String billId,
    required String participantId,
    String? proofDataUrl,
    String? method,
  }) async {
    final String? token;
    if (_idToken != null) {
      token = await _idToken();
    } else {
      final user = await GuestSession.ensureSignedIn().timeout(_timeout);
      token = await user?.getIdToken().timeout(_timeout);
    }
    if (token == null || token.isEmpty) throw StateError('not_signed_in');

    final client = _http ?? http.Client();
    try {
      final response = await client
          .post(
            BackendConfig.guestPaymentUri(billId),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'participantId': participantId,
              'status': 'REVIEW',
              if (proofDataUrl != null) 'proofImage': proofDataUrl,
              if (method != null && method.trim().isNotEmpty)
                'method': method.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw GuestPaymentRejected(response.statusCode);
      }
    } finally {
      if (_http == null) client.close();
    }
  }

  @override
  Future<void> notifyHost(GuestPaymentNotice notice) async {
    if (notice.hostId.isEmpty) return;
    try {
      await notifications.loadLibrary();
      final service = notifications.NotificationService();
      final titleKey = notice.withProof
          ? 'payment_received'
          : 'payment_marked_as_sent';
      final bodyKey = notice.withProof
          ? 'payment_received_body'
          : 'payment_marked_as_sent_body';
      final args = notice.withProof
          ? {
              'payer': notice.payerName,
              'amount': notice.formattedAmount,
              'store': notice.storeName,
              'method_suffix': '',
            }
          : {'payer': notice.payerName, 'amount': notice.formattedAmount};
      await service.sendNotification(
        targetUid: notice.hostId,
        title: notice.title,
        body: notice.body,
        historyTitleKey: titleKey,
        historyBodyKey: bodyKey,
        historyBodyArgs: args,
        data: {
          'billId': notice.billId,
          'type': 'payment_proof',
          'amount': notice.amount.toString(),
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        },
      );
    } on Object {
      // The payment is saved; the host still sees it in the app.
    }
  }

  @override
  Future<GuestProof?> pickProof() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 25,
      maxWidth: 800,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    if (dataUrl.length > maxProofDataUrlLength) {
      throw const GuestProofTooLarge();
    }
    return GuestProof(bytes: bytes, dataUrl: dataUrl);
  }
}
