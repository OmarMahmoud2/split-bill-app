/// Guest web view of a shared bill: link parsing, a read-only snapshot of the
/// bill document and the payer's breakdown, all in integer minor units.
///
/// Pure Dart (no Flutter, no Firebase) so it is unit-testable.
///
/// Data contract (bills/{id}): legacy fields (`storeName`, `hostId`,
/// `hostName`, `date`, `currencyCode`, `total`, `charges`, `items`,
/// `participants[] {id, name, share, status, isPaid, phoneNumber}`,
/// `paymentMethods {name: value}`), plus the optional 2.0 fields `currency`,
/// `totalMinor`, `participants[].shareMinor`, `splitMethod`, `groupId` and
/// `expiresAt`. Minor fields win when present; legacy doubles are converted
/// with [toMinorUnits].
library;

import '../../domain/item_split.dart';
import '../../domain/money.dart';
import '../../domain/split_methods.dart';

// ---------------------------------------------------------------------------
// Links
// ---------------------------------------------------------------------------

/// A bill link: `/bill/<id>`, `/b/<id>` or `?billId=<id>`, optionally
/// personal with `?p=<participantId>` (legacy `?uid=`).
class GuestLink {
  const GuestLink({required this.billId, this.participantId});

  final String billId;
  final String? participantId;

  @override
  bool operator ==(Object other) =>
      other is GuestLink &&
      other.billId == billId &&
      other.participantId == participantId;

  @override
  int get hashCode => Object.hash(billId, participantId);

  @override
  String toString() => 'GuestLink($billId, $participantId)';
}

String? _nonEmpty(String? value) {
  final v = value?.trim();
  return (v == null || v.isEmpty) ? null : v;
}

/// Reads a guest bill link, or null when [uri] is not one.
GuestLink? parseGuestLink(Uri uri) {
  var billId = _nonEmpty(uri.queryParameters['billId']);
  if (billId == null) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    for (var i = 0; i < segments.length - 1; i++) {
      if (segments[i] == 'bill' || segments[i] == 'b') {
        billId = _nonEmpty(segments[i + 1]);
        break;
      }
    }
  }
  if (billId == null) return null;
  final participantId =
      _nonEmpty(uri.queryParameters['p']) ??
      _nonEmpty(uri.queryParameters['uid']);
  return GuestLink(billId: billId, participantId: participantId);
}

// ---------------------------------------------------------------------------
// Bill snapshot
// ---------------------------------------------------------------------------

enum GuestPayStatus { pending, review, paid }

GuestPayStatus _statusOf(Map<String, dynamic> p) {
  final status = p['status']?.toString().toUpperCase();
  if (status == null || status.isEmpty) {
    return p['isPaid'] == true ? GuestPayStatus.paid : GuestPayStatus.pending;
  }
  return switch (status) {
    'PAID' => GuestPayStatus.paid,
    'REVIEW' => GuestPayStatus.review,
    _ => GuestPayStatus.pending,
  };
}

int? _minorOf(Object? minor, Object? legacy, String currency) {
  if (minor is int) return minor;
  if (minor is num) return minor.round();
  if (legacy is num) {
    try {
      return toMinorUnits(legacy.toDouble(), currency);
    } on Object {
      return null;
    }
  }
  return null;
}

int _chargeMinor(Map<String, dynamic>? charges, String key, String currency) =>
    _minorOf(null, charges?[key], currency)?.abs() ?? 0;

DateTime? _dateOf(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  // Firestore Timestamp without importing cloud_firestore.
  try {
    final dynamic dyn = value;
    final converted = dyn.toDate();
    if (converted is DateTime) return converted;
  } on Object {
    // not a Timestamp
  }
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

class GuestParticipant {
  const GuestParticipant({
    required this.id,
    required this.name,
    required this.status,
    this.shareMinor,
    this.phoneNumber,
    this.hasProof = false,
  });

  final String id;
  final String name;
  final GuestPayStatus status;

  /// Stored share in minor units (`shareMinor`, else legacy `share`).
  final int? shareMinor;
  final String? phoneNumber;
  final bool hasProof;

  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters1.toUpperCase();
  }
}

extension on String {
  /// First user-perceived character (good enough for initials; handles
  /// surrogate pairs).
  String get characters1 {
    final runes = this.runes;
    return runes.isEmpty ? '' : String.fromCharCode(runes.first);
  }
}

class GuestReceiptItem {
  const GuestReceiptItem({
    required this.name,
    required this.unitPriceMinor,
    required this.quantity,
    required this.assignees,
  });

  final String name;
  final int unitPriceMinor;
  final int quantity;
  final List<String> assignees;

  int get lineTotal => unitPriceMinor * quantity;
}

/// A read-only snapshot of `bills/{id}` for the guest page.
class GuestBill {
  const GuestBill({
    required this.id,
    required this.storeName,
    required this.hostId,
    required this.hostName,
    required this.currency,
    required this.participants,
    required this.items,
    required this.charges,
    required this.otherChargeLabels,
    required this.paymentMethods,
    this.date,
    this.totalMinor,
    this.expiresAt,
    this.billStatus,
  });

