/// The bill document data contract (2.0), shared with the other clients.
///
/// Writers keep every legacy field 1.x clients read (`total`,
/// `currencyCode`, `charges.*Amount`, `items[].price/qty/assignedTo`,
/// `participants[].share` as doubles) and add:
///
/// | field                          | type              | notes |
/// |--------------------------------|-------------------|-------|
/// | `currency`                     | String (ISO 4217) | same as `currencyCode` |
/// | `totalMinor`                   | int               | == sum of `participants[].shareMinor` |
/// | `splitMethod`                  | String            | items, equal, exact, percent, shares |
/// | `groupId`                      | String?           | ledger / group id, optional |
/// | `participants[].shareMinor`    | int               | exact share in minor units |
/// | `participants[].breakdown`     | `Map<String,int>`| items, tax, service, tip, delivery, other, discount, adjustment (minor) |
/// | `participants[].splitInput`    | num?              | exact minor / percent / shares weight |
/// | `items[].priceMinor`           | int               | unit price in minor units |
/// | `items[].unitAssignments`      | `Map<String,int>?`| units per person when qty > 1 |
/// | `charges.minor`                | `Map<String,int>`| tax, service, tip, delivery, discount |
/// | `charges.otherCharges[].amountMinor` / `.splitMethod` | | `split_method` kept too |
/// | `history`                      | `List<Map>`      | {by, byName, at, change, args}, newest first, capped |
///
/// Readers ([BillReader]) prefer the minor fields and fall back to the
/// legacy doubles when they are missing (bills written by 1.x).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/participant_payment.dart';
import 'package:split_bill_app/domain/item_split.dart';
import 'package:split_bill_app/domain/money.dart';

export 'package:split_bill_app/bill_flow/participant_payment.dart';

/// The placeholder id older screens use for the signed-in host.
const String kCurrentUserPlaceholder = 'current_user';

/// Maximum entries kept in `history`.
const int kBillHistoryCap = 30;

String _str(Object? v) => v?.toString() ?? '';

