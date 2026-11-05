import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

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
  FirestoreGuestBillRepository({FirebaseFirestore? firestore})
    : _firestore = firestore;

  final FirebaseFirestore? _firestore;
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

  /// Stage A rule-compatible write: only `participants` changes, same list
  /// length (firestore.rules paymentOnlyBillUpdate).
  @override
  Future<void> submitPayment({
    required String billId,
    required String participantId,
    String? proofDataUrl,
  }) async {
    final billRef = _db.collection('bills').doc(billId);
    await _db.runTransaction<void>((transaction) async {
      final snapshot = await transaction.get(billRef);
      if (!snapshot.exists) throw StateError('bill_not_found');
      final data = snapshot.data()!;
      final participants = (data['participants'] as List<dynamic>? ?? const [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
      final index = participants.indexWhere((p) => p['id'] == participantId);
      if (index == -1) throw StateError('participant_not_found');
      participants[index] = {
        ...participants[index],
        'paymentProof': proofDataUrl,
        'status': 'REVIEW',
        'paymentTime': Timestamp.now(),
      };
      transaction.update(billRef, {'participants': participants});
    });
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