  factory GuestBill.fromMap(String id, Map<String, dynamic> data) {
    final currency = normalizeCurrency(
      (data['currency'] ?? data['currencyCode'] ?? data['currency_code'] ?? 'USD')
          .toString(),
    );
    final participants = <GuestParticipant>[];
    for (final raw in (data['participants'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final pid = p['id']?.toString();
      if (pid == null || pid.isEmpty) continue;
      participants.add(
        GuestParticipant(
          id: pid,
          name: (p['name'] ?? '').toString(),
          status: _statusOf(p),
          shareMinor: _minorOf(p['shareMinor'], p['share'], currency),
          phoneNumber: _nonEmpty(p['phoneNumber']?.toString()),
          hasProof: (p['paymentProof']?.toString().isNotEmpty ?? false),
        ),
      );
    }

    final items = <GuestReceiptItem>[];
    for (final raw in (data['items'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final price = raw['price'];
      if (price is! num) continue;
      final qty = (raw['qty'] as num?)?.toInt() ?? 1;
      int unit;
      try {
        unit = toMinorUnits(price.toDouble(), currency);
      } on Object {
        continue;
      }
      items.add(
        GuestReceiptItem(
          name: (raw['name'] ?? '').toString(),
          unitPriceMinor: unit,
          quantity: qty < 1 ? 1 : qty,
          assignees: [
            for (final a in (raw['assignedTo'] as List?) ?? const [])
              a.toString(),
          ],
        ),
      );
    }

    final chargesMap = data['charges'] is Map
        ? Map<String, dynamic>.from(data['charges'] as Map)
        : null;
    final others = <OtherCharge>[];
    final otherLabels = <String>[];
    for (final raw in (chargesMap?['otherCharges'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final amount = _minorOf(null, raw['amount'], currency)?.abs() ?? 0;
      if (amount == 0) continue;
      final split = (raw['splitMethod'] ?? raw['split_method']) == 'equal'
          ? ChargeSplit.equal
          : ChargeSplit.proportional;
      final label = (raw['label'] ?? '').toString();
      others.add(OtherCharge(label: label, amount: amount, split: split));
      otherLabels.add(label);
    }

    final methodsRaw = data['paymentMethods'];
    final methods = <String, String>{};
    if (methodsRaw is Map) {
      methodsRaw.forEach((k, v) {
        final value = v?.toString().trim() ?? '';
        if (value.isNotEmpty) methods[k.toString()] = value;
      });
    }

    return GuestBill(
      id: id,
      storeName: (data['storeName'] ?? '').toString().trim(),
      hostId: (data['hostId'] ?? '').toString(),
      hostName: (data['hostName'] ?? '').toString().trim(),
      currency: currency,
      participants: participants,
      items: items,
      charges: BillCharges(
        tax: _chargeMinor(chargesMap, 'taxAmount', currency),
        serviceCharge: _chargeMinor(chargesMap, 'serviceCharge', currency),
        tip: _chargeMinor(chargesMap, 'tipAmount', currency),
        deliveryFee: _chargeMinor(chargesMap, 'deliveryFeeAmount', currency),
        discount: _chargeMinor(chargesMap, 'discountAmount', currency),
        otherCharges: others,
      ),
      otherChargeLabels: otherLabels,
      paymentMethods: methods,
      date: _dateOf(data['date']),
      totalMinor: _minorOf(data['totalMinor'], data['total'], currency),
      expiresAt: _dateOf(data['expiresAt']),
      billStatus: data['status']?.toString().toUpperCase(),
    );
  }

  final String id;
  final String storeName;
  final String hostId;
  final String hostName;
  final String currency;
  final List<GuestParticipant> participants;
  final List<GuestReceiptItem> items;
  final BillCharges charges;
  final List<String> otherChargeLabels;

  /// `{name: value}` as copied onto the bill at creation.
  final Map<String, String> paymentMethods;
  final DateTime? date;
  final int? totalMinor;
  final DateTime? expiresAt;
  final String? billStatus;

  /// Everyone except the host, i.e. the people who can open the link.
  List<GuestParticipant> get guests =>
      participants.where((p) => p.id != hostId).toList();

  GuestParticipant? participant(String? id) {
    if (id == null) return null;
    for (final p in participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The host's phone, when the host is also listed as a participant.
  String? get hostPhone => participant(hostId)?.phoneNumber;

  /// Everyone (but the host) has paid, or the host closed the bill.
  bool get isSettled {
    if (billStatus == 'SETTLED' || billStatus == 'CLOSED') return true;
    final g = guests;
    return g.isNotEmpty && g.every((p) => p.status == GuestPayStatus.paid);
  }

  bool isExpired(DateTime now) {
    if (billStatus == 'EXPIRED' || billStatus == 'ARCHIVED') return true;
    final e = expiresAt;
    return e != null && now.isAfter(e);
  }

  /// Sum of the stored shares, or [totalMinor].
  int get displayTotalMinor =>
      totalMinor ??
      participants.fold<int>(0, (sum, p) => sum + (p.shareMinor ?? 0));

  /// The payer's breakdown; see [GuestBreakdown].
  GuestBreakdown breakdownFor(String participantId) =>
      GuestBreakdown.compute(this, participantId);
}

// ---------------------------------------------------------------------------
// Breakdown
// ---------------------------------------------------------------------------

enum GuestLineKind {
  item,
  tax,
  service,
  tip,
  delivery,
  other,
  discount,
  adjustment,
  share,
}

class GuestLine {
  const GuestLine({
    required this.kind,
    required this.amountMinor,
    this.label = '',
    this.sharedWith = 1,
    this.ratePercent,
    this.baseMinor,
  });

  final GuestLineKind kind;

  /// Signed: discounts are negative.
  final int amountMinor;

  /// Item name or custom charge label.
  final String label;

  /// People sharing an item line (1 = not shared).
  final int sharedWith;

  /// Tax/service rate on the items subtotal ("14", "12.5"), when it reads
  /// as a clean rate.
  final String? ratePercent;

  /// The payer's items subtotal the rate applies to.
  final int? baseMinor;

  /// Charges and adjustments render muted under the items.
  bool get isMuted => kind != GuestLineKind.item && kind != GuestLineKind.share;
}

/// What one guest owes and why.
///
/// When the bill has items, lines come from [splitItemizedBill] (the same
/// maths the app uses). [totalMinor] is the stored share when there is one
/// (it is what the host sees); if the computed lines disagree with it, an
/// [GuestLineKind.adjustment] line makes the rows add up. Without items (or
/// when the items don't split cleanly) there is a single share line.
class GuestBreakdown {
  const GuestBreakdown({
    required this.lines,
    required this.totalMinor,
    required this.currency,
    required this.itemized,
  });

  final List<GuestLine> lines;
  final int totalMinor;
  final String currency;

  /// True when [lines] break the share down by item.
  final bool itemized;

  static GuestBreakdown compute(GuestBill bill, String participantId) {
    final me = bill.participant(participantId);
    final stored = me?.shareMinor;
    final fallback = GuestBreakdown(
      lines: [
        GuestLine(kind: GuestLineKind.share, amountMinor: stored ?? 0),
      ],
      totalMinor: stored ?? 0,
      currency: bill.currency,
      itemized: false,
    );
    if (me == null) return fallback;

    final ids = bill.participants.map((p) => p.id).toList();
    final items = [
      for (final item in bill.items)
        if (item.assignees.isNotEmpty)
          BillItem(
            name: item.name,
            unitPrice: item.unitPriceMinor,
            quantity: item.quantity,
            assignees: item.assignees,
          ),
    ];
    if (items.isEmpty) return fallback;

    ItemizedSplit split;
    try {
      split = splitItemizedBill(
        participants: ids,
        items: items,
        charges: bill.charges,
      );
    } on Object {
      return fallback;
    }
    final share = split.shares[participantId];
    if (share == null || share.items == 0) return fallback;

    final lines = <GuestLine>[];
    for (final item in items) {
      if (!item.assignees.contains(participantId)) continue;
      final part = splitEqually(item.lineTotal, item.assignees)[participantId]!;
      lines.add(
        GuestLine(
          kind: GuestLineKind.item,
          label: item.name,
          amountMinor: part,
          sharedWith: item.assignees.length,
        ),
      );
    }

    String? rate(int charge) {
      if (split.itemsSubtotal <= 0 || charge <= 0) return null;
      final pct = charge * 100 / split.itemsSubtotal;
      final oneDecimal = (pct * 10).round() / 10;
      // Only show a rate that reproduces the charge (a typed percentage),
      // not 13.8472% from a typed amount.
      final reproduced = (split.itemsSubtotal * oneDecimal / 100).round();
      if ((reproduced - charge).abs() > 1) return null;
      return oneDecimal == oneDecimal.roundToDouble()
          ? oneDecimal.toStringAsFixed(0)
          : oneDecimal.toStringAsFixed(1);
    }

    void add(GuestLineKind kind, int amount, {String label = '', String? r}) {
      if (amount == 0) return;
      lines.add(
        GuestLine(
          kind: kind,
          amountMinor: amount,
          label: label,
          ratePercent: r,
          baseMinor: r == null ? null : share.items,
        ),
      );
    }

    add(GuestLineKind.tax, share.tax, r: rate(bill.charges.tax));
    add(
      GuestLineKind.service,
      share.serviceCharge,
      r: rate(bill.charges.serviceCharge),
    );
    add(GuestLineKind.tip, share.tip);
    add(GuestLineKind.delivery, share.deliveryFee);
    add(
      GuestLineKind.other,
      share.otherCharges,
      label: bill.otherChargeLabels.length == 1
          ? bill.otherChargeLabels.first
          : '',
    );
    add(GuestLineKind.discount, -share.discount);

    final total = stored ?? share.total;
    add(GuestLineKind.adjustment, total - share.total);

    return GuestBreakdown(
      lines: lines,
      totalMinor: total,
      currency: bill.currency,
      itemized: true,
    );
  }
}
