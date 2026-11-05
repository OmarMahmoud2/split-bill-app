import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/data/ledger_math.dart';

import 'fixtures.dart';

/// Rule under test: in a group, settle-up payments are the source of truth;
/// a bill share's PAID status must not be subtracted again. Outside groups
/// PAID status still removes the share.
void main() {
  group('settlement vs PAID status (no double counting)', () {
    final g = ledgerGroup('g', ['o', 'a']);

    test('group: payment then host marks PAID leaves the group settled', () {
      final input = GroupLedgerInput(
        group: g,
        bills: [bill('b', 'o', {'o': 1000, 'a': 1000}, paid: {'a'}, groupId: 'g')],
        payments: [pay('p', 'a', 'o', 1000, groupId: 'g')],
      );
      expect(input.view.isSettled, isTrue);
      final s = buildCounterparties(me: 'o', groups: [input]);
      expect(s.person('a')?.net ?? {}, isEmpty);
      expect(s.net, isEmpty);
    });

    test('group: payment while still PENDING is also settled', () {
      final input = GroupLedgerInput(
        group: g,
        bills: [bill('b', 'o', {'o': 1000, 'a': 1000}, groupId: 'g')],
        payments: [pay('p', 'a', 'o', 1000, groupId: 'g')],
      );
      expect(input.view.isSettled, isTrue);
    });

    test('group: partial payment keeps the remainder after PAID', () {
      final input = GroupLedgerInput(
        group: g,
        bills: [bill('b', 'o', {'o': 1000, 'a': 1000}, paid: {'a'}, groupId: 'g')],
        payments: [pay('p', 'a', 'o', 400, groupId: 'g')],
      );
      expect(buildCounterparties(me: 'o', groups: [input]).person('a')!.net, {'USD': 600});
    });

    test('outside a group PAID still removes the share', () {
      final s = buildCounterparties(
        me: 'o',
        looseBills: [bill('b', 'o', {'o': 1000, 'a': 1000}, paid: {'a'})],
      );
      expect(s.net, isEmpty);
    });
  });
}
