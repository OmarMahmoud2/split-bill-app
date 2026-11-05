import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:split_bill_app/data/activity.dart';
import 'package:split_bill_app/data/insights.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/data/nudge_service.dart';

import 'fixtures.dart';

void main() {
  group('activity', () {
    test('bills read as owe for an unpaid participant, neutral for the host', () {
      final b = bill('b', 'sara', {'sara': 1200, 'me': 1200});
      final mine = activityFromBill(b, 'me');
      expect(mine.tone, ActivityTone.owe);
      expect(mine.amountMinor, 1200);
      expect(mine.signedMinor, -1200);
      final host = activityFromBill(b, 'sara');
      expect(host.tone, ActivityTone.neutral);
      expect(host.amountMinor, 2400);
    });

    test('payments to me are owed-tone, mine are neutral', () {
      expect(activityFromPayment(pay('p', 'ali', 'me', 300), 'me').tone, ActivityTone.owed);
      expect(activityFromPayment(pay('p', 'me', 'ali', 300), 'me').tone, ActivityTone.neutral);
      final iou = activityFromPayment(pay('i', 'me', 'ali', 300, kind: PaymentKind.iou), 'me');
      expect(iou.kind, ActivityKind.iou);
      expect(iou.tone, ActivityTone.owe);
    });

    test('mergeNewestFirst keeps order and reports what each source gave', () {
      final a = [DateTime(2026, 1, 9), DateTime(2026, 1, 5), DateTime(2026, 1, 1)];
      final b = [DateTime(2026, 1, 8), DateTime(2026, 1, 2)];
      final m = mergeNewestFirst(a, b, (d) => d, 3);
      expect(m.items, [a[0], b[0], a[1]]);
      expect(m.takenFromA, 2);
      expect(m.takenFromB, 1);
      final rest = mergeNewestFirst(a.sublist(2), b.sublist(1), (d) => d, 3);
      expect(rest.items, [b[1], a[2]]);
    });

    test('groupByDay and dayBucket', () {
      final now = DateTime(2026, 11, 5, 12);
      expect(dayBucket(DateTime(2026, 11, 5, 1), now), DayBucket.today);
      expect(dayBucket(DateTime(2026, 11, 4, 23), now), DayBucket.yesterday);
      expect(dayBucket(DateTime(2026, 10, 1), now), DayBucket.earlier);
      final items = [
        activityFromBill(bill('1', 'me', {'me': 1}, date: DateTime(2026, 11, 5, 9)), 'me'),
        activityFromBill(bill('2', 'me', {'me': 1}, date: DateTime(2026, 11, 5, 8)), 'me'),
        activityFromBill(bill('3', 'me', {'me': 1}, date: DateTime(2026, 11, 4)), 'me'),
      ];
      final days = groupByDay(items);
      expect(days.length, 2);
      expect(days.first.$2.length, 2);
    });
  });

  group('insights', () {
    test('monthly share, weeks, change and slices by group without categories', () {
      final bills = [
        bill('1', 'me', {'me': 1000, 'a': 1000}, date: DateTime(2026, 10, 2), groupId: 'g'),
        bill('2', 'a', {'me': 500, 'a': 500}, date: DateTime(2026, 10, 16)),
        bill('3', 'a', {'me': 9999}, date: DateTime(2026, 10, 16), currency: 'EGP'),
        bill('4', 'me', {'me': 3000}, date: DateTime(2026, 9, 10)),
      ];
      final i = computeInsights(me: 'me', month: DateTime(2026, 10, 20), currency: 'usd', bills: bills);
      expect(i.totalMinor, 1500);
      expect(i.billCount, 2);
      expect(i.weekly, [1000, 0, 500, 0, 0]);
      expect(i.peakWeek, 0);
      expect(i.changeVsPrevious, closeTo(-0.5, 1e-9));
      expect(i.byCategory, isFalse);
      expect(i.slices.map((s) => s.key), ['g', '']);
      expect(i.otherCurrencies, {'EGP'});
    });

    test('payback speed from payments that reference a bill', () {
      final b1 = bill('1', 'me', {'me': 10, 'a': 10}, date: DateTime(2026, 10, 1));
      final b2 = bill('2', 'me', {'me': 10, 'm': 10}, date: DateTime(2026, 10, 1));
      PaymentRecord p(String from, String billId, int days) => PaymentRecord(
        id: '$from$billId',
        from: from,
        fromName: from.toUpperCase(),
        to: 'me',
        amountMinor: 10,
        currency: 'USD',
        createdBy: from,
        billId: billId,
        createdAt: DateTime(2026, 10, 1).add(Duration(days: days)),
      );
      final i = computeInsights(
        me: 'me',
        month: DateTime(2026, 10),
        currency: 'USD',
        bills: [b1, b2],
        payments: [p('a', '1', 2), p('m', '2', 6)],
      );
      expect(i.paybackDays, 4);
      expect(i.slowestPayer!.name, 'M');
      expect(i.slowestPayer!.days, 6);
    });

    test('totalsByCurrency keeps original currencies', () {
      expect(
        totalsByCurrency([
          bill('1', 'a', {'a': 100}),
          bill('2', 'a', {'a': 50}, currency: 'EGP'),
          bill('3', 'a', {'a': 25}),
        ]),
        {'USD': 125, 'EGP': 50},
      );
    });
  });

  group('NudgeService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sends once, then blocks for 7 days', () async {
      var now = DateTime(2026, 11, 1);
      final sent = <String>[];
      final service = NudgeService(
        clock: () => now,
        sender: ({required targetUid, required billId, required title, required body, required args}) async {
          sent.add('$targetUid:$billId');
          return true;
        },
      );
      final b = bill('b1', 'me', {'me': 100, 'ali': 100});
      expect(await service.nudge(targetId: 'ali', bill: b, title: 't', body: 'b'), NudgeResult.sent);
      expect(sent, ['ali:b1']);
      now = now.add(const Duration(days: 3));
      expect(await service.nudge(targetId: 'ali', bill: b, title: 't', body: 'b'), NudgeResult.tooSoon);
      expect(await service.nextAllowedAt('ali'), DateTime(2026, 11, 8));
      now = now.add(const Duration(days: 5));
      expect(await service.nudge(targetId: 'ali', bill: b, title: 't', body: 'b'), NudgeResult.sent);
      expect(sent.length, 2);
    });

    test('reports no shared bill and backend failures without recording', () async {
      var ok = false;
      final service = NudgeService(
        sender: ({required targetUid, required billId, required title, required body, required args}) async => ok,
      );
      expect(await service.nudge(targetId: 'x', bill: null, title: '', body: ''), NudgeResult.noSharedBill);
      final b = bill('b', 'me', {'x': 5});
      expect(await service.nudge(targetId: 'x', bill: b, title: '', body: ''), NudgeResult.failed);
      expect(await service.lastNudgedAt('x'), isNull);
      ok = true;
      expect(await service.nudge(targetId: 'x', bill: b, title: '', body: ''), NudgeResult.sent);
    });

    test('pickNudgeBill picks the newest open bill the two share', () {
      final bills = [
        bill('old', 'me', {'ali': 100}, date: DateTime(2026, 1, 1)),
        bill('new', 'ali', {'me': 100}, date: DateTime(2026, 2, 1)),
        bill('paid', 'me', {'ali': 100}, paid: {'ali'}, date: DateTime(2026, 3, 1)),
        bill('other', 'me', {'sara': 100}, date: DateTime(2026, 4, 1)),
      ];
      expect(pickNudgeBill(bills, 'me', 'ali')!.id, 'new');
      expect(pickNudgeBill(bills, 'me', 'nobody'), isNull);
    });
  });
}
