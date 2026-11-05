/// Pure helpers for the "Who had what" assignment screen (no Flutter, no
/// Firebase), so the rules can be unit tested.
///
/// Money math stays in `lib/bill_flow`; this file only answers UI questions:
/// how many items are assigned, what note an item row shows, how many units
/// are left, how a voice result maps onto assignments.
library;

import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:uuid/uuid.dart';

/// "5 of 6": how many receipt items are fully assigned.
class AssignmentProgress {
  const AssignmentProgress({required this.assigned, required this.total});

  final int assigned;
  final int total;

  int get left => total - assigned;
  bool get isComplete => assigned >= total;
}

/// Counts the items of [draft] whose units are exactly covered.
AssignmentProgress assignmentProgress(BillDraft draft) {
  var assigned = 0;
  for (var i = 0; i < draft.items.length; i++) {
    final state = draft.assignmentOf(i);
    if (draft.items[i].quantity >= 1 && state.isComplete) assigned++;
  }
  return AssignmentProgress(assigned: assigned, total: draft.items.length);
}

/// What the small grey note under an item says.
enum ItemNoteKind {
  /// Fully assigned to one person: no note.
  none,

  /// Nobody yet: "Tap a face below" (row highlighted amber).
  unassigned,

  /// Shared equally: "split {count} ways".
  splitWays,

  /// Per unit, everyone took the same: "{count} each".
  each,

  /// Per unit, some units still free: "{count} left".
  unitsLeft,

  /// Per unit, more units than the quantity (legacy data): "{count} too many".
  tooMany,
}

class ItemNote {
  const ItemNote(this.kind, [this.count = 0]);

  final ItemNoteKind kind;
  final int count;

  /// i18n key for [kind]; null for [ItemNoteKind.none].
  String? get key => switch (kind) {
    ItemNoteKind.none => null,
    ItemNoteKind.unassigned => 'bf_assign_note_tap_face',
    ItemNoteKind.splitWays => 'bf_assign_note_split_ways',
    ItemNoteKind.each => 'bf_assign_note_each',
    ItemNoteKind.unitsLeft => 'bf_assign_note_units_left',
    ItemNoteKind.tooMany => 'bf_assign_note_too_many',
  };

  /// Whether the row should be highlighted as needing attention.
  bool get needsAttention =>
      kind == ItemNoteKind.unassigned ||
      kind == ItemNoteKind.unitsLeft ||
      kind == ItemNoteKind.tooMany;

  @override
  bool operator ==(Object other) =>
      other is ItemNote && other.kind == kind && other.count == count;

  @override
  int get hashCode => Object.hash(kind, count);

  @override
  String toString() => 'ItemNote($kind, $count)';
}

/// The note for an item in [state].
ItemNote itemNoteFor(ItemAssignmentState state) {
  if (state.isEmpty) return const ItemNote(ItemNoteKind.unassigned);
  if (state.isOver) {
    return ItemNote(ItemNoteKind.tooMany, state.assignedUnits - state.quantity);
  }
  if (state.unitAssignments.isNotEmpty) {
    if (!state.isComplete) {
      return ItemNote(
        ItemNoteKind.unitsLeft,
        state.quantity - state.assignedUnits,
      );
    }
    final counts = state.unitAssignments.values.toSet();
    if (state.people.length > 1 && counts.length == 1) {
      return ItemNote(ItemNoteKind.each, counts.first);
    }
    return const ItemNote(ItemNoteKind.none);
  }
  if (state.people.length > 1) {
    return ItemNote(ItemNoteKind.splitWays, state.people.length);
  }
  return const ItemNote(ItemNoteKind.none);
}

/// Per-unit assignment rules: never more units than the quantity.
class UnitCap {
  UnitCap._();

  static int assigned(Map<String, int> units) =>
      units.values.fold(0, (sum, n) => sum + (n > 0 ? n : 0));

  /// Units still free (never negative).
  static int remaining(Map<String, int> units, int quantity) {
    final left = quantity - assigned(units);
    return left < 0 ? 0 : left;
  }

  static bool canAdd(Map<String, int> units, int quantity) =>
      remaining(units, quantity) > 0;

  /// One more unit for [id], or [units] unchanged when none is left.
  static Map<String, int> increment(
    Map<String, int> units,
    String id,
    int quantity,
  ) {
    if (!canAdd(units, quantity)) return Map.of(units);
    return {...units, id: (units[id] ?? 0) + 1};
  }

