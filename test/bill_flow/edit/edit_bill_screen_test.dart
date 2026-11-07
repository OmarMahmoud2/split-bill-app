import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/edit_bill_screen.dart';
import 'package:split_bill_app/theme/theme.dart';

class _FakeStore implements EditBillStore {
  final updates = <Map<String, dynamic>>[];
  bool fail = false;

  @override
  Future<void> update(String billId, Map<String, dynamic> fields) async {
    if (fail) throw StateError('offline');
    updates.add(fields);
  }

  @override
  Future<void> delete(String billId) async {}
}

Map<String, dynamic> _bill({bool unassigned = false}) => {
  'hostId': 'host',
  'storeName': 'Sea Breeze Grill',
  'currency': 'EGP',
  'date': Timestamp.fromDate(DateTime(2026, 11, 4)),
  'items': [
    {
      'name': 'Kunafa',
      'priceMinor': 600,
      'qty': 1,
      'assignedTo': unassigned ? <String>[] : ['host', 'ali'],
    },
  ],
  'charges': {
    'minor': {'tax': 84, 'service': 72, 'tip': 0, 'delivery': 0, 'discount': 0},
  },
  'participants': [
    {'id': 'host', 'name': 'Omar', 'shareMinor': 378, 'status': 'PAID'},
    {'id': 'ali', 'name': 'Ali', 'shareMinor': 378, 'status': 'PENDING'},
  ],
  'history': [
    {
      'by': 'host',
      'byName': 'Omar',
      'at': Timestamp.fromDate(DateTime.now()),
      'change': 'created',
    },
  ],
};

Future<_FakeStore> _open(WidgetTester tester, Map<String, dynamic> data) async {
  final store = _FakeStore();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => EditBillScreen(
                  billId: 'b1',
                  billData: data,
                  store: store,
                  currentUid: 'host',
                  currentUserName: 'Omar',
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('shows the board rows and saves a rename with history', (
    tester,
  ) async {
    final store = await _open(tester, _bill());
    expect(find.text('bf_edit_title'), findsOneWidget);
    expect(find.textContaining('bfx_items'), findsOneWidget); // "1 item · 2 people" when localized
    expect(find.text('14% · 12% · —'), findsOneWidget);
    expect(find.text('EGP'), findsOneWidget);
    expect(find.textContaining('bf_edit_history_you_created'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Sea Breeze');
    await tester.tap(find.text('bf_edit_save'));
    await tester.pumpAndSettle();

    expect(store.updates, hasLength(1));
    final update = store.updates.single;
    expect(update['storeName'], 'Sea Breeze');
    expect(update['totalMinor'], 756);
    final history = (update['history'] as List).cast<Map<String, dynamic>>();
    expect(history.first['change'], 'renamed');
    expect(history.first['byName'], 'Omar');
    expect(find.byType(EditBillScreen), findsNothing, reason: 'popped');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('blocks saving an unassigned item with a friendly message', (
    tester,
  ) async {
    final store = await _open(tester, _bill(unassigned: true));
    expect(find.text('bf_edit_issue_unassigned'), findsOneWidget);
    await tester.tap(find.text('bf_edit_save'));
    await tester.pump();
    expect(store.updates, isEmpty);
    expect(find.byType(EditBillScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a failed save keeps the screen and shows no raw error', (
    tester,
  ) async {
    final data = _bill();
    final store = await _open(tester, data);
    store.fail = true;
    await tester.tap(find.text('bf_edit_save'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(EditBillScreen), findsOneWidget);
    expect(find.text('bf_edit_save_failed'), findsOneWidget);
    expect(find.textContaining('offline'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
