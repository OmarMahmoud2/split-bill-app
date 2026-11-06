import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/screens/bill_link_error_screen.dart';
import 'package:split_bill_app/services/bill_link_routing.dart';

void main() {
  final bill = {
    'hostId': 'host',
    'participants': [
      {'id': 'host'},
      {'id': 'me'},
      {'id': 'guest1'},
    ],
  };

  test('host and participant resolve by uid', () {
    expect(resolveBillLinkTarget(data: bill, uid: 'host'), BillLinkTarget.host);
    expect(resolveBillLinkTarget(data: bill, uid: 'me'), BillLinkTarget.participant);
  });

  test('personal link for someone else opens that guest entry', () {
    expect(
      resolveBillLinkTarget(data: bill, uid: 'stranger', personalId: 'guest1'),
      BillLinkTarget.guestEntry,
    );
  });

  test('not on the bill and no personal link keeps the explanation screen', () {
    expect(resolveBillLinkTarget(data: bill, uid: 'stranger'), BillLinkTarget.participant);
  });

  test('missing bill is not found', () {
    expect(resolveBillLinkTarget(data: null, uid: 'me', personalId: 'x'), BillLinkTarget.notFound);
  });

  testWidgets('error screen shows the not-found state with a way back', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BillLinkErrorScreen()));
    expect(find.text('bf_bill_not_found_title'), findsOneWidget);
    expect(find.text('bf_bill_go_back'), findsOneWidget);
  });
}