  /// One unit fewer for [id]; drops the entry at zero.
  static Map<String, int> decrement(Map<String, int> units, String id) {
    final current = units[id] ?? 0;
    final next = Map.of(units);
    if (current <= 1) {
      next.remove(id);
    } else {
      next[id] = current - 1;
    }
    return next;
  }

  /// Drops zero/negative entries and trims units from the last people until
  /// the total fits [quantity] (repairs legacy over-assigned data).
  static Map<String, int> clamp(Map<String, int> units, int quantity) {
    final result = <String, int>{
      for (final e in units.entries)
        if (e.value > 0) e.key: e.value,
    };
    var over = assigned(result) - (quantity < 0 ? 0 : quantity);
    final keys = result.keys.toList();
    for (var i = keys.length - 1; i >= 0 && over > 0; i--) {
      final n = result[keys[i]]!;
      final take = n < over ? n : over;
      over -= take;
      if (n - take == 0) {
        result.remove(keys[i]);
      } else {
        result[keys[i]] = n - take;
      }
    }
    return result;
  }
}

/// What a face tap did on a quantity item.
enum UnitTapResult { added, removed, full }

/// A face tap on a quantity item in per-unit mode: a person not on the item
/// takes one unit (if any is left); a person on it is taken off.
({Map<String, int> units, UnitTapResult result}) tapUnitFace(
  Map<String, int> units,
  String id,
  int quantity,
) {
  if ((units[id] ?? 0) > 0) {
    return (units: Map.of(units)..remove(id), result: UnitTapResult.removed);
  }
  if (!UnitCap.canAdd(units, quantity)) {
    return (units: Map.of(units), result: UnitTapResult.full);
  }
  return (
    units: UnitCap.increment(units, id, quantity),
    result: UnitTapResult.added,
  );
}

/// Toggles [id] on a shared (equal) item.
List<String> toggleShared(List<String> people, String id) =>
    people.contains(id) ? (List.of(people)..remove(id)) : [...people, id];

/// Assignments with [id] removed everywhere; items left empty are dropped.
({Map<int, List<String>> items, Map<int, Map<String, int>> units})
removeParticipantAssignments(
  Map<int, List<String>> itemAssignments,
  Map<int, Map<String, int>> quantityAssignments,
  String id,
) {
  final items = <int, List<String>>{};
  itemAssignments.forEach((index, people) {
    final rest = people.where((p) => p != id).toList();
    if (rest.isNotEmpty) items[index] = rest;
  });
  final units = <int, Map<String, int>>{};
  quantityAssignments.forEach((index, map) {
    final rest = Map.of(map)..remove(id);
    if (rest.isNotEmpty) units[index] = rest;
  });
  return (items: items, units: units);
}

/// Assignments decoded from the voice overlay.
class VoiceAssignment {
  const VoiceAssignment({required this.items, required this.units});

  /// Item index -> people sharing it equally.
  final Map<int, List<String>> items;

  /// Item index -> units per person.
  final Map<int, Map<String, int>> units;

  bool get isEmpty => items.isEmpty && units.isEmpty;
}

/// Decodes what `VoiceCommandOverlay` pops: either the legacy
/// `Map<String, List<String>>` (item index -> user ids) or a map with
/// `assignments` (that same shape) and `splits` (item index -> user id ->
/// units). Unknown ids (when [knownIds] is given), bad indexes
/// and zero units are dropped. An item with per-unit splits is not also
/// kept as a shared item. Returns null for anything else.
VoiceAssignment? parseVoiceResult(
  Object? result, {
  Set<String>? knownIds,
  int? itemCount,
}) {
  if (result is! Map) return null;
  final wrapped =
      (result.containsKey('assignments') || result.containsKey('splits')) &&
      result.values.every((v) => v == null || v is Map);
  final rawItems = wrapped ? result['assignments'] : result;
  final rawSplits = wrapped ? result['splits'] : null;

  bool known(String id) => knownIds == null || knownIds.contains(id);
  int? indexOf(Object? key) {
    final i = int.tryParse(key.toString());
    if (i == null || i < 0) return null;
    if (itemCount != null && i >= itemCount) return null;
    return i;
  }

  final units = <int, Map<String, int>>{};
  if (rawSplits is Map) {
    rawSplits.forEach((key, value) {
      final index = indexOf(key);
      if (index == null || value is! Map) return;
      final map = <String, int>{};
      value.forEach((id, n) {
        final count = n is num ? n.round() : int.tryParse(n.toString());
        if (count != null && count > 0 && known(id.toString())) {
          map[id.toString()] = count;
        }
      });
      if (map.isNotEmpty) units[index] = map;
    });
  }

  final items = <int, List<String>>{};
  if (rawItems is Map) {
    rawItems.forEach((key, value) {
      final index = indexOf(key);
      if (index == null || value is! List || units.containsKey(index)) return;
      final ids = <String>[];
      for (final id in value) {
        final s = id.toString();
        if (known(s) && !ids.contains(s)) ids.add(s);
      }
      if (ids.isNotEmpty) items[index] = ids;
    });
  }
  return VoiceAssignment(items: items, units: units);
}

