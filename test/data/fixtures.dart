import 'package:split_bill_app/data/models.dart';

BillRecord bill(
  String id,
  String host,
  Map<String, int> shares, {
  Set<String> paid = const {},
  String currency = 'USD',
  String? groupId,
  DateTime? date,
  String? status,
}) => BillRecord(
  id: id,
  hostId: host,
  title: id,
  currency: currency,
  totalMinor: shares.values.fold(0, (a, b) => a + b),
  groupId: groupId,
  date: date ?? DateTime(2026, 11, 1),
  status: status,
  participants: [
    for (final e in shares.entries)
      BillShare(
        id: e.key,
        name: e.key.toUpperCase(),
        shareMinor: e.value,
        status: e.key == host || paid.contains(e.key) ? 'PAID' : 'PENDING',
      ),
  ],
);

PaymentRecord pay(
  String id,
  String from,
  String to,
  int amount, {
  String currency = 'USD',
  PaymentKind kind = PaymentKind.payment,
  String? groupId,
}) => PaymentRecord(
  id: id,
  from: from,
  to: to,
  amountMinor: amount,
  currency: currency,
  createdBy: from,
  kind: kind,
  groupId: groupId,
);

LedgerGroup ledgerGroup(String id, List<String> members, {bool simplify = true}) =>
    LedgerGroup(
      id: id,
      name: 'Group $id',
      createdBy: members.first,
      simplifyDebts: simplify,
      members: [for (final m in members) GroupMember(id: m, name: m.toUpperCase())],
    );
