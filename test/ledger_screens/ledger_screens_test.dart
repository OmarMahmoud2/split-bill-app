import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/data/activity.dart';
import 'package:split_bill_app/data/ledger_math.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/data/nudge_service.dart';
import 'package:split_bill_app/payments/payments.dart';
import 'package:split_bill_app/notifications_screen.dart';
import 'package:split_bill_app/screens/activity/activity_screen.dart';
import 'package:split_bill_app/screens/groups/create_group_screen.dart';
import 'package:split_bill_app/screens/groups/group_detail_screen.dart';
import 'package:split_bill_app/screens/settle/pay_sheet.dart';
import 'package:split_bill_app/screens/settle/quick_iou_sheet.dart';
import 'package:split_bill_app/screens/settle/settle_actions.dart';
import 'package:split_bill_app/screens/settle/settle_up_screen.dart';
import 'package:split_bill_app/screens/friends/friend_detail_screen.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/home_dashboard.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';

import '../data/fixtures.dart';
import 'fake_repo.dart';

Finder textPlain(String value) =>
    find.byWidgetPredicate((w) => w is Text && w.data != null && plainText(w.data!) == value);

final trip = LedgerGroup(
  id: 'g1',
  name: 'Dahab trip',
  createdBy: 'me',
  type: GroupType.trip,
  currency: 'USD',
  budgetMinor: 120000,
  members: const [
    GroupMember(id: 'me', name: 'Omar Test'),
    GroupMember(id: 'sara', name: 'Sara'),
    GroupMember(id: 'ali', name: 'Ali'),
  ],
);

FakeLedgerRepository tripRepo({List<BillRecord>? loose}) => FakeLedgerRepository(
  groups: [trip],
  groupBills: {
    'g1': [
      bill('b1', 'me', {'me': 3000, 'sara': 3000, 'ali': 3000}, groupId: 'g1'),
    ],
  },
  recentBills: loose ?? [bill('l1', 'mona', {'mona': 1000, 'me': 2400})],
);

HomeActions noActions() => HomeActions(
  onNew: () {},
  onQuickIou: () {},
  onStartGroup: () {},
  onOpenGroups: () {},
  onOpenActivity: () {},
  onOpenProfile: () {},
  onOpenNotifications: () {},
);

