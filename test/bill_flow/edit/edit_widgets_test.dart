import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/screens/completed_bills_screen.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/history_card.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/money_text.dart';

Widget _app(Widget child, {bool dark = false}) => MaterialApp(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _en = {
  'bf_edit_history_you': 'You',
  'bf_edit_history_someone': 'Someone',
  'bf_edit_history_item_price': 'changed {item} from {from} to {to}',
  'bf_edit_history_marked_paid_self': 'marked their share paid',
  'bf_edit_history_created': 'created the bill',
  'bf_edit_history_empty': 'No changes yet',
  'bf_edit_time_hours': '{count} h ago',
};

String english(String key, Map<String, String> args) {
  var s = _en[key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', v));
  return s;
}

String _plain(String s) => s.replaceAll(RegExp('[\u2066\u2069]'), '');

void main() {
  group('BillHistoryCard', () {
    final now = DateTime(2026, 11, 5, 12);
    final entries = [
      BillHistoryEntry(
        by: 'me',
        byName: 'Omar',
        at: now.subtract(const Duration(hours: 2)),
        change: 'item_price',
        args: const {'item': 'Kunafa', 'from': 600, 'to': 700},
      ),
      BillHistoryEntry(
        by: 'ali',
        byName: 'Ali',
        at: now.subtract(const Duration(hours: 1)),
        change: 'marked_paid',
      ),
      BillHistoryEntry(
        by: 'me',
        at: now.subtract(const Duration(hours: 3)),
        change: 'created',
      ),
    ];

    testWidgets('renders the board lines in order', (tester) async {
      await tester.pumpWidget(
        _app(
          BillHistoryCard(
            entries: entries,
            currentUid: 'me',
            currency: 'USD',
            now: now,
            translate: english,
          ),
        ),
      );
      expect(
        find.text('You changed Kunafa from 6.00 to 7.00 · 2 h ago'),
        findsOneWidget,
      );
      expect(
        find.text('Ali marked their share paid · 1 h ago'),
        findsOneWidget,
      );
      expect(find.text('You created the bill · 3 h ago'), findsOneWidget);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
          .toList();
      expect(texts.first, startsWith('You changed Kunafa'));
      expect(texts.last, startsWith('You created'));
    });

    testWidgets('empty history and default (key) translations', (tester) async {
      await tester.pumpWidget(
        _app(
          BillHistoryCard(
            entries: const [],
            currentUid: 'me',
            currency: 'USD',
            translate: english,
          ),
        ),
      );
      expect(find.text('No changes yet'), findsOneWidget);
    });

    testWidgets('caps the number of lines', (tester) async {
      await tester.pumpWidget(
        _app(
          BillHistoryCard(
            entries: entries,
            currentUid: 'me',
            currency: 'USD',
            now: now,
            maxEntries: 1,
            translate: english,
          ),
        ),
      );
      expect(find.textContaining('created'), findsNothing);
      expect(find.textContaining('Kunafa'), findsOneWidget);
    });
  });

  group('BillListRow', () {
    BillListEntry make(Map<String, dynamic> data) =>
        BillListEntry.fromData('id', data, 'me');

    Map<String, dynamic> data({
      required String host,
      required List<Map<String, dynamic>> participants,
      String currency = 'USD',
    }) => {
      'hostId': host,
      'storeName': 'Sea Breeze Grill',
      'currency': currency,
      'date': Timestamp.fromDate(DateTime(2026, 11, 4)),
      'participants': participants,
    };

    testWidgets('owed to you: + amount in teal, date tile, people', (
      tester,
    ) async {
      final e = make(
        data(
          host: 'me',
          participants: [
            {'id': 'me', 'name': 'Omar', 'shareMinor': 1000, 'status': 'PAID'},
            {
              'id': 'ali',
              'name': 'Ali',
              'shareMinor': 5418,
              'status': 'PENDING',
            },
          ],
        ),
      );
      var tapped = false;
      await tester.pumpWidget(
        _app(BillListRow(entry: e, onTap: () => tapped = true)),
      );
      final money = tester.widget<Text>(
        find.descendant(
          of: find.byType(MoneyText),
          matching: find.byType(Text),
        ),
      );
      expect(_plain(money.data!), contains('+'));
      expect(_plain(money.data!), contains('54.18'));
      expect(money.style!.color, AppPalette.light.owed);
      expect(find.text('Sea Breeze Grill'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('NOV'), findsOneWidget);
      expect(find.textContaining('bf_bills_people'), findsOneWidget);
      await tester.tap(find.byType(BillListRow));
      expect(tapped, isTrue);
    });

    testWidgets('you owe: − amount in amber with KWD decimals, dark mode', (
      tester,
    ) async {
      final e = make(
        data(
          host: 'ali',
          currency: 'KWD',
          participants: [
            {'id': 'ali', 'name': 'Ali', 'shareMinor': 1000, 'status': 'PAID'},
            {
              'id': 'me',
              'name': 'Omar',
              'shareMinor': 12500,
              'status': 'PENDING',
            },
          ],
        ),
      );
      await tester.pumpWidget(_app(BillListRow(entry: e), dark: true));
      final money = tester.widget<Text>(
        find.descendant(
          of: find.byType(MoneyText),
          matching: find.byType(Text),
        ),
      );
      expect(_plain(money.data!), startsWith(kMinusSign));
      expect(_plain(money.data!), contains('12.500'));
      expect(money.style!.color, AppPalette.dark.owe);
      expect(find.textContaining('bf_bills_paid_by'), findsOneWidget);
    });

    testWidgets('settled bills use the neutral ink', (tester) async {
      final e = make(
        data(
          host: 'me',
          participants: [
            {'id': 'me', 'name': 'Omar', 'shareMinor': 1000, 'status': 'PAID'},
            {'id': 'ali', 'name': 'Ali', 'shareMinor': 2000, 'status': 'PAID'},
          ],
        ),
      );
      await tester.pumpWidget(_app(BillListRow(entry: e)));
      final money = tester.widget<Text>(
        find.descendant(
          of: find.byType(MoneyText),
          matching: find.byType(Text),
        ),
      );
      expect(money.style!.color, AppPalette.light.neutralAmount);
    });
  });
}
