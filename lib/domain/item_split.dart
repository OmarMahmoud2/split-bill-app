/// Item-based ("who had what") bill splitting in integer minor units.
///
/// Reproduces the per-person totals of the current app
/// (`_BillSummaryConfirmScreenState._calculateFinalShares` in
/// lib/bill_summary_confirm_screen.dart, mirrored for display by
/// `_ParticipantBillScreenState._calculateMyShare` in
/// lib/participant_bill_screen.dart):
///
/// * An item's line total is `unitPrice * quantity` (the receipt `price` is
///   per unit).
/// * If `quantity > 1` and per-unit assignments exist, each assignee pays
///   `unitPrice * unitsTaken`; otherwise the line total is split equally
///   among the assignees.
/// * Tax, service charge, tip, discount and "proportional" other charges are
///   allocated in proportion to each person's item subtotal.
/// * Delivery fee and "equal" other charges are split equally among *all*
///   participants, including those who had no items.
/// * Person total = items + tax + service + tip + delivery + other - discount.
///
/// Unlike the legacy double maths, every allocation here uses the
/// largest-remainder method so the per-person totals always add up to the
/// grand total exactly.
///
/// Deliberate deviations from the legacy code (each one is a suspected bug
/// there, see the notes below):
///
/// * LEGACY BUG (rounding drift): the app computes shares as doubles, never
///   rounds them to minor units, stores the raw doubles as `share` in
///   Firestore, and displays them with `decimalDigits: 1`. Displayed shares
///   therefore can disagree with the total by several cents, and 1-decimal
///   formatting is wrong for every currency (USD shows 3.3 instead of 3.33,
///   KWD loses two of its three decimals, JPY shows a spurious .0).
/// * LEGACY BUG (silent money loss): assignee ids that are not in the
///   participants list are skipped (`if (shares.containsKey(uid))`), so
///   their part of the item disappears from the bill. Here this throws
///   [UnknownParticipantError].
/// * LEGACY BUG (over-assignment): split_bill_screen.dart `_finalizeBill`
///   only rejects `assignedQty < totalQty`; assigning 4 of 3 units passes and
///   inflates the bill by one unit. Here any mismatch throws
///   [ItemAssignmentError].
/// * LEGACY BUG (vanishing charges): when the assigned item subtotal is 0
///   the app divides by 1 instead, so every proportional charge (tax, tip,
///   service, discount) is allocated as 0 to everybody and silently dropped.
///   Here proportional charges fall back to an equal split.
///
/// Other suspected legacy bugs, outside what this function models:
///
/// * Quantity assignments are lost on save: `_createBill` persists only
///   `quantityAssignments[i].keys` as `assignedTo`, and
///   participant_bill_screen.dart re-splits each line equally by
///   `assignedTo.length`. Someone who took 1 of 3 sodas (the other person 2)
///   is shown half the line, so the participant view disagrees with the
///   stored `share`.
/// * The `equal` split key is read inconsistently: the summary screen's
///   `_calculateFinalShares` only checks `split_method`, while
///   `_shareForCharge` and participant_bill_screen.dart accept `splitMethod`
///   too, so a camelCase charge is proportional in one place and equal in
///   another.
/// * `_showUserBreakdown` uses `_calculateTotalItemCost()` (all receipt
///   items) as the proportion denominator, while `_calculateFinalShares`
///   uses the sum of assigned shares; the breakdown rows can therefore not
///   add up to the displayed share.
/// * Manual share overrides (`_manualShareOverrides`) replace a person's
///   share without rebalancing anyone else, and `total` is then saved as the
///   sum of shares, silently changing the bill total.
/// * A large discount can make a share negative; nothing clamps or flags it.
library;

import 'domain_errors.dart';
import 'split_methods.dart';

/// How a non-standard charge is shared.
enum ChargeSplit {
  /// In proportion to each person's item subtotal (legacy default).
  proportional,

  /// Equally among all participants (legacy `split_method: 'equal'`).
  equal,
}

/// An extra line on the receipt (cover charge, bag fee, parking...).
class OtherCharge {
  final String label;

  /// Amount in minor units, >= 0.
  final int amount;
  final ChargeSplit split;

  const OtherCharge({
    required this.label,
    required this.amount,
    this.split = ChargeSplit.proportional,
  });
}

/// A receipt line item.
class BillItem {
  final String name;

  /// Price of ONE unit in minor units (legacy `price`).
  final int unitPrice;

  /// Number of units on the line (legacy `qty`, default 1).
  final int quantity;

  /// People sharing the whole line equally (legacy `itemAssignments[i]`).
  final List<String> assignees;

  /// Units taken per person (legacy `quantityAssignments[i]`). Only used
  /// when [quantity] > 1, exactly like the legacy code.
  final Map<String, int> unitAssignments;

  const BillItem({
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.assignees = const [],
    this.unitAssignments = const {},
  });

  int get lineTotal => unitPrice * quantity;

  bool get _usesUnitAssignments => quantity > 1 && unitAssignments.isNotEmpty;
}

/// Bill-level charges in minor units (all >= 0; [discount] is subtracted).
class BillCharges {
  final int tax;
  final int serviceCharge;
  final int tip;
  final int deliveryFee;
  final int discount;
  final List<OtherCharge> otherCharges;

