/// State and rules of the edit-bill flow, without Firebase or widgets.
///
/// [EditBillController] holds the bill being edited as a [BillDraft] plus
/// the name, date and participant maps, recomputes it with [computeBill],
/// explains problems with [describeIssue], and builds the Firestore update
/// (2.0 data contract + `history`) with [EditBillController.buildUpdate].
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/domain/money.dart';
import 'package:split_bill_app/utils/money_format.dart';

// ------------------------------------------------------------ draft operations

Map<int, V> _reindexAfterRemoval<V>(Map<int, V> map, int removed) => {
  for (final e in map.entries)
    if (e.key != removed) (e.key > removed ? e.key - 1 : e.key): e.value,
};

/// Appends [item] (left unassigned so the user picks who had it).
BillDraft draftAddItem(BillDraft d, DraftItem item) =>
    d.copyWith(items: [...d.items, item]);

/// Replaces item [index]. When the quantity drops to 1, a per-unit
/// assignment becomes a plain "shared by" list.
BillDraft draftUpdateItem(BillDraft d, int index, DraftItem item) {
  final items = [...d.items]..[index] = item;
  final units = Map<int, Map<String, int>>.from(d.quantityAssignments);
  final people = Map<int, List<String>>.from(d.itemAssignments);
  final current = units[index];
  if (item.quantity <= 1 && current != null) {
    units.remove(index);
    people[index] = [
      for (final e in current.entries)
        if (e.value > 0) e.key,
    ];
  }
  return d.copyWith(
    items: items,
    quantityAssignments: units,
    itemAssignments: people,
  );
}

/// Removes item [index] and shifts the assignments of the items after it.
BillDraft draftRemoveItem(BillDraft d, int index) => d.copyWith(
  items: [...d.items]..removeAt(index),
  itemAssignments: _reindexAfterRemoval(d.itemAssignments, index),
  quantityAssignments: _reindexAfterRemoval(d.quantityAssignments, index),
);

/// Assigns item [index]: per unit when [units] is non-empty (quantity > 1),
/// otherwise shared equally by [people].
BillDraft draftAssign(
  BillDraft d,
  int index, {
  List<String> people = const [],
  Map<String, int> units = const {},
}) {
  final cleanUnits = {
    for (final e in units.entries)
      if (e.value > 0) e.key: e.value,
  };
  final unitMap = Map<int, Map<String, int>>.from(d.quantityAssignments);
  final peopleMap = Map<int, List<String>>.from(d.itemAssignments);
  if (cleanUnits.isNotEmpty && d.items[index].quantity > 1) {
    unitMap[index] = cleanUnits;
    peopleMap[index] = cleanUnits.keys.toList();
  } else {
    unitMap.remove(index);
    peopleMap[index] = [...people];
  }
  return d.copyWith(itemAssignments: peopleMap, quantityAssignments: unitMap);
}

/// Everyone shares every item equally.
BillDraft draftAssignAllToEveryone(BillDraft d) => d.copyWith(
  itemAssignments: {
    for (var i = 0; i < d.items.length; i++) i: [...d.participantIds],
  },
  quantityAssignments: const {},
);

BillDraft draftAddParticipant(BillDraft d, String id) =>
    d.participantIds.contains(id)
    ? d
    : d.copyWith(participantIds: [...d.participantIds, id]);

/// Removes [id] everywhere: participants, assignments, split inputs and
/// overrides.
BillDraft draftRemoveParticipant(BillDraft d, String id) {
  Map<String, T> without<T>(Map<String, T> m) => {
    for (final e in m.entries)
      if (e.key != id) e.key: e.value,
  };
  return d.copyWith(
    participantIds: [
      for (final p in d.participantIds)
        if (p != id) p,
    ],
    itemAssignments: {
      for (final e in d.itemAssignments.entries)
        e.key: [
          for (final p in e.value)
            if (p != id) p,
        ],
    },
    quantityAssignments: {
      for (final e in d.quantityAssignments.entries)
        if (without(e.value).isNotEmpty) e.key: without(e.value),
    },
    exactAmounts: without(d.exactAmounts),
    percentages: without(d.percentages),
    shares: without(d.shares),
    overrides: without(d.overrides),
    clearRoulette: d.rouletteWinnerId == id,
  );
}

int _rescale(int minor, int fromDecimals, int toDecimals) {
  if (fromDecimals == toDecimals) return minor;
  var factor = 1;
  for (var i = 0; i < (toDecimals - fromDecimals).abs(); i++) {
    factor *= 10;
  }
  if (toDecimals > fromDecimals) return minor * factor;
  // Round half away from zero.
  final q = minor.abs() * 2 + factor;
  final rounded = q ~/ (factor * 2);
  return minor < 0 ? -rounded : rounded;
}