/// The first item problem that blocks "Continue", in receipt order.
({int index, bool over, int assigned, int quantity})? firstItemIssue(
  List<BillIssue> issues,
) {
  ({int index, bool over, int assigned, int quantity})? best;
  for (final issue in issues) {
    final candidate = switch (issue) {
      UnassignedItemIssue(
        :final index,
        :final assignedUnits,
        :final quantity,
      ) =>
        (
          index: index,
          over: false,
          assigned: assignedUnits,
          quantity: quantity,
        ),
      OverAssignedItemIssue(
        :final index,
        :final assignedUnits,
        :final quantity,
      ) =>
        (index: index, over: true, assigned: assignedUnits, quantity: quantity),
      _ => null,
    };
    if (candidate != null && (best == null || candidate.index < best.index)) {
      best = candidate;
    }
  }
  return best;
}

/// A guest participant (name only) with a stable unique id.
Map<String, dynamic> guestParticipant(String name, {String? id}) => {
  'id': id ?? 'guest_${const Uuid().v4()}',
  'name': name.trim(),
  'phoneNumber': '',
  'photoUrl': '',
  'isGuest': true,
  'isHost': false,
};

/// First letter of the first word, upper-cased ("?" when empty).
String initialOf(Object? name) {
  final s = (name ?? '').toString().trim();
  if (s.isEmpty) return '?';
  return String.fromCharCode(s.runes.first).toUpperCase();
}

/// First word of a display name.
String firstNameOf(Object? name) {
  final s = (name ?? '').toString().trim();
  if (s.isEmpty) return '?';
  return s.split(RegExp(r'\s+')).first;
}

/// A bill participant from a profile / contact lookup (`uid` or `id`,
/// `displayName` or `name`). Guests without an id get a stable guest id.
Map<String, dynamic> participantFromProfile(
  Map<dynamic, dynamic> data, {
  bool isGuest = false,
  String fallbackName = '',
}) {
  final rawId = (data['uid'] ?? data['id'])?.toString();
  final rawName = (data['displayName'] ?? data['name'])?.toString().trim();
  return {
    'id': rawId == null || rawId.isEmpty ? 'guest_${const Uuid().v4()}' : rawId,
    'name': rawName == null || rawName.isEmpty ? fallbackName : rawName,
    'phoneNumber': (data['phoneNumber'] ?? '').toString(),
    'photoUrl': (data['photoUrl'] ?? '').toString(),
    'isGuest': isGuest,
    'isHost': false,
    'isPro': data['isPro'] == true,
  };
}

/// [current] reconciled with the add-people step's [selected] list: hosts
/// always stay, people not selected any more are dropped (their ids are in
/// `removed`), new people are appended in selection order.
({List<Map<String, dynamic>> participants, List<String> removed})
reconcileParticipants(
  List<Map<String, dynamic>> current,
  List<Map<String, dynamic>> selected,
) {
  final selectedIds = {for (final x in selected) x['id'].toString()};
  final removed = <String>[];
  final result = <Map<String, dynamic>>[];
  for (final x in current) {
    final id = x['id'].toString();
    if (x['isHost'] == true || selectedIds.contains(id)) {
      result.add(x);
    } else {
      removed.add(id);
    }
  }
  final have = {for (final x in result) x['id'].toString()};
  for (final x in selected) {
    final id = x['id'].toString();
    if (have.add(id)) result.add(x);
  }
  return (participants: result, removed: removed);
}
