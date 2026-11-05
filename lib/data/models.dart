/// Read models for the ledger screens (groups, bills, payments, IOUs).
///
/// Firestore shapes (validated by firestore.rules):
///
/// * `groups/{id}`: legacy `name, createdBy, createdAt, members, memberIds`
///   plus `type` (trip/home/couple/other), `currency`, `budgetMinor`,
///   `startDate`, `endDate`, `simplifyDebts`, `archived`, `updatedAt`.
/// * `groups/{id}/payments/{pid}` and top-level `payments/{pid}`:
///   `{kind, from, to, fromName, toName, amountMinor, currency, method,
///   proofUrl?, note?, billId?, groupId?, participants_uids, createdBy,
///   createdAt}`. `kind` is `payment` (from paid to) or `iou` (from owes to,
///   no bill needed; top-level only).
/// * `bills/{id}`: legacy `participants[].share` doubles and `total`, plus
///   (from the bill flow) `currency`, `participants[].shareMinor`,
///   `totalMinor`, `splitMethod`, `groupId`. Readers fall back to the doubles.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/domain/settlement.dart';

/// Converts Firestore timestamps, DateTimes and epoch millis.
DateTime? parseDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num && v == v.roundToDouble()) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String? _asString(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// Reads a minor amount: [minorKey] when present, else converts the legacy
/// double at [legacyKey].
int readMinor(
  Map<String, dynamic> data,
  String minorKey,
  String legacyKey,
  String currency,
) {
  final minor = _asInt(data[minorKey]);
  if (minor != null) return minor;
  final legacy = _asDouble(data[legacyKey]);
  if (legacy == null || legacy.isNaN || legacy.isInfinite) return 0;
  return toMinorUnits(legacy, currency);
}

enum GroupType {
  trip,
  home,
  couple,
  other;

  static GroupType parse(Object? v) => GroupType.values.firstWhere(
    (t) => t.name == v,
    orElse: () => GroupType.other,
  );

  String get labelKey => 'group_type_$name';
}

class GroupMember {
  const GroupMember({
    required this.id,
    required this.name,
    this.photoUrl,
    this.isGuest = false,
    this.phoneNumber,
  });

  factory GroupMember.fromMap(Map<dynamic, dynamic> m) => GroupMember(
    id: m['id']?.toString() ?? '',
    name: _asString(m['name']) ?? '',
    photoUrl: _asString(m['photoUrl']),
    isGuest: m['isGuest'] == true,
    phoneNumber: _asString(m['phoneNumber']),
  );

  final String id;
  final String name;
  final String? photoUrl;
  final bool isGuest;
  final String? phoneNumber;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'photoUrl': photoUrl,
    'phoneNumber': phoneNumber,
    'isGuest': isGuest,
  };
}

/// A group, trip or household ledger.
class LedgerGroup {
  const LedgerGroup({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.members,
    this.type = GroupType.other,
    this.currency,
    this.budgetMinor,
    this.startDate,
    this.endDate,
    this.simplifyDebts = true,
    this.archived = false,
    this.createdAt,
  });

  factory LedgerGroup.fromMap(String id, Map<String, dynamic> data) {
    final rawMembers = data['members'];
    final members = <GroupMember>[
      if (rawMembers is List)
        for (final m in rawMembers)
          if (m is Map) GroupMember.fromMap(m),
    ];
    // Old docs may carry ids in memberIds that are missing from members.
    final ids = data['memberIds'];
    if (ids is List) {
      for (final id in ids) {
        final s = id.toString();
        if (!members.any((m) => m.id == s)) {
          members.add(GroupMember(id: s, name: ''));
        }
      }
    }
    final currency = _asString(data['currency']);
    return LedgerGroup(
      id: id,
      name: _asString(data['name']) ?? '',
      createdBy: data['createdBy']?.toString() ?? '',
      members: members.where((m) => m.id.isNotEmpty).toList(),
      type: GroupType.parse(data['type']),
      currency: currency == null ? null : normalizeCurrency(currency),
      budgetMinor: _asInt(data['budgetMinor']),
      startDate: parseDate(data['startDate']),
      endDate: parseDate(data['endDate']),
      simplifyDebts: data['simplifyDebts'] != false,
      archived: data['archived'] == true,
      createdAt: parseDate(data['createdAt']),
    );
  }

