import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/group_settlement.dart';

Map<String, dynamic> _bill({String? groupId}) => {
  'hostId': 'host',
  'currency': 'EGP',
  if (groupId != null) 'groupId': groupId,
  'participants_uids': ['host', 'ali'],
  'participants': [
    {'id': 'host', 'name': 'Omar', 'shareMinor': 2709},
    {'id': 'ali', 'name': 'Ali', 'shareMinor': 3024},
    {'id': 'guest_1', 'name': 'Mona', 'shareMinor': 1638},
  ],
};

Map<String, dynamic> _p(Map<String, dynamic> bill, String id) =>
    (bill['participants'] as List).cast<Map<String, dynamic>>().firstWhere(
      (p) => p['id'] == id,
    );

void main() {
  test('member share in a group becomes a payment to the host', () {
    final bill = _bill(groupId: 'g1');
    final payment = groupSettlementForPaidShare(
      billId: 'b1',
      bill: bill,
      participant: _p(bill, 'ali'),
      createdBy: 'host',
    );
    expect(payment, isNotNull);
    expect(payment!.from, 'ali');
    expect(payment.to, 'host');
    expect(payment.amountMinor, 3024);
    expect(payment.currency, 'EGP');
    expect(payment.groupId, 'g1');
    expect(payment.billId, 'b1');
    expect(payment.method, 'marked_paid');
  });

  test('bills outside a group record nothing', () {
    final bill = _bill();
    expect(
      groupSettlementForPaidShare(
        billId: 'b1',
        bill: bill,
        participant: _p(bill, 'ali'),
        createdBy: 'host',
      ),
      isNull,
    );
  });

  test('guests without an account and the host record nothing', () {
    final bill = _bill(groupId: 'g1');
    for (final id in ['guest_1', 'host']) {
      expect(
        groupSettlementForPaidShare(
          billId: 'b1',
          bill: bill,
          participant: _p(bill, id),
          createdBy: 'host',
        ),
        isNull,
        reason: id,
      );
    }
  });

  test('empty shares record nothing', () {
    final bill = _bill(groupId: 'g1');
    final zero = {..._p(bill, 'ali'), 'shareMinor': 0};
    expect(
      groupSettlementForPaidShare(
        billId: 'b1',
        bill: bill,
        participant: zero,
        createdBy: 'host',
      ),
      isNull,
    );
  });

  group('settlement link on toggle', () {
    test('unmark whose delete failed keeps the link', () {
      expect(
        nextSettlementPaymentId(
          paid: false,
          previousId: 'pay1',
          recordedId: null,
          deleteSucceeded: false,
        ),
        'pay1',
      );
    });

    test('unmark whose delete worked clears the link', () {
      expect(
        nextSettlementPaymentId(
          paid: false,
          previousId: 'pay1',
          recordedId: null,
          deleteSucceeded: true,
        ),
        isNull,
      );
    });

    test('re-marking reuses the existing payment instead of a second one', () {
      final plan = planSettlementLink(
        paid: true,
        previousId: 'pay1',
        hasSettlement: true,
      );
      expect(plan.recordNew, isFalse);
      expect(plan.reuseId, 'pay1');
      expect(
        nextSettlementPaymentId(
          paid: true,
          previousId: 'pay1',
          recordedId: null,
          deleteSucceeded: true,
        ),
        'pay1',
      );
    });

    test('first mark records a new payment; unmark plans a delete', () {
      expect(
        planSettlementLink(paid: true, previousId: '', hasSettlement: true)
            .recordNew,
        isTrue,
      );
      expect(
        planSettlementLink(paid: false, previousId: 'pay1', hasSettlement: false)
            .deleteId,
        'pay1',
      );
    });
  });
}
