import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';

Map<String, dynamic> _bill(Map<String, dynamic> sara) => {
  'currency': 'EGP',
  'hostId': 'host',
  'totalMinor': 52987 + 1000,
  'participants': [
    {'id': 'host', 'name': 'Omar', 'shareMinor': 1000, 'status': 'PAID'},
    {'id': 'sara', 'name': 'Sara', 'shareMinor': 52987, ...sara},
  ],
};

/// Saves an edit where Sara's share becomes [newShare] (host takes the rest).
Map<String, dynamic> _edit(int newShare, Map<String, dynamic> prevSara) {
  final draft = BillDraft(
    currency: 'EGP',
    items: [
      DraftItem(name: 'Dinner', unitPriceMinor: 1000 + newShare, quantity: 1),
    ],
    participantIds: const ['host', 'sara'],
    method: SplitMethod.exact,
    exactAmounts: {'host': 1000, 'sara': newShare},
  );
  return buildBillFields(
    computation: computeBill(draft),
    participants: const [
      BillParticipantInfo(id: 'host', name: 'Omar'),
      BillParticipantInfo(id: 'sara', name: 'Sara'),
    ],
    hostUid: 'host',
    previousParticipants: [
      {'id': 'host', 'status': 'PAID', 'isPaid': true, 'shareMinor': 1000},
      {'id': 'sara', 'shareMinor': 52987, ...prevSara},
    ],
  );
}

Map _sara(Map<String, dynamic> fields) =>
    (fields['participants'] as List).last as Map;

void main() {
  test('legacy PAID without paidMinor counts as fully paid', () {
    final r = BillReader(_bill({'status': 'PAID', 'isPaid': true}));
    final sara = r.participants.last;
    expect(r.paidMinorOf(sara), 52987);
    expect(r.outstandingMinorOf(sara), 0);
    // status null + isPaid true is the 1.x shape.
    final old = BillReader(_bill({'isPaid': true})).participants.last;
    expect(paidMinorFromMap(old, 52987), 52987);
  });

  test('pending participant owes the whole share', () {
    final r = BillReader(_bill({'status': 'PENDING', 'isPaid': false}));
    expect(r.outstandingMinorOf(r.participants.last), 52987);
  });

  test('edit raising a paid share reopens with the difference owed', () {
    final saved = _edit(54848, {'status': 'PAID', 'isPaid': true});
    final sara = _sara(saved);
    expect(sara['status'], 'PENDING');
    expect(sara['isPaid'], false);
    expect(sara['paidMinor'], 52987);
    final r = BillReader(saved);
    expect(r.outstandingMinorOf(r.participants.last), 1861);
    final summary = collectionSummary(r, hostId: 'host');
    expect(summary.collectedMinor, 52987);
    expect(summary.owedMinor, 54848);
    expect(summary.allSettled, isFalse);
  });

  test('edit lowering a paid share keeps it paid', () {
    final saved = _edit(50000, {'status': 'PAID', 'isPaid': true});
    final sara = _sara(saved);
    expect(sara['status'], 'PAID');
    expect(sara['isPaid'], true);
    final r = BillReader(saved);
    expect(r.outstandingMinorOf(r.participants.last), 0);
  });

  test('unpaid participants and the host are unchanged by an edit', () {
    final saved = _edit(54848, {'status': 'PENDING', 'isPaid': false});
    expect(_sara(saved)['status'], 'PENDING');
    expect(_sara(saved).containsKey('paidMinor'), isFalse);
    final host = (saved['participants'] as List).first as Map;
    expect(host['status'], 'PAID');
  });

  test('confirmed share is stamped with paidMinor == share', () {
    // What bill details writes when the host confirms payment.
    final r = BillReader(_bill({'status': 'REVIEW', 'isPaid': false}));
    final p = r.participants.last;
    final confirmed = {
      ...p,
      'status': 'PAID',
      'isPaid': true,
      'paidMinor': r.shareMinorOf(p),
    };
    expect(confirmed['paidMinor'], 52987);
    expect(r.outstandingMinorOf(confirmed), 0);
  });

  test('ledger and home balances use what is outstanding', () {
    final saved = _edit(54848, {'status': 'PAID', 'isPaid': true});
    final rec = BillRecord.fromMap('b1', {...saved, 'hostId': 'host'});
    expect(rec.owedBy('sara'), 1861);
    expect(rec.isOpen, isTrue);
    expect(rec.toExpense()!.owedBy['sara'], 1861);
    // Paid in full: nothing owed.
    final paid = BillRecord.fromMap(
      'b2',
      _bill({'status': 'PAID', 'isPaid': true}),
    );
    expect(paid.owedBy('sara'), 0);
    expect(paid.isOpen, isFalse);
  });
}