int _int(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

/// Builds a [BillDraft] from the receipt map the scan / manual screens pass
/// around (`items[{name, price, qty}]`, `tax_amount`, `other_charges`...).
BillDraft draftFromReceipt({
  required Map<String, dynamic> receiptData,
  required List<String> participantIds,
  required String currency,
  Map<int, List<String>> itemAssignments = const {},
  Map<int, Map<String, int>> quantityAssignments = const {},
  double? tax,
  double? service,
  double? tip,
  double? discount,
  double? delivery,
}) {
  final code = normalizeCurrency(currency);
  final rawItems = (receiptData['items'] as List?) ?? const [];
  final items = <DraftItem>[
    for (final raw in rawItems)
      if (raw is Map)
        DraftItem(
          name: _str(raw['name']),
          unitPriceMinor: raw['priceMinor'] is num
              ? (raw['priceMinor'] as num).round()
              : minorFromAny(raw['price'], code),
          quantity: _int(raw['qty'] ?? raw['quantity'], 1),
        ),
  ];
  final rawOther =
      (receiptData['other_charges'] as List?) ??
      (receiptData['otherCharges'] as List?) ??
      const [];
  return BillDraft(
    currency: code,
    items: items,
    participantIds: participantIds,
    itemAssignments: itemAssignments,
    quantityAssignments: quantityAssignments,
    taxMinor: minorFromAny(tax ?? receiptData['tax_amount'], code),
    serviceMinor: minorFromAny(service ?? receiptData['service_charge'], code),
    tipMinor: minorFromAny(tip ?? receiptData['tip_amount'], code),
    discountMinor: minorFromAny(
      discount ?? receiptData['discount_amount'],
      code,
    ).abs(),
    deliveryMinor: minorFromAny(delivery ?? receiptData['delivery_fee'], code),
    otherCharges: [
      for (final c in rawOther)
        if (c is Map)
          DraftCharge(
            label: _str(c['label']),
            amountMinor: c['amountMinor'] is num
                ? (c['amountMinor'] as num).round()
                : minorFromAny(c['amount'], code),
            split: chargeSplitOf(c),
          ),
    ],
  );
}

/// Participant display info kept on the bill (legacy shape).
class BillParticipantInfo {
  const BillParticipantInfo({
    required this.id,
    required this.name,
    this.photoUrl,
    this.phoneNumber,
    this.isGuest = false,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final String? phoneNumber;
  final bool isGuest;

  factory BillParticipantInfo.fromMap(Map<dynamic, dynamic> m) =>
      BillParticipantInfo(
        id: _str(m['id']),
        name: _str(m['name']),
        photoUrl: m['photoUrl']?.toString(),
        phoneNumber: m['phoneNumber']?.toString(),
        isGuest: m['isGuest'] == true,
      );
}

/// Builds the bill fields for Firestore (create or full update).
///
/// [hostUid] replaces [kCurrentUserPlaceholder] ids. [previous] keeps
/// payment status (`isPaid`, `status`, extra keys) of existing participants
/// when editing.
Map<String, dynamic> buildBillFields({
  required BillComputation computation,
  required List<BillParticipantInfo> participants,
  required String hostUid,
  String? storeName,
  List<Map<String, dynamic>>? previousParticipants,
  String? groupId,
}) {
  final draft = computation.draft;
  final code = draft.currency;
  String real(String id) => id == kCurrentUserPlaceholder ? hostUid : id;
  double major(int minor) => fromMinorUnits(minor, code);

  final previousById = <String, Map<String, dynamic>>{
    for (final p in previousParticipants ?? const <Map<String, dynamic>>[])
      _str(p['id']): Map<String, dynamic>.from(p),
  };

  final items = <Map<String, dynamic>>[];
  for (var i = 0; i < draft.items.length; i++) {
    final item = draft.items[i];
    final state = draft.method == SplitMethod.items
        ? draft.assignmentOf(i)
        : null;
    final people = (state?.people ?? draft.participantIds).map(real).toList();
    items.add({
      'name': item.name,
      'price': major(item.unitPriceMinor),
      'priceMinor': item.unitPriceMinor,
      'qty': item.quantity,
      'assignedTo': people,
      if (state != null && state.unitAssignments.isNotEmpty)
        'unitAssignments': {
          for (final e in state.unitAssignments.entries) real(e.key): e.value,
        },
    });
  }

  final participantMaps = <Map<String, dynamic>>[];
  var totalMinor = 0;
  for (final info in participants) {
    final id = real(info.id);
    final person = computation.people[info.id];
    final share = person?.totalMinor ?? 0;
    totalMinor += share;
    final prev = previousById[id];
    final isHost = id == hostUid;
    // A paid share that grew (tip added, item changed) reopens: the person
    // owes the difference, `paidMinor` keeps what the host already received.
    final prevShare = prev == null
        ? 0
        : prev['shareMinor'] is num
        ? (prev['shareMinor'] as num).round()
        : minorFromAny(prev['share'], code);
    final wasPaid = !isHost && prev != null && isParticipantPaid(prev);
    final prevPaid = wasPaid ? paidMinorFromMap(prev, prevShare) : 0;
    final reopen = wasPaid && share > prevPaid;
    num? splitInput;
    switch (draft.method) {
      case SplitMethod.exact:
        splitInput = draft.exactAmounts[info.id];
      case SplitMethod.percent:
        splitInput = draft.percentages[info.id];
      case SplitMethod.shares:
        splitInput = draft.shares[info.id] ?? 1;
      case SplitMethod.items:
      case SplitMethod.equal:
        splitInput = null;
    }
    participantMaps.add({
      ...?prev,
      'id': id,
      'name': info.name,
      'photoUrl': info.photoUrl,
      'phoneNumber': info.phoneNumber,
      'isGuest': info.isGuest,
      'share': major(share),
      'shareMinor': share,
      'breakdown': person == null ? <String, int>{} : breakdownToMap(person),
      'splitInput': ?splitInput,
      'isPaid': isHost || (wasPaid ? !reopen : prev?['isPaid'] ?? false),
      'status': isHost
          ? 'PAID'
          : reopen
          ? 'PENDING'
          : prev?['status'] ?? 'PENDING',
      if (wasPaid) 'paidMinor': reopen ? prevPaid : share,
    });
  }

  return {
    'storeName': ?storeName,
    'currency': code,
    'currencyCode': code,
    'total': major(totalMinor),
    'totalMinor': totalMinor,
    'splitMethod': draft.method.wireName,
    'groupId': ?groupId,
    'charges': {
      'taxAmount': major(draft.taxMinor),
      'serviceCharge': major(draft.serviceMinor),
      'tipAmount': major(draft.tipMinor),
      'discountAmount': major(draft.discountMinor),
      'deliveryFeeAmount': major(draft.deliveryMinor),
      'otherCharges': [
        for (final c in draft.otherCharges)
          {
            'label': c.label,
            'amount': major(c.amountMinor),
            'amountMinor': c.amountMinor,
            'split_method': c.split == ChargeSplit.equal
                ? 'equal'
                : 'proportional',
            'splitMethod': c.split == ChargeSplit.equal
                ? 'equal'
                : 'proportional',
          },
      ],
      'minor': {
        'tax': draft.taxMinor,
        'service': draft.serviceMinor,
        'tip': draft.tipMinor,
        'delivery': draft.deliveryMinor,
        'discount': draft.discountMinor,
      },
    },
    'items': items,
    'participants': participantMaps,
    'participants_uids': [for (final p in participants) real(p.id)],
  };
}

Map<String, int> breakdownToMap(PersonBreakdown p) => {
  'items': p.itemsMinor,
  'tax': p.taxMinor,
  'service': p.serviceMinor,
  'tip': p.tipMinor,
  'delivery': p.deliveryMinor,
  'other': p.otherMinor,
  'discount': p.discountMinor,
  'adjustment':
      p.totalMinor -
      p.itemsMinor -
      p.taxMinor -
      p.serviceMinor -
      p.tipMinor -
      p.deliveryMinor -
      p.otherMinor +
      p.discountMinor,
};

/// Reads bill documents written by 1.x or 2.0 clients.
class BillReader {
  BillReader(this.data, {String fallbackCurrency = 'USD'})
    : currency = normalizeCurrency(
        _str(data['currency']).isNotEmpty
            ? _str(data['currency'])
            : _str(data['currencyCode']).isNotEmpty
            ? _str(data['currencyCode'])
            : fallbackCurrency,
      );

  final Map<String, dynamic> data;
  final String currency;

  SplitMethod get splitMethod => SplitMethod.parse(data['splitMethod']);

  String? get groupId {
    final g = data['groupId'];
    return g == null || _str(g).isEmpty ? null : _str(g);
  }

  List<Map<String, dynamic>> get participants => [
    for (final p in (data['participants'] as List?) ?? const [])
      if (p is Map) Map<String, dynamic>.from(p),
  ];

  List<Map<String, dynamic>> get items => [
    for (final p in (data['items'] as List?) ?? const [])
      if (p is Map) Map<String, dynamic>.from(p),
  ];

  Map<String, dynamic> get charges =>
      Map<String, dynamic>.from((data['charges'] as Map?) ?? const {});

  int shareMinorOf(Map<String, dynamic> participant) {
    final m = participant['shareMinor'];
    if (m is num) return m.round();
    return minorFromAny(participant['share'], currency);
  }

  int paidMinorOf(Map<String, dynamic> participant) =>
      paidMinorFromMap(participant, shareMinorOf(participant));

  int outstandingMinorOf(Map<String, dynamic> participant) =>
      outstandingMinorFromMap(participant, shareMinorOf(participant));

  Map<String, dynamic>? participant(String id) {
    for (final p in participants) {
      if (_str(p['id']) == id) return p;
    }
    return null;
  }

  int shareMinorFor(String id) {
    final p = participant(id);
    return p == null ? 0 : shareMinorOf(p);
  }

  int get totalMinor {
    final m = data['totalMinor'];
    if (m is num) return m.round();
    final fromShares = participants.fold(0, (s, p) => s + shareMinorOf(p));
    if (fromShares > 0) return fromShares;
    return minorFromAny(data['total'], currency);
  }

  int itemUnitPriceMinor(Map<String, dynamic> item) {
    final m = item['priceMinor'];
    if (m is num) return m.round();
    return minorFromAny(item['price'], currency);
  }

  int chargeMinor(String minorKey, String legacyKey) {
    final minor = charges['minor'];
    if (minor is Map && minor[minorKey] is num) {
      return (minor[minorKey] as num).round();
    }
    return minorFromAny(charges[legacyKey], currency).abs();
  }

  /// Rebuilds a draft so screens can recompute (edit, participant view).
  BillDraft toDraft() {
    final ids = [for (final p in participants) _str(p['id'])];
    final itemList = items;
    final assignments = <int, List<String>>{};
    final units = <int, Map<String, int>>{};
    for (var i = 0; i < itemList.length; i++) {
      final item = itemList[i];
      final ua = item['unitAssignments'];
      if (ua is Map && ua.isNotEmpty) {
        units[i] = {for (final e in ua.entries) _str(e.key): _int(e.value)};
      } else {
        assignments[i] = [
          for (final id in (item['assignedTo'] as List?) ?? const []) _str(id),
        ];
      }
    }
    final method = splitMethod;
    final splitInputs = <String, num>{
      for (final p in participants)
        if (p['splitInput'] is num) _str(p['id']): p['splitInput'] as num,
    };
    final other = (charges['otherCharges'] as List?) ?? const [];
    final draft = BillDraft(
      currency: currency,
      items: [
        for (final item in itemList)
          DraftItem(
            name: _str(item['name']),
            unitPriceMinor: itemUnitPriceMinor(item),
            quantity: _int(item['qty'], 1),
          ),
      ],
      participantIds: ids,
      itemAssignments: assignments,
      quantityAssignments: units,
      taxMinor: chargeMinor('tax', 'taxAmount'),
      serviceMinor: chargeMinor('service', 'serviceCharge'),
      tipMinor: chargeMinor('tip', 'tipAmount'),
      deliveryMinor: chargeMinor('delivery', 'deliveryFeeAmount'),
      discountMinor: chargeMinor('discount', 'discountAmount'),
      otherCharges: [
        for (final c in other)
          if (c is Map)
            DraftCharge(
              label: _str(c['label']),
              amountMinor: c['amountMinor'] is num
                  ? (c['amountMinor'] as num).round()
                  : minorFromAny(c['amount'], currency),
              split: chargeSplitOf(c),
            ),
      ],
      method: method,
      exactAmounts: method == SplitMethod.exact
          ? splitInputs.map((k, v) => MapEntry(k, v.round()))
          : const {},
      percentages: method == SplitMethod.percent ? splitInputs : const {},
      shares: method == SplitMethod.shares ? splitInputs : const {},
    );
    // If stored shares differ from the recomputed ones (manual overrides,
    // roulette, or legacy rounding), keep the stored numbers as overrides
    // so the bill keeps its saved shares and its total.
    final computed = computeBill(draft);
    final stored = {
      for (final p in participants) _str(p['id']): shareMinorOf(p),
    };
    final differs = stored.entries.any(
      (e) => computed.shareOf(e.key) != e.value,
    );
    final storedSum = stored.values.fold(0, (a, b) => a + b);
    if (differs && storedSum == draft.grandTotalMinor && stored.isNotEmpty) {
      return draft.copyWith(overrides: stored);
    }
    return draft;
  }

  /// Breakdown for [id]: recomputed from the items when possible, so the
  /// participant sees exactly what they had; falls back to the stored
  /// `breakdown` map / share.
  PersonBreakdown breakdownFor(String id) {
    final computed = computeBill(toDraft());
    final person = computed.people[id];
    final stored = shareMinorFor(id);
    if (person != null && person.totalMinor == stored) return person;
    final p = participant(id);
    final map = p?['breakdown'];
    if (map is Map && map.isNotEmpty) {
      int v(String k) => _int(map[k]);
      final lines = <BreakdownLine>[
        if (v('items') != 0)
          BreakdownLine(kind: BreakdownKind.item, amountMinor: v('items')),
        if (v('tax') != 0)
          BreakdownLine(kind: BreakdownKind.tax, amountMinor: v('tax')),
        if (v('service') != 0)
          BreakdownLine(kind: BreakdownKind.service, amountMinor: v('service')),
        if (v('tip') != 0)
          BreakdownLine(kind: BreakdownKind.tip, amountMinor: v('tip')),
        if (v('delivery') != 0)
          BreakdownLine(
            kind: BreakdownKind.delivery,
            amountMinor: v('delivery'),
          ),
        if (v('other') != 0)
          BreakdownLine(kind: BreakdownKind.other, amountMinor: v('other')),
        if (v('discount') != 0)
          BreakdownLine(
            kind: BreakdownKind.discount,
            amountMinor: -v('discount'),
          ),
      ];
      final sum = lines.fold(0, (s, l) => s + l.amountMinor);
      if (sum != stored) {
        lines.add(
          BreakdownLine(
            kind: BreakdownKind.adjustment,
            amountMinor: stored - sum,
          ),
        );
      }
      return PersonBreakdown(id: id, lines: lines);
    }
    if (person != null) {
      return PersonBreakdown(
        id: id,
        lines: [
          ...person.lines,
          if (stored != person.totalMinor)
            BreakdownLine(
              kind: BreakdownKind.adjustment,
              amountMinor: stored - person.totalMinor,
            ),
        ],
      );
    }
    return PersonBreakdown(
      id: id,
      lines: [
        if (stored != 0)
          BreakdownLine(kind: BreakdownKind.methodShare, amountMinor: stored),
      ],
    );
  }

  List<BillHistoryEntry> get history => [
    for (final h in (data['history'] as List?) ?? const [])
      if (h is Map) BillHistoryEntry.fromMap(Map<String, dynamic>.from(h)),
  ];
}

/// One `history` entry: who changed what, when.
class BillHistoryEntry {
  const BillHistoryEntry({
    required this.by,
    required this.at,
    required this.change,
    this.byName,
    this.args = const {},
  });

  /// uid of the author.
  final String by;
  final String? byName;
  final DateTime at;

  /// A change code: created, edited, renamed, item_price, item_added,
  /// item_removed, person_added, person_removed, charges, split_method,
  /// currency, marked_paid.
  final String change;
  final Map<String, dynamic> args;

  Map<String, dynamic> toMap() => {
    'by': by,
    'byName': ?byName,
    'at': Timestamp.fromDate(at),
    'change': change,
    if (args.isNotEmpty) 'args': args,
  };

  factory BillHistoryEntry.fromMap(Map<String, dynamic> m) {
    final at = m['at'];
    DateTime when;
    if (at is Timestamp) {
      when = at.toDate();
    } else if (at is int) {
      when = DateTime.fromMillisecondsSinceEpoch(at);
    } else if (at is String) {
      when = DateTime.tryParse(at) ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      when = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return BillHistoryEntry(
      by: _str(m['by']),
      byName: m['byName']?.toString(),
      at: when,
      change: _str(m['change']),
      args: Map<String, dynamic>.from((m['args'] as Map?) ?? const {}),
    );
  }
}

/// New history list: [entries] first (newest first), then [existing],
/// capped at [cap].
List<Map<String, dynamic>> appendHistory(
  List<dynamic>? existing,
  List<BillHistoryEntry> entries, {
  int cap = kBillHistoryCap,
}) {
  final old = [
    for (final h in existing ?? const [])
      if (h is Map) Map<String, dynamic>.from(h),
  ];
  final all = [for (final e in entries) e.toMap(), ...old];
  return all.length > cap ? all.sublist(0, cap) : all;
}

/// Describes what changed between two drafts as history entries.
List<BillHistoryEntry> diffDrafts({
  required BillDraft before,
  required BillDraft after,
  required String by,
  String? byName,
  required DateTime at,
  String? nameBefore,
  String? nameAfter,
  Map<String, String> participantNames = const {},
}) {
  final out = <BillHistoryEntry>[];
  BillHistoryEntry e(String change, [Map<String, dynamic> args = const {}]) =>
      BillHistoryEntry(
        by: by,
        byName: byName,
        at: at,
        change: change,
        args: args,
      );

  if (nameBefore != null && nameAfter != null && nameBefore != nameAfter) {
    out.add(e('renamed', {'from': nameBefore, 'to': nameAfter}));
  }
  if (before.currency != after.currency) {
    out.add(e('currency', {'from': before.currency, 'to': after.currency}));
  }
  final beforeByName = {for (final i in before.items) i.name: i};
  final afterByName = {for (final i in after.items) i.name: i};
  for (final item in after.items) {
    final old = beforeByName[item.name];
    if (old == null) {
      out.add(e('item_added', {'item': item.name, 'to': item.lineTotalMinor}));
    } else if (old.unitPriceMinor != item.unitPriceMinor ||
        old.quantity != item.quantity) {
      out.add(
        e('item_price', {
          'item': item.name,
          'from': old.lineTotalMinor,
          'to': item.lineTotalMinor,
        }),
      );
    }
  }
  for (final item in before.items) {
    if (!afterByName.containsKey(item.name)) {
      out.add(e('item_removed', {'item': item.name}));
    }
  }
  final beforeIds = before.participantIds.toSet();
  final afterIds = after.participantIds.toSet();
  for (final id in afterIds.difference(beforeIds)) {
    out.add(e('person_added', {'name': participantNames[id] ?? id}));
  }
  for (final id in beforeIds.difference(afterIds)) {
    out.add(e('person_removed', {'name': participantNames[id] ?? id}));
  }
  if (before.taxMinor != after.taxMinor ||
      before.serviceMinor != after.serviceMinor ||
      before.tipMinor != after.tipMinor ||
      before.deliveryMinor != after.deliveryMinor ||
      before.discountMinor != after.discountMinor ||
      before.otherChargesMinor != after.otherChargesMinor) {
    out.add(
      e('charges', {
        'from': before.grandTotalMinor - before.itemsSubtotalMinor,
        'to': after.grandTotalMinor - after.itemsSubtotalMinor,
      }),
    );
  }
  if (before.method != after.method) {
    out.add(
      e('split_method', {
        'from': before.method.wireName,
        'to': after.method.wireName,
      }),
    );
  }
  if (out.isEmpty) out.add(e('edited'));
  return out;
}
