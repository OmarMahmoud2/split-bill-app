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

  test('"Say it" is registered', () {
    expect(BillEntryPoints.voice, isNotNull);
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
