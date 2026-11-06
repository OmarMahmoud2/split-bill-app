/// Pure helpers for how much of a participant's share the host has received.
/// No imports on purpose: the guest web page uses them too.
library;

/// Paid for the host's purposes: status PAID, or no status and `isPaid`.
bool isParticipantPaid(Map<String, dynamic> p) =>
    p['status'] == 'PAID' || (p['status'] == null && p['isPaid'] == true);

/// What the host has received from participant [p] (minor units). A PAID
/// participant counts as fully paid (covers legacy data without `paidMinor`).
int paidMinorFromMap(Map<String, dynamic> p, int shareMinor) {
  if (isParticipantPaid(p)) return shareMinor;
  final m = p['paidMinor'];
  return m is num && m > 0 ? m.round() : 0;
}

/// What [p] still owes: share minus [paidMinorFromMap], never negative.
int outstandingMinorFromMap(Map<String, dynamic> p, int shareMinor) {
  final left = shareMinor - paidMinorFromMap(p, shareMinor);
  return left > 0 ? left : 0;
}