/// Switches the currency, keeping every amount's major value (12.50 USD ->
/// 12.500 KWD, 12.50 USD -> 13 JPY). Manual overrides are dropped since
/// they no longer add up exactly.
BillDraft draftChangeCurrency(BillDraft d, String currency) {
  final code = normalizeCurrency(currency);
  final from = currencyDecimals(d.currency);
  final to = currencyDecimals(code);
  int r(int v) => _rescale(v, from, to);
  return d.copyWith(
    currency: code,
    items: [
      for (final i in d.items)
        DraftItem(
          name: i.name,
          unitPriceMinor: r(i.unitPriceMinor),
          quantity: i.quantity,
        ),
    ],
    taxMinor: r(d.taxMinor),
    serviceMinor: r(d.serviceMinor),
    tipMinor: r(d.tipMinor),
    deliveryMinor: r(d.deliveryMinor),
    discountMinor: r(d.discountMinor),
    otherCharges: [
      for (final c in d.otherCharges)
        DraftCharge(
          label: c.label,
          amountMinor: r(c.amountMinor),
          split: c.split,
        ),
    ],
    exactAmounts: d.exactAmounts.map((k, v) => MapEntry(k, r(v))),
    overrides: const {},
  );
}

// ---------------------------------------------------------------- money input

/// Plain editable text for [minor] ("12.50", "1200" for JPY), no grouping.
String moneyInputText(int minor, String currency) {
  if (minor == 0) return '';
  final decimals = currencyDecimals(currency);
  var unit = 1;
  for (var i = 0; i < decimals; i++) {
    unit *= 10;
  }
  final abs = minor.abs();
  final whole = abs ~/ unit;
  final frac = abs % unit;
  final body = decimals == 0
      ? '$whole'
      : '$whole.${frac.toString().padLeft(decimals, '0')}';
  return minor < 0 ? '-$body' : body;
}

/// Parses what the user typed ("12,5", "12.50", " 3 ") into minor units of
/// [currency]. Empty means 0; junk or a negative number returns null.
int? parseMoneyInput(String text, String currency) {
  var t = text.trim().replaceAll(' ', '').replaceAll(' ', '');
  if (t.isEmpty) return 0;
  // "1,234.50" -> drop grouping; "12,50" -> decimal comma.
  if (t.contains('.') && t.contains(',')) {
    t = t.replaceAll(',', '');
  } else {
    t = t.replaceAll(',', '.');
  }
  if (!RegExp(r'^\d*\.?\d*$').hasMatch(t) || t == '.') return null;
  final value = double.tryParse(t);
  if (value == null || value < 0) return null;
  return toMinorUnits(value, currency);
}

// -------------------------------------------------------------------- display

/// "14%" for a charge as a share of the items subtotal, "—" when there is
/// none. Falls back to the amount when the subtotal is zero.
String chargePercentLabel(
  int chargeMinor,
  int subtotalMinor,
  String currency, {
  String? locale,
}) {
  if (chargeMinor == 0) return '—';
  if (subtotalMinor <= 0) {
    return formatMoneyMinor(chargeMinor, currency, locale: locale);
  }
  final pct = chargeMinor * 100 / subtotalMinor;
  return '${NumberFormat('#,##0.#', locale).format(pct)}%';
}

/// A user-facing explanation of a [BillIssue]: a translation key and its
/// named args, with a clear next step in the text.
class IssueMessage {
  const IssueMessage(this.key, [this.args = const {}]);

  final String key;
  final Map<String, String> args;

  String get text => key.tr(namedArgs: args);

  @override
  bool operator ==(Object other) =>
      other is IssueMessage && other.key == key && mapEquals(other.args, args);

  @override
  int get hashCode => Object.hash(key, Object.hashAll(args.entries));

  @override
  String toString() => 'IssueMessage($key, $args)';
}

IssueMessage describeIssue(BillIssue issue, BillDraft draft, {String? locale}) {
  String item(int i) => i >= 0 && i < draft.items.length
      ? (draft.items[i].name.trim().isEmpty
            ? '#${i + 1}'
            : draft.items[i].name.trim())
      : '#${i + 1}';
  String money(int minor) =>
      formatMoneyMinor(minor, draft.currency, locale: locale);
  switch (issue) {
    case NoParticipantsIssue():
      return const IssueMessage('bf_edit_issue_no_people');
    case UnassignedItemIssue(
      :final index,
      :final assignedUnits,
      :final quantity,
    ):
      if (quantity > 1 && assignedUnits > 0) {
        return IssueMessage('bf_edit_issue_units_left', {
          'item': item(index),
          'count': '${quantity - assignedUnits}',
        });
      }
      return IssueMessage('bf_edit_issue_unassigned', {'item': item(index)});
    case OverAssignedItemIssue(:final index):
      return IssueMessage('bf_edit_issue_over_assigned', {'item': item(index)});
    case ExactMismatchIssue():
      return const IssueMessage('bf_edit_issue_exact');
    case PercentMismatchIssue():
      return const IssueMessage('bf_edit_issue_percent');
    case NoSharesIssue():
      return const IssueMessage('bf_edit_issue_shares');
    case DiscountTooLargeIssue(:final beforeDiscountMinor):
      return IssueMessage('bf_edit_issue_discount', {
        'amount': money(beforeDiscountMinor),
      });
    case OverrideExceedsTotalIssue():
    case OverrideMismatchIssue():
      return const IssueMessage('bf_edit_issue_overrides');
  }
}

