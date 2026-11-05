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
  final amountMinor = reader.shareMinorOf(participant);
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
