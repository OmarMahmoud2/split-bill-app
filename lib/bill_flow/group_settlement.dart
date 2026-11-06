import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/data/models.dart';

/// Field on a bill participant that links their share to the settle-up
/// payment created when the host marked it paid.
const settlementPaymentIdField = 'settlementPaymentId';

/// In group ledgers settle-up payments are the source of truth, so a host
/// marking a member's share paid must also record that payment. Returns the
/// payment to record, or null when the share is outside a group, belongs to
/// the host or a guest without an account, or is empty.
PaymentRecord? groupSettlementForPaidShare({
  required String billId,
  required Map<String, dynamic> bill,
  required Map<String, dynamic> participant,
  required String createdBy,
}) {
  final groupId = bill['groupId']?.toString() ?? '';
  final hostId = bill['hostId']?.toString() ?? '';
  final memberId = participant['id']?.toString() ?? '';
  final uids = ((bill['participants_uids'] as List?) ?? const [])
      .map((e) => e.toString())
      .toSet();
  if (groupId.isEmpty || hostId.isEmpty || memberId.isEmpty) return null;
  if (memberId == hostId || !uids.contains(memberId)) return null;

  final reader = BillReader(bill);
  final amountMinor = reader.outstandingMinorOf(participant);
  if (amountMinor <= 0) return null;

  return PaymentRecord(
    id: '',
    from: memberId,
    to: hostId,
    fromName: participant['name']?.toString(),
    amountMinor: amountMinor,
    currency: reader.currency,
    createdBy: createdBy,
    method: 'marked_paid',
    billId: billId,
    groupId: groupId,
  );
}

/// What to do with a share's linked settle-up payment when the host toggles
/// it paid or unpaid.
class SettlementLinkPlan {
  const SettlementLinkPlan({
    required this.reuseId,
    required this.recordNew,
    required this.deleteId,
  });

  /// Existing payment to keep linked (re-marking paid).
  final String? reuseId;

  /// A new payment must be recorded.
  final bool recordNew;

  /// Payment to delete (unmarking).
  final String? deleteId;
}

/// Re-marking a share paid reuses its existing payment instead of recording
/// a second one; unmarking deletes it.
SettlementLinkPlan planSettlementLink({
  required bool paid,
  required String? previousId,
  required bool hasSettlement,
}) {
  final prev = (previousId ?? '').isEmpty ? null : previousId;
  if (paid) {
    return SettlementLinkPlan(
      reuseId: prev,
      recordNew: prev == null && hasSettlement,
      deleteId: null,
    );
  }
  return SettlementLinkPlan(reuseId: null, recordNew: false, deleteId: prev);
}

/// The `settlementPaymentId` to store after the toggle. When unmarking and the
/// payment could not be deleted (older than the 24 h window) the link stays,
/// so re-marking reuses it.
String? nextSettlementPaymentId({
  required bool paid,
  required String? previousId,
  required String? recordedId,
  required bool deleteSucceeded,
}) {
  final prev = (previousId ?? '').isEmpty ? null : previousId;
  if (paid) return recordedId ?? prev;
  if (prev != null && !deleteSucceeded) return prev;
  return null;
}