// ----------------------------------------------------------------- controller

enum AddParticipantResult { added, duplicate, missingId }

enum RemoveParticipantResult { removed, isHost, notFound }

class EditBillController extends ChangeNotifier {
  EditBillController({
    required Map<String, dynamic> billData,
    required this.currentUid,
  }) : reader = BillReader(billData) {
    final data = billData;
    hostUid = (data['hostId']?.toString().isNotEmpty ?? false)
        ? data['hostId'].toString()
        : (currentUid ?? '');
    originalName = (data['storeName'] ?? '').toString();
    _name = originalName;
    final rawDate = data['date'];
    originalDate = rawDate is Timestamp
        ? rawDate.toDate()
        : rawDate is DateTime
        ? rawDate
        : DateTime.now();
    _date = originalDate;
    originalDraft = reader.toDraft();
    _draft = originalDraft;
    _participants = [
      for (final p in reader.participants) Map<String, dynamic>.from(p),
    ];
    _originalPaid = {
      for (final p in _participants) p['id'].toString(): _isPaid(p),
    };
    for (final p in _participants) {
      _knownNames[p['id'].toString()] = (p['name'] ?? '').toString();
    }
  }

  final BillReader reader;
  final String? currentUid;
  late final String hostUid;
  late final String originalName;
  late final DateTime originalDate;
  late final BillDraft originalDraft;

  late String _name;
  late DateTime _date;
  late BillDraft _draft;
  late List<Map<String, dynamic>> _participants;
  late final Map<String, bool> _originalPaid;
  final Map<String, String> _knownNames = {};
  bool _dirty = false;
  bool _overridesReset = false;
  BillComputation? _computation;

  String get name => _name;
  DateTime get date => _date;
  BillDraft get draft => _draft;
  String get currency => _draft.currency;
  bool get isDirty => _dirty;

  /// Participant maps in bill order (keep isPaid / status / proof keys).
  List<Map<String, dynamic>> get participants =>
      List.unmodifiable(_participants);

  List<BillParticipantInfo> get participantInfos => [
    for (final p in _participants) BillParticipantInfo.fromMap(p),
  ];

  BillComputation get computation => _computation ??= computeBill(_draft);

  List<IssueMessage> get issueMessages => [
    for (final i in computation.issues) describeIssue(i, _draft),
  ];

  bool get canSave => computation.isValid && _name.trim().isNotEmpty;

  String nameOf(String id) => _knownNames[id] ?? id;

  bool isHost(String id) => id == hostUid;

  static bool _isPaid(Map<String, dynamic> p) =>
      p['status'] == 'PAID' || (p['status'] == null && p['isPaid'] == true);

  bool isPaid(String id) {
    for (final p in _participants) {
      if (p['id'].toString() == id) return _isPaid(p);
    }
    return false;
  }

  /// True once after a money change dropped the stored manual shares, so
  /// the UI can say so. Reading it clears it.
  bool takeOverridesResetNotice() {
    final v = _overridesReset;
    _overridesReset = false;
    return v;
  }

  void _changed() {
    _dirty = true;
    _computation = null;
    notifyListeners();
  }

  /// Money-affecting change. Stored manual shares (kept as overrides so an
  /// untouched bill keeps its numbers) no longer apply, so they are reset:
  /// the bill total always stays items + charges.
  void _apply(BillDraft next) {
    if (_draft.overrides.isNotEmpty || _draft.rouletteWinnerId != null) {
      next = next.copyWith(overrides: const {}, clearRoulette: true);
      _overridesReset = true;
    }
    _draft = next;
    _changed();
  }

  void setName(String value) {
    if (value == _name) return;
    _name = value;
    _changed();
  }

  void setDate(DateTime value) {
    _date = value;
    _changed();
  }

  void setCurrency(String code) {
    if (normalizeCurrency(code) == _draft.currency) return;
    _apply(draftChangeCurrency(_draft, code));
  }

  void addItem(DraftItem item) => _apply(draftAddItem(_draft, item));

  void updateItem(int index, DraftItem item) =>
      _apply(draftUpdateItem(_draft, index, item));

