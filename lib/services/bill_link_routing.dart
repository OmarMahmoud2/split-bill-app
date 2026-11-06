/// Where a bill link or notification tap should land for a signed-in user.
enum BillLinkTarget {
  /// The signed-in user hosts the bill.
  host,

  /// The signed-in user is a participant (by uid).
  participant,

  /// A personal guest link (`?p=`) for someone else's entry: open the guest
  /// page for that entry instead of a dead end.
  guestEntry,

  /// No bill (or nothing the user may open).
  notFound,
}

/// Decides the [BillLinkTarget] from the bill document [data] (null when it
/// does not exist), the signed-in [uid] and the optional personal link id
/// [personalId] (`?p=`).
BillLinkTarget resolveBillLinkTarget({
  required Map<String, dynamic>? data,
  required String uid,
  String? personalId,
}) {
  final hasPersonal = personalId != null && personalId.isNotEmpty;
  if (data == null) return BillLinkTarget.notFound;
  if (data['hostId'] == uid) return BillLinkTarget.host;
  final people = data['participants'];
  final onBill =
      people is List &&
      people.any((p) => p is Map && p['id']?.toString() == uid);
  if (onBill) return BillLinkTarget.participant;
  if (hasPersonal && personalId != uid) return BillLinkTarget.guestEntry;
  // Not on the bill and no personal link: the participant screen explains it.
  return BillLinkTarget.participant;
}