  final String id;
  final String name;
  final String createdBy;
  final List<GroupMember> members;
  final GroupType type;

  /// Main currency; null on legacy groups (use the user's default).
  final String? currency;
  final int? budgetMinor;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool simplifyDebts;
  final bool archived;
  final DateTime? createdAt;

  List<String> get memberIds => members.map((m) => m.id).toList();

  GroupMember? member(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }
}

/// One participant's share of a bill.
class BillShare {
  const BillShare({
    required this.id,
    required this.name,
    required this.shareMinor,
    required this.status,
    this.photoUrl,
  });

  final String id;
  final String name;
  final int shareMinor;

  /// PAID, PENDING or REVIEW (paid, waiting for the host to confirm).
  final String status;
  final String? photoUrl;

  bool get isPaid => status == 'PAID';
}

/// A bill as the ledger sees it: the host paid, participants owe shares.
class BillRecord {
  const BillRecord({
    required this.id,
    required this.hostId,
    required this.title,
    required this.currency,
    required this.totalMinor,
    required this.participants,
    this.hostName,
    this.date,
    this.groupId,
    this.category,
    this.splitMethod,
    this.status,
  });

  /// [fallbackCurrency] is used when neither `currency` nor the legacy
  /// `currencyCode` is stored.
  factory BillRecord.fromMap(
    String id,
    Map<String, dynamic> data, {
    String fallbackCurrency = 'USD',
  }) {
    final currency = normalizeCurrency(
      _asString(data['currency']) ??
          _asString(data['currencyCode']) ??
          fallbackCurrency,
    );
    final parts = <BillShare>[];
    final raw = data['participants'];
    if (raw is List) {
      for (final p in raw) {
        if (p is! Map) continue;
        final m = Map<String, dynamic>.from(p);
        final pid = _asString(m['id']) ?? _asString(m['uid']);
        if (pid == null) continue;
        final isPaid = m['isPaid'] == true;
        parts.add(
          BillShare(
            id: pid,
            name: _asString(m['name']) ?? '',
            photoUrl: _asString(m['photoUrl']),
            shareMinor: readMinor(m, 'shareMinor', 'share', currency),
            status: _asString(m['status']) ?? (isPaid ? 'PAID' : 'PENDING'),
          ),
        );
      }
    }
    final sum = parts.fold<int>(0, (a, p) => a + p.shareMinor);
    final total = data.containsKey('totalMinor') || data.containsKey('total')
        ? readMinor(data, 'totalMinor', 'total', currency)
        : sum;
    return BillRecord(
      id: id,
      hostId: data['hostId']?.toString() ?? '',
      hostName: _asString(data['hostName']),
      title: _asString(data['storeName']) ?? _asString(data['title']) ?? '',
      currency: currency,
      totalMinor: total,
      participants: parts,
      date: parseDate(data['date']),
      groupId: _asString(data['groupId']),
      category: _asString(data['category']),
      splitMethod: _asString(data['splitMethod']),
      status: _asString(data['status']),
    );
  }

  final String id;
  final String hostId;
  final String? hostName;
  final String title;
  final String currency;
  final int totalMinor;
  final List<BillShare> participants;
  final DateTime? date;
  final String? groupId;
  final String? category;
  final String? splitMethod;
  final String? status;

  /// Scanned but never split ("Later"): not part of any balance.
  bool get isDraft => status == 'UNATTEMPTED';

  /// Unpaid shares of people other than the host.
  Map<String, int> get unpaidShares => {
    for (final p in participants)
      if (p.id != hostId && !p.isPaid && p.shareMinor > 0) p.id: p.shareMinor,
  };

  /// Still has someone who owes the host.
  bool get isOpen => !isDraft && unpaidShares.isNotEmpty;

  BillShare? share(String personId) {
    for (final p in participants) {
      if (p.id == personId) return p;
    }
    return null;
  }

  /// What [personId] owes on this bill (0 for the host or when paid).
  int owedBy(String personId) => unpaidShares[personId] ?? 0;

  /// What every non-host participant owes, whatever their status.
  Map<String, int> get allShares => {
    for (final p in participants)
      if (p.id != hostId && p.shareMinor > 0) p.id: p.shareMinor,
  };