  void removeItem(int index) => _apply(draftRemoveItem(_draft, index));

  void assignItem(
    int index, {
    List<String> people = const [],
    Map<String, int> units = const {},
  }) => _apply(draftAssign(_draft, index, people: people, units: units));

  void assignAllToEveryone() => _apply(
    draftAssignAllToEveryone(_draft).copyWith(method: SplitMethod.items),
  );

  void setMethod(SplitMethod method) {
    if (method == _draft.method) return;
    _apply(_draft.copyWith(method: method));
  }

  void setCharges({
    required int taxMinor,
    required int serviceMinor,
    required int tipMinor,
    required int deliveryMinor,
    required int discountMinor,
  }) {
    if (taxMinor == _draft.taxMinor &&
        serviceMinor == _draft.serviceMinor &&
        tipMinor == _draft.tipMinor &&
        deliveryMinor == _draft.deliveryMinor &&
        discountMinor == _draft.discountMinor) {
      return;
    }
    _apply(
      _draft.copyWith(
        taxMinor: taxMinor,
        serviceMinor: serviceMinor,
        tipMinor: tipMinor,
        deliveryMinor: deliveryMinor,
        discountMinor: discountMinor.abs(),
      ),
    );
  }

  AddParticipantResult addParticipant({
    required String? id,
    required String name,
    String? photoUrl,
    String? phoneNumber,
    bool isGuest = false,
  }) {
    if (id == null || id.isEmpty) return AddParticipantResult.missingId;
    if (_participants.any((p) => p['id'].toString() == id)) {
      return AddParticipantResult.duplicate;
    }
    _participants.add({
      'id': id,
      'name': name,
      'photoUrl': photoUrl ?? '',
      'phoneNumber': phoneNumber ?? '',
      'isGuest': isGuest,
      'status': id == hostUid ? 'PAID' : 'PENDING',
      'isPaid': id == hostUid,
    });
    _knownNames[id] = name;
    _apply(draftAddParticipant(_draft, id));
    return AddParticipantResult.added;
  }

  RemoveParticipantResult removeParticipant(String id) {
    if (isHost(id)) return RemoveParticipantResult.isHost;
    final before = _participants.length;
    _participants.removeWhere((p) => p['id'].toString() == id);
    if (_participants.length == before) return RemoveParticipantResult.notFound;
    _apply(draftRemoveParticipant(_draft, id));
    return RemoveParticipantResult.removed;
  }

  /// Toggles a participant between paid and not paid yet.
  void togglePaid(String id) {
    final i = _participants.indexWhere((p) => p['id'].toString() == id);
    if (i < 0) return;
    final p = Map<String, dynamic>.from(_participants[i]);
    final paid = !_isPaid(p);
    p['status'] = paid ? 'PAID' : 'PENDING';
    p['isPaid'] = paid;
    _participants[i] = p;
    _changed();
  }

  /// The history entries this save adds (newest first).
  List<BillHistoryEntry> historyEntries({
    required DateTime now,
    String? byName,
  }) {
    final by = currentUid ?? hostUid;
    final diff = diffDrafts(
      before: originalDraft,
      after: _draft,
      by: by,
      byName: byName,
      at: now,
      nameBefore: originalName,
      nameAfter: _name.trim(),
      participantNames: Map.of(_knownNames),
    );
    final paidEntries = <BillHistoryEntry>[
      for (final p in _participants)
        if (_isPaid(p) && _originalPaid[p['id'].toString()] == false)
          BillHistoryEntry(
            by: by,
            byName: byName,
            at: now,
            change: 'marked_paid',
            args: {'name': (p['name'] ?? '').toString(), 'id': p['id']},
          ),
    ];
    final onlyEdited = diff.length == 1 && diff.single.change == 'edited';
    return [
      if (!(onlyEdited && paidEntries.isNotEmpty)) ...diff,
      ...paidEntries,
    ];
  }

  /// The Firestore update: 2.0 bill fields (participants keep their
  /// payment status and proof), the date and the new `history`. Other
  /// fields of the doc (hostId, paymentMethods, ...) are left untouched
  /// because this goes through `update`.
  Map<String, dynamic> buildUpdate({required DateTime now, String? byName}) {
    final fields = buildBillFields(
      computation: computation,
      participants: participantInfos,
      hostUid: hostUid,
      storeName: _name.trim(),
      previousParticipants: [
        for (final p in _participants) Map<String, dynamic>.from(p),
      ],
      groupId: reader.groupId,
    );
    return {
      ...fields,
      if (_date != originalDate) 'date': Timestamp.fromDate(_date),
      'history': appendHistory(
        reader.data['history'] as List?,
        historyEntries(now: now, byName: byName),
      ),
    };
  }
}