  const BillCharges({
    this.tax = 0,
    this.serviceCharge = 0,
    this.tip = 0,
    this.deliveryFee = 0,
    this.discount = 0,
    this.otherCharges = const [],
  });
}

/// One participant's breakdown, in minor units.
class PersonShare {
  final int items;
  final int tax;
  final int serviceCharge;
  final int tip;
  final int deliveryFee;
  final int otherCharges;
  final int discount;

  const PersonShare({
    required this.items,
    required this.tax,
    required this.serviceCharge,
    required this.tip,
    required this.deliveryFee,
    required this.otherCharges,
    required this.discount,
  });

  /// What this person owes for the bill.
  int get total =>
      items + tax + serviceCharge + tip + deliveryFee + otherCharges - discount;
}

/// Result of [splitItemizedBill].
class ItemizedSplit {
  /// Breakdown per participant, in participant input order.
  final Map<String, PersonShare> shares;

  /// Sum of all item line totals.
  final int itemsSubtotal;

  /// Items + all charges - discount. Always equals the sum of [totals].
  final int grandTotal;

  const ItemizedSplit({
    required this.shares,
    required this.itemsSubtotal,
    required this.grandTotal,
  });

  /// Total owed per participant, in participant input order.
  Map<String, int> get totals =>
      shares.map((id, share) => MapEntry(id, share.total));
}

void _nonNegative(String field, int value) {
  if (value < 0) throw NegativeAmountError(field, value);
}

/// Splits an itemized bill. See the library docs for the rules.
ItemizedSplit splitItemizedBill({
  required List<String> participants,
  required List<BillItem> items,
  BillCharges charges = const BillCharges(),
}) {
  if (participants.isEmpty) throw const EmptyParticipantsError();
  final known = <String>{};
  for (final p in participants) {
    if (!known.add(p)) throw DuplicateParticipantError(p);
  }
  void checkKnown(String id) {
    if (!known.contains(id)) throw UnknownParticipantError(id);
  }

  _nonNegative('tax', charges.tax);
  _nonNegative('serviceCharge', charges.serviceCharge);
  _nonNegative('tip', charges.tip);
  _nonNegative('deliveryFee', charges.deliveryFee);
  _nonNegative('discount', charges.discount);
  for (final c in charges.otherCharges) {
    _nonNegative(c.label, c.amount);
  }

  // 1. Item subtotals per person.
  final itemTotals = {for (final p in participants) p: 0};
  var itemsSubtotal = 0;
  for (final item in items) {
    _nonNegative('${item.name}.unitPrice', item.unitPrice);
    if (item.quantity < 1) {
      throw ItemAssignmentError(
        itemName: item.name,
        quantity: item.quantity,
        assignedQuantity: 0,
      );
    }
    itemsSubtotal += item.lineTotal;

    if (item._usesUnitAssignments) {
      var assigned = 0;
      item.unitAssignments.forEach((id, units) {
        checkKnown(id);
        _nonNegative('${item.name}.$id', units);
        assigned += units;
      });
      if (assigned != item.quantity) {
        throw ItemAssignmentError(
          itemName: item.name,
          quantity: item.quantity,
          assignedQuantity: assigned,
        );
      }
      item.unitAssignments.forEach((id, units) {
        itemTotals[id] = itemTotals[id]! + item.unitPrice * units;
      });
    } else {
      if (item.assignees.isEmpty) {
        throw ItemAssignmentError(
          itemName: item.name,
          quantity: item.quantity,
          assignedQuantity: 0,
        );
      }
      item.assignees.forEach(checkKnown);
      splitEqually(item.lineTotal, item.assignees).forEach((id, part) {
        itemTotals[id] = itemTotals[id]! + part;
      });
    }
  }

  // 2. Charges.
  Map<String, int> proportional(int amount) => itemsSubtotal == 0
      ? splitEqually(amount, participants)
      : allocateByWeights(amount, itemTotals);
  Map<String, int> equal(int amount) => splitEqually(amount, participants);

  var proportionalOther = 0;
  var equalOther = 0;
  for (final c in charges.otherCharges) {
    if (c.split == ChargeSplit.equal) {
      equalOther += c.amount;
    } else {
      proportionalOther += c.amount;
    }
  }

  final tax = proportional(charges.tax);
  final service = proportional(charges.serviceCharge);
  final tip = proportional(charges.tip);
  final discount = proportional(charges.discount);
  final otherProp = proportional(proportionalOther);
  final delivery = equal(charges.deliveryFee);
  final otherEqual = equal(equalOther);

  final shares = <String, PersonShare>{
    for (final p in participants)
      p: PersonShare(
        items: itemTotals[p]!,
        tax: tax[p]!,
        serviceCharge: service[p]!,
        tip: tip[p]!,
        deliveryFee: delivery[p]!,
        otherCharges: otherProp[p]! + otherEqual[p]!,
        discount: discount[p]!,
      ),
  };

  final grandTotal =
      itemsSubtotal +
      charges.tax +
      charges.serviceCharge +
      charges.tip +
      charges.deliveryFee +
      proportionalOther +
      equalOther -
      charges.discount;

  return ItemizedSplit(
    shares: shares,
    itemsSubtotal: itemsSubtotal,
    grandTotal: grandTotal,
  );
}