  /// The ledger expense for what is still unpaid, or null when settled.
  ///
  /// With [ignorePaidStatus] every share counts in full: group ledgers use
  /// this because settle-up payments (not the bill's PAID flag) record what
  /// was paid, and subtracting both would count the same money twice.
  Expense? toExpense({bool ignorePaidStatus = false}) {
    final shares = ignorePaidStatus ? allShares : unpaidShares;
    if (isDraft || shares.isEmpty || hostId.isEmpty) return null;
    return Expense.singlePayer(
      id: 'bill:$id',
      currency: currency,
      payer: hostId,
      shares: shares,
    );
  }

  String nameOf(String personId) {
    if (personId == hostId && hostName != null) return hostName!;
    return share(personId)?.name ?? '';
  }
}

enum PaymentKind {
  /// [PaymentRecord.from] paid [PaymentRecord.to].
  payment,

  /// [PaymentRecord.from] owes [PaymentRecord.to] (Quick IOU).
  iou;

  static PaymentKind parse(Object? v) =>
      v == 'iou' ? PaymentKind.iou : PaymentKind.payment;
}

/// A settlement payment or a Quick IOU.
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.from,
    required this.to,
    required this.amountMinor,
    required this.currency,
    required this.createdBy,
    this.kind = PaymentKind.payment,
    this.fromName,
    this.toName,
    this.method = 'cash',
    this.proofUrl,
    this.note,
    this.billId,
    this.groupId,
    this.createdAt,
  });

  factory PaymentRecord.fromMap(String id, Map<String, dynamic> data) {
    final currency = normalizeCurrency(_asString(data['currency']) ?? 'USD');
    return PaymentRecord(
      id: id,
      kind: PaymentKind.parse(data['kind']),
      from: data['from']?.toString() ?? '',
      to: data['to']?.toString() ?? '',
      fromName: _asString(data['fromName']),
      toName: _asString(data['toName']),
      amountMinor: _asInt(data['amountMinor']) ?? 0,
      currency: currency,
      method: _asString(data['method']) ?? 'cash',
      proofUrl: _asString(data['proofUrl']),
      note: _asString(data['note']),
      billId: _asString(data['billId']),
      groupId: _asString(data['groupId']),
      createdBy: data['createdBy']?.toString() ?? '',
      createdAt: parseDate(data['createdAt']),
    );
  }

  final String id;
  final PaymentKind kind;
  final String from;
  final String to;
  final String? fromName;
  final String? toName;
  final int amountMinor;
  final String currency;
  final String method;
  final String? proofUrl;
  final String? note;
  final String? billId;
  final String? groupId;
  final String createdBy;
  final DateTime? createdAt;

  bool get isValid => amountMinor > 0 && from.isNotEmpty && from != to;

  /// Firestore map for a new doc. [participantUids] are the real accounts
  /// among [from] and [to] (guests have no account).
  Map<String, dynamic> toCreateMap({
    required List<String> participantUids,
    Object? createdAtValue,
  }) => {
    'kind': kind.name,
    'from': from,
    'to': to,
    if (fromName != null) 'fromName': fromName,
    if (toName != null) 'toName': toName,
    'amountMinor': amountMinor,
    'currency': normalizeCurrency(currency),
    'method': method,
    if (proofUrl != null) 'proofUrl': proofUrl,
    if (note != null) 'note': note,
    if (billId != null) 'billId': billId,
    if (groupId != null) 'groupId': groupId,
    'participants_uids': participantUids,
    'createdBy': createdBy,
    'createdAt': createdAtValue ?? FieldValue.serverTimestamp(),
  };

  /// A Quick IOU is an expense the creditor "paid" for the debtor.
  Expense? toExpense() => kind == PaymentKind.iou && isValid
      ? Expense.singlePayer(
          id: 'iou:$id',
          currency: currency,
          payer: to,
          shares: {from: amountMinor},
        )
      : null;

  SettlementPayment? toSettlement() => kind == PaymentKind.payment && isValid
      ? SettlementPayment(
          id: 'pay:$id',
          currency: normalizeCurrency(currency),
          from: from,
          to: to,
          amount: amountMinor,
        )
      : null;
}
