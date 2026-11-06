import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_calculator.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/widgets/bill_details/bill_view_logic.dart';

import 'fixtures.dart';

void main() {
  group('payStatusOf', () {
    test('maps PAID / REVIEW / PENDING and legacy isPaid', () {
      expect(payStatusOf({'status': 'PAID'}), PayStatus.paid);
      expect(payStatusOf({'status': 'paid'}), PayStatus.paid);
      expect(payStatusOf({'status': 'REVIEW'}), PayStatus.review);
      expect(payStatusOf({'status': 'PENDING'}), PayStatus.notYet);
      expect(payStatusOf({'isPaid': true}), PayStatus.paid);
      expect(payStatusOf({}), PayStatus.notYet);
      expect(payStatusOf(null), PayStatus.notYet);
    });

    test('pill keys', () {
      expect(PayStatus.paid.labelKey, 'bf_bill_status_paid');
      expect(PayStatus.review.labelKey, 'bf_bill_status_check_proof');
      expect(PayStatus.notYet.labelKey, 'bf_bill_status_not_yet');
      expect(PayStatus.review.selfLabelKey, 'bf_bill_status_waiting');
    });
  });

  group('collectionSummary', () {
    test('2.0 bill: owed excludes the host, collected counts PAID only', () {
      final bill = itemizedBill();
      final reader = BillReader(bill);
      final s = collectionSummary(reader, hostId: 'omar');
      final sara = reader.shareMinorFor('sara');
      final ali = reader.shareMinorFor('ali');
      final mona = reader.shareMinorFor('mona');
      expect(s.owedMinor, sara + ali + mona);
      expect(s.owedMinor, reader.totalMinor - reader.shareMinorFor('omar'));
      expect(s.collectedMinor, sara);
      expect(s.reviewMinor, ali);
      expect(s.outstandingMinor, ali + mona);
      expect(s.people, 3);
      expect(s.paidPeople, 1);
      expect(s.allSettled, isFalse);
      expect(s.progress, closeTo(sara / s.owedMinor, 1e-9));
    });

    test('legacy doubles read in exact minor units', () {
      final s = collectionSummary(BillReader(legacyBill()), hostId: 'omar');
      expect(s.owedMinor, 2000);
      expect(s.collectedMinor, 1000);
      expect(s.percent, 50);
    });

    test('settled when everybody paid; nothing owed when host is alone', () {
      final bill = legacyBill();
      (bill['participants'] as List)[2]['status'] = 'PAID';
      final s = collectionSummary(BillReader(bill), hostId: 'omar');
      expect(s.allSettled, isTrue);
      expect(s.progress, 1);

      final alone = collectionSummary(
        BillReader({
          'currency': 'USD',
          'participants': [
            {'id': 'omar', 'shareMinor': 500},
          ],
        }),
        hostId: 'omar',
      );
      expect(alone.owedMinor, 0);
      expect(alone.allSettled, isFalse);
      expect(alone.progress, 0);
    });
  });

  test('nextToRemind skips host, paid and proof-in-review people', () {
    final reader = BillReader(itemizedBill());
    expect(nextToRemind(reader, hostId: 'omar')?['id'], 'mona');
    final bill = legacyBill();
    (bill['participants'] as List)[2]['status'] = 'REVIEW';
    expect(nextToRemind(BillReader(bill), hostId: 'omar'), isNull);
  });

  test('initialsOf', () {
    expect(initialsOf('Omar Mahmoud'), 'OM');
    expect(initialsOf('sara'), 'S');
    expect(initialsOf('  '), '?');
    expect(initialsOf(null), '?');
    expect(initialsOf('سارة علي'), 'سع');
  });

  group('breakdownLineCopy', () {
    test('units, split and quantity items', () {
      final units = breakdownLineCopy(
        const BreakdownLine(
          kind: BreakdownKind.item,
          amountMinor: 300,
          label: 'Lemon mint',
          units: 1,
          quantity: 3,
        ),
      );
      expect(units.key, 'bf_bill_line_item_units');
      expect(units.args, {'item': 'Lemon mint', 'units': '1', 'qty': '3'});

      final split = breakdownLineCopy(
        const BreakdownLine(
          kind: BreakdownKind.item,
          amountMinor: 300,
          label: 'Fries',
          sharedWith: 2,
          quantity: 1,
        ),
      );
      expect(split.key, 'bf_bill_line_item_split');
      expect(split.args['count'], '2');

      final plain = breakdownLineCopy(
        const BreakdownLine(
          kind: BreakdownKind.item,
          amountMinor: 1400,
          label: 'Beef burger',
          sharedWith: 1,
          quantity: 1,
        ),
      );
      expect(plain.raw, 'Beef burger');
    });

    test('charges', () {
      expect(
        breakdownLineCopy(
          const BreakdownLine(kind: BreakdownKind.tax, amountMinor: 1),
        ).key,
        'bf_bill_line_tax',
      );
      final other = breakdownLineCopy(
        const BreakdownLine(
          kind: BreakdownKind.other,
          amountMinor: 1,
          label: 'Cover',
        ),
      );
      expect(other.key, 'bf_bill_line_other');
      expect(other.args['label'], 'Cover');
      expect(
        breakdownLineCopy(
          const BreakdownLine(kind: BreakdownKind.adjustment, amountMinor: 1),
        ).key,
        'bf_bill_line_adjustment',
      );
    });
  });

  test('relativeTimeCopy', () {
    final now = DateTime(2026, 11, 5, 12);
    expect(
      relativeTimeCopy(now.subtract(const Duration(seconds: 20)), now).key,
      'bf_bill_time_just_now',
    );
    final mins = relativeTimeCopy(
      now.subtract(const Duration(minutes: 2)),
      now,
    );
    expect(mins.key, 'bf_bill_time_minutes');
    expect(mins.args['count'], '2');
    expect(
      relativeTimeCopy(now.subtract(const Duration(hours: 5)), now).key,
      'bf_bill_time_hours',
    );
    final days = relativeTimeCopy(now.subtract(const Duration(days: 3)), now);
    expect(days.key, 'bf_bill_time_days');
    expect(days.args['count'], '3');
  });

  test('billErrorKey never leaks raw errors', () {
    FirebaseException fx(String code) =>
        FirebaseException(plugin: 'cloud_firestore', code: code);
    expect(billErrorKey(fx('unavailable')), 'bf_bill_error_offline');
    expect(isOfflineError(fx('unavailable')), isTrue);
    expect(billErrorKey(fx('permission-denied')), 'bf_bill_error_permission');
    expect(billErrorKey(fx('not-found')), 'bf_bill_error_not_found');
    expect(billErrorKey(fx('aborted')), 'bf_bill_error_conflict');
    expect(billErrorKey(Exception('boom')), 'bf_bill_error_generic');
    expect(billErrorKey(StateError('x')), 'bf_bill_error_generic');
  });

  test('updateParticipant targets by id and keeps others', () {
    final list = [
      {'id': 'a', 'status': 'PENDING'},
      {'id': 'b', 'status': 'PENDING'},
    ];
    final out = updateParticipant(list, 'b', (p) => {...p, 'status': 'PAID'});
    expect(out[0]['status'], 'PENDING');
    expect(out[1]['status'], 'PAID');
    expect(list[1]['status'], 'PENDING', reason: 'input untouched');
    expect(() => updateParticipant(list, 'zz', (p) => p), throwsStateError);
  });

  test('historyChangeKey', () {
    expect(historyChangeKey('item_price'), 'bf_bill_history_item_price');
    expect(historyChangeKey('whatever'), 'bf_bill_history_edited');
  });

  test('rejectProof clears the proof and sets the share back to unpaid', () {
    final out = rejectProof({
      'id': 'ali',
      'name': 'Ali',
      'status': 'REVIEW',
      'paymentProof': 'data:image/png;base64,AAAA',
      'paymentMethod': 'InstaPay',
      'paymentTime': 1,
    });
    expect(out['status'], 'PENDING');
    expect(out['isPaid'], false);
    expect(out.containsKey('paymentProof'), isFalse);
    expect(out.containsKey('paymentMethod'), isFalse);
    expect(out['name'], 'Ali');
    expect(payStatusOf(out), PayStatus.notYet);
  });
}