void main() {
  late FakeLedgerRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LedgerMe.debugOverride = me;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    AppToast.hide();
    LedgerMe.debugOverride = null;
  });

  group('Home', () {
    for (final dark in [false, true]) {
      testWidgets('net balance, settle with and groups (${dark ? 'dark' : 'light'})', (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        repo = tripRepo();
        LedgerRepository.instance = repo;
        final stream = watchHomeLedger(repo, 'me');
        await tester.pumpWidget(testApp(HomeDashboard(stream: stream, actions: noActions(), onRetry: () {}), dark: dark));
        await tester.pumpAndSettle();
        // me: +60.00 from the trip, −24.00 to Mona.
        expect(textPlain('+\$36.00'), findsOneWidget);
        expect(find.text('home_owed_overall'), findsOneWidget);
        expect(find.text('Sara'), findsWidgets);
        expect(find.text('MONA'), findsOneWidget);
        expect(textPlain('−\$24.00'), findsWidgets);
        expect(find.text('Dahab trip'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('first-day empty state', (tester) async {
      repo = FakeLedgerRepository();
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(HomeDashboard(stream: watchHomeLedger(repo, 'me'), actions: noActions(), onRetry: () {})));
      await tester.pumpAndSettle();
      expect(find.text('home_first_title'), findsOneWidget);
      expect(find.text('new_scan_title'), findsOneWidget);
    });

    testWidgets('lays out right to left', (tester) async {
      repo = tripRepo();
      LedgerRepository.instance = repo;
      await tester.pumpWidget(
        testApp(HomeDashboard(stream: watchHomeLedger(repo, 'me'), actions: noActions(), onRetry: () {}), direction: TextDirection.rtl),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(textPlain('+\$36.00'), findsOneWidget);
    });

    testWidgets('hero says all square when nothing is open', (tester) async {
      repo = FakeLedgerRepository(recentBills: [bill('l1', 'me', {'me': 1000, 'mona': 1000}, paid: {'mona'})]);
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(HomeDashboard(stream: watchHomeLedger(repo, 'me'), actions: noActions(), onRetry: () {})));
      await tester.pumpAndSettle();
      expect(find.text('home_all_square'), findsOneWidget);
      expect(find.text('settle_up_title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hero says you owe overall', (tester) async {
      repo = FakeLedgerRepository(recentBills: [bill('l1', 'mona', {'mona': 1000, 'me': 2400})]);
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(HomeDashboard(stream: watchHomeLedger(repo, 'me'), actions: noActions(), onRetry: () {})));
      await tester.pumpAndSettle();
      expect(find.text('home_owe_overall'), findsOneWidget);
      expect(textPlain('−\$24.00'), findsWidgets);
    });

    testWidgets('hero amount never clips in RTL on a narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      repo = FakeLedgerRepository(recentBills: [bill('l1', 'me', {'me': 100, 'mona': 987654321})]);
      LedgerRepository.instance = repo;
      await tester.pumpWidget(
        testApp(HomeDashboard(stream: watchHomeLedger(repo, 'me'), actions: noActions(), onRetry: () {}), direction: TextDirection.rtl),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rect = tester.getRect(textPlain('+\$9,876,543.21').first);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    });

    test('recentActivity merges bills and payments, newest first', () {
      final s = HomeLedgerState(
        groups: const [],
        groupInputs: const [],
        recentBills: [bill('a', 'me', {'me': 1, 'x': 1}, date: DateTime(2026, 1, 1))],
        directPayments: [
          PaymentRecord(id: 'p', from: 'x', to: 'me', amountMinor: 1, currency: 'USD', createdBy: 'x', createdAt: DateTime(2026, 2, 1)),
        ],
        summary: BalanceSummary(me: 'me', people: const []),
      );
      final items = recentActivity(s, 'me');
      expect(items.map((i) => i.kind), [ActivityKind.payment, ActivityKind.billAdded]);
    });
  });

  group('Settle up', () {
    testWidgets('records cash for the last payment and celebrates the group', (tester) async {
      repo = FakeLedgerRepository(
        groups: [trip],
        groupBills: {
          'g1': [bill('b1', 'me', {'me': 1000, 'ali': 1000}, groupId: 'g1')],
        },
      );
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(const SettleUpScreen.group(groupId: 'g1')));
      await tester.pumpAndSettle();
      expect(find.text('settle_one_payment_settles'), findsOneWidget);
      await tester.tap(find.text('settle_record_cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('settle_mark_paid'));
      await tester.pumpAndSettle();
      expect(repo.recorded.single.from, 'ali');
      expect(repo.recorded.single.to, 'me');
      expect(repo.recorded.single.amountMinor, 1000);
      expect(repo.recorded.single.groupId, 'g1');
      expect(repo.recorded.single.method, 'cash');
      expect(find.byType(SuccessScreen), findsOneWidget);
      expect(find.text('settle_everyone_square'), findsOneWidget);
      // Always a way out, with share and archive as optional extras.
      expect(find.text('done'), findsOneWidget);
      expect(find.text('settle_share_recap'), findsOneWidget);
      await tester.tap(find.text('done'));
      await tester.pumpAndSettle();
      expect(find.byType(SuccessScreen), findsNothing);
    });

    testWidgets('shows fewest payments vs the naive count', (tester) async {
      repo = FakeLedgerRepository(
        groups: [trip],
        groupBills: {
          'g1': [
            bill('1', 'me', {'ali': 1000}, groupId: 'g1'),
            bill('2', 'ali', {'sara': 1000}, groupId: 'g1'),
          ],
        },
      );
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(const SettleUpScreen.group(groupId: 'g1')));
      await tester.pumpAndSettle();
      expect(find.text('settle_one_payment_settles'), findsOneWidget);
      expect(find.text('settle_instead_of'), findsOneWidget);
      expect(find.text('settle_nudge_name'), findsOneWidget);
    });

    testWidgets('a failed write shows an error toast and records nothing', (tester) async {
      repo = FakeLedgerRepository(
        groups: [trip],
        groupBills: {
          'g1': [bill('b1', 'ali', {'ali': 1000, 'me': 1000}, groupId: 'g1')],
        },
      )..failWrites = true;
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(const SettleUpScreen.group(groupId: 'g1')));
      await tester.pumpAndSettle();
      expect(find.text('settle_pay_name'), findsOneWidget);
      await tester.tap(find.text('settle_record_cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('settle_mark_paid'));
      await tester.pumpAndSettle();
      expect(repo.recorded, isEmpty);
      expect(find.text('settle_record_failed'), findsOneWidget);
    });

    test('friendSettleRows turns contexts into transfers', () {
      final c = Counterparty(id: 'ali', name: 'Ali');
      final summary = buildCounterparties(
        me: 'me',
        looseBills: [bill('1', 'me', {'ali': 500}), bill('2', 'ali', {'me': 200}, currency: 'EGP')],
      );
      final rows = friendSettleRows(summary.person('ali')!, 'me');
      expect(rows.length, 2);
      expect(rows.firstWhere((r) => r.transfer.currency == 'USD').transfer.from, 'ali');
      expect(rows.firstWhere((r) => r.transfer.currency == 'EGP').transfer.from, 'me');
      expect(c.isSettled, isTrue);
    });
  });

  group('Quick IOU', () {
    test('parseAmountMinor', () {
      expect(parseAmountMinor('20', 'USD'), 2000);
      expect(parseAmountMinor('20,5', 'USD'), 2050);
      expect(parseAmountMinor('1.005', 'KWD'), 1005);
      expect(parseAmountMinor('600', 'JPY'), 600);
      expect(parseAmountMinor('0', 'USD'), isNull);
      expect(parseAmountMinor('abc', 'USD'), isNull);
      expect(parseAmountMinor('', 'USD'), isNull);
    });

    testWidgets('saves "Ali owes me" as an IOU in minor units', (tester) async {
      repo = FakeLedgerRepository();
      LedgerRepository.instance = repo;
      await tester.pumpWidget(
        testApp(const Scaffold(body: QuickIouSheet(people: [GroupMember(id: 'ali', name: 'Ali'), GroupMember(id: 'sara', name: 'Sara')]))),
      );
      await tester.tap(find.text('Ali'));
      await tester.enterText(find.byType(TextField).first, '20');
      await tester.enterText(find.byType(TextField).last, 'coffee');
      await tester.pump();
      await tester.tap(find.text('iou_cta_they_owe'));
      await tester.pumpAndSettle();
      final iou = repo.recorded.single;
      expect(iou.kind, PaymentKind.iou);
      expect(iou.from, 'ali');
      expect(iou.to, 'me');
      expect(iou.amountMinor, 2000);
      expect(iou.note, 'coffee');
      expect(iou.groupId, isNull);
    });
  });

  group('Group detail', () {
    testWidgets('budget bar, balances and tabs', (tester) async {
      repo = tripRepo();
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(const GroupDetailScreen(groupId: 'g1')));
      await tester.pumpAndSettle();
      expect(find.text('Dahab trip'), findsOneWidget);
      expect(find.text('groups_spent_of_budget'), findsOneWidget);
      expect(textPlain('\$90.00'), findsOneWidget);
      expect(textPlain('+\$60.00'), findsOneWidget);
      expect(textPlain('−\$30.00'), findsNWidgets(2));
      await tester.tap(find.text('groups_tab_bills'));
      await tester.pumpAndSettle();
      expect(find.text('b1'), findsOneWidget);
      await tester.tap(find.text('groups_tab_totals'));
      await tester.pumpAndSettle();
      expect(find.text('groups_total_spent'), findsOneWidget);
    });

    test('BudgetStatus math', () {
      final input = GroupLedgerInput(
        group: LedgerGroup(
          id: 'g',
          name: 'g',
          createdBy: 'me',
          currency: 'USD',
          budgetMinor: 120000,
          endDate: DateTime(2026, 11, 6),
          members: const [GroupMember(id: 'a', name: 'a'), GroupMember(id: 'b', name: 'b'), GroupMember(id: 'c', name: 'c'), GroupMember(id: 'd', name: 'd')],
        ),
        bills: [bill('1', 'a', {'a': 96800}, groupId: 'g')],
        payments: const [],
      );
      final s = BudgetStatus.of(input, now: DateTime(2026, 11, 6, 10))!;
      expect(s.leftMinor, 23200);
      expect(s.daysLeft, 1);
      expect(s.eachMinor, 5800);
      expect(s.fraction, closeTo(0.807, 0.001));
    });
  });

  group('Friend detail', () {
    testWidgets('shows the balance across contexts and nudges once a week', (tester) async {
      repo = tripRepo();
      LedgerRepository.instance = repo;
      final sent = <String>[];
      nudgeService = NudgeService(
        sender: ({required targetUid, required billId, required title, required body, required args}) async {
          sent.add('$targetUid/$billId');
          return true;
        },
      );
      await tester.pumpWidget(testApp(const FriendDetailScreen(friendId: 'ali')));
      await tester.pumpAndSettle();
      expect(find.text('friend_owes_you'), findsOneWidget);
      expect(textPlain('+\$30.00'), findsWidgets);
      await tester.tap(find.text('friend_nudge'));
      await tester.pumpAndSettle();
      expect(sent, ['ali/b1']);
      expect(find.text('nudge_sent'), findsOneWidget);
      AppToast.hide();
      await tester.tap(find.text('friend_nudge'));
      await tester.pumpAndSettle();
      expect(sent.length, 1);
      expect(find.text('nudge_too_soon'), findsOneWidget);
    });
  });

  group('Pay sheet', () {
    testWidgets('opens the recipient method, then records it', (tester) async {
      repo = FakeLedgerRepository(profiles: {
        'mona': {
          'customPaymentMethods': [
            {'name': 'PayPal', 'value': 'paypal.me/mona', 'type': 'paypal'},
          ],
        },
      });
      LedgerRepository.instance = repo;
      final opened = <Uri>[];
      paymentLauncher = PaymentLauncher(
        canOpen: (_) async => true,
        open: (u) async {
          opened.add(u);
          return true;
        },
        copy: (_) async {},
      );
      PaySheetResult? result;
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => result = await showPaySheet(context, recipientId: 'mona', recipientName: 'Mona', amountMinor: 2400, currency: 'USD'),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('PayPal'), findsOneWidget);
      await tester.tap(find.text('pay_open_app'));
      await tester.pumpAndSettle();
      expect(opened, isNotEmpty);
      AppToast.hide();
      await tester.tap(find.text('pay_yes_mark_paid'));
      await tester.pumpAndSettle();
      expect(result!.method, 'paypal');
    });

    testWidgets('no methods: empty state with record cash', (tester) async {
      repo = FakeLedgerRepository();
      LedgerRepository.instance = repo;
      await tester.pumpWidget(
        testApp(const Scaffold(body: PaySheet(recipientId: 'x', recipientName: 'X', amountMinor: 100, currency: 'USD'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('pay_no_methods_title'), findsOneWidget);
      expect(find.text('settle_record_cash'), findsOneWidget);
    });
  });

  group('Activity', () {
    testWidgets('groups items by day and loads the next page', (tester) async {
      final now = DateTime.now();
      repo = FakeLedgerRepository(activityPages: [
        ActivityPage([
          activityFromPayment(PaymentRecord(id: 'p', from: 'ali', fromName: 'Ali', to: 'me', amountMinor: 3024, currency: 'USD', createdBy: 'ali', createdAt: now), 'me'),
          activityFromBill(bill('b', 'sara', {'sara': 1200, 'me': 1200}, date: now.subtract(const Duration(days: 1))), 'me'),
        ], const ActivityCursor()),
        const ActivityPage([], null),
      ]);
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(const ActivityScreen(embedded: true)));
      await tester.pumpAndSettle();
      expect(find.text('activity_today'), findsOneWidget);
      expect(find.text('activity_yesterday'), findsOneWidget);
      expect(textPlain('+\$30.24'), findsOneWidget);
      expect(textPlain('−\$12.00'), findsOneWidget);
      expect(repo.activityCalls, 2);
    });

    testWidgets('empty feed', (tester) async {
      repo = FakeLedgerRepository();
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(const ActivityScreen(embedded: true)));
      await tester.pumpAndSettle();
      expect(find.text('activity_empty_title'), findsOneWidget);
    });
  });

  group('Create group', () {
    testWidgets('creates a trip with currency, budget and simplify on', (tester) async {
      repo = FakeLedgerRepository();
      LedgerRepository.instance = repo;
      await tester.pumpWidget(testApp(Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('group_type_home'));
      await tester.enterText(find.byType(TextField).at(0), 'Flat 4B');
      await tester.enterText(find.byType(TextField).at(1), '1200');
      await tester.pump();
      await tester.tap(find.text('groups_create_and_invite'));
      await tester.pumpAndSettle();
      final d = repo.created.single;
      expect(d.name, 'Flat 4B');
      expect(d.type, GroupType.home);
      expect(d.currency, 'USD');
      expect(d.budgetMinor, 120000);
      expect(d.simplifyDebts, isTrue);
      expect(d.members.single.id, 'me');
      expect(find.byType(SuccessScreen), findsOneWidget);
    });
  });

  group('Notifications', () {
    testWidgets('unread cards show a dot, read ones blend in', (tester) async {
      await tester.pumpWidget(testApp(const Scaffold(
        body: Column(children: [
          NotificationCard(title: 'Ali paid you', body: 'Check the proof', when: 'now', read: false),
          NotificationCard(title: 'Old one', body: '', when: '1 Nov', read: true, reminder: true),
        ]),
      ), dark: true));
      expect(find.text('Ali paid you'), findsOneWidget);
      expect(find.text('Old one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
