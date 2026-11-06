import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/manual_entry_screen.dart';
import 'package:split_bill_app/scan_receipt_screen.dart';
import 'package:split_bill_app/split_bill_screen.dart';
import 'package:split_bill_app/utils/share_link_utils.dart';
import 'package:split_bill_app/widgets/home/new_sheet.dart';

void main() {
  test('groupId is carried by scan, manual entry and the assign screen', () {
    expect(const ScanReceiptScreen(groupId: 'g').groupId, 'g');
    expect(const ManualEntryScreen(groupId: 'g').groupId, 'g');
    expect(const SplitBillScreen(receiptData: {}, groupId: 'g').groupId, 'g');
  });

  test('"Say it" stays hidden until standalone voice entry exists', () {
    expect(BillEntryPoints.voice, isNull);
  });

  testWidgets('New sheet offers no "Say it" option', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showNewSheet(
              context,
              onQuickIou: () {},
              onStartGroup: () {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('new_scan_title'), findsOneWidget);
    expect(find.text('new_say_title'), findsNothing);
  });

  test('personal link uses /bill/<id>?p= and keeps ?uid= compatibility', () {
    final u = ShareLinkUtils.buildBillShareUri('b1', participantId: 'p9');
    expect(u.path, '/bill/b1');
    expect(u.queryParameters['p'], 'p9');
    expect(u.queryParameters['uid'], 'p9');
    expect(
      ShareLinkUtils.buildBillShareUrl('b1'),
      'https://splitbillapp-ffc39.web.app/bill/b1',
    );
  });
}
