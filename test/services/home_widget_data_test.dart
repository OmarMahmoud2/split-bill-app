import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/home_widget_data.dart';

const _me = 'me';

Map<String, dynamic> _participant(
  String id,
  String name,
  num share, {
  String status = 'PENDING',
}) => {'id': id, 'name': name, 'share': share, 'status': status};

Map<String, dynamic> _bill({
  required String hostId,
  required List<Map<String, dynamic>> participants,
  String? hostName,
}) => {'hostId': hostId, 'hostName': ?hostName, 'participants': participants};

const _strings = WidgetStrings(
  youAreOwed: "You're owed",
  youOwe: 'You owe',
  allSettled: 'All settled up',
  updatedAt: 'Updated 14:32',
  scanReceipt: 'Scan a receipt',
  settleWith: 'Settle with',
  noOpenBalances: 'No open balances',
  signInPrompt: 'Sign in to see balances',
  hideAmounts: 'Hide amounts',
  showAmounts: 'Show amounts',
);

/// Strips the LTR isolate marks so expectations stay readable.
String _plain(String s) => s.replaceAll(RegExp('[\u2066\u2069]'), '');

void main() {
  group('computeWidgetBalances', () {
    test('mirrors HomeScreen totals: host is owed, participant owes', () {
      final balances = computeWidgetBalances(
        uid: _me,
        currency: 'USD',
        bills: {
          // I hosted: Sara and Ali still owe, Mona paid, my own share ignored.
          'b1': _bill(
            hostId: _me,
            participants: [
              _participant(_me, 'Me', 20),
              _participant('sara', 'Sara', 30.10),
              _participant('ali', 'Ali', 32.30, status: 'REVIEW'),
              _participant('mona', 'Mona', 15, status: 'PAID'),
            ],
          ),
          // Mona hosted, I still owe her.
          'b2': _bill(
            hostId: 'mona',
            participants: [
              _participant('mona', 'Mona', 10, status: 'PAID'),
              _participant(_me, 'Me', 24),
            ],
          ),
          // Sara hosted, I already paid: ignored.
          'b3': _bill(
            hostId: 'sara',
            participants: [_participant(_me, 'Me', 99, status: 'PAID')],
          ),
          // Another bill I hosted with Sara.
          'b4': _bill(
            hostId: _me,
            participants: [_participant('sara', 'Sara', 24)],
          ),
        },
      );

      expect(balances.owedToMeMinor, 3010 + 3230 + 2400);
      expect(balances.iOweMinor, 2400);
      expect(balances.netMinor, 6240);
      expect(balances.counterparts.map((c) => c.name), ['Sara', 'Ali', 'Mona']);
      final sara = balances.counterparts.first;
      expect(sara.netMinor, 5410);
      expect(sara.billId, 'b1', reason: 'largest open bill with Sara');
      final mona = balances.counterparts.last;
      expect(mona.netMinor, -2400);
      expect(mona.billId, 'b2');
    });

    test('nets both directions with the same person', () {
      final balances = computeWidgetBalances(
        uid: _me,
        currency: 'EUR',
        bills: {
          'a': _bill(hostId: _me, participants: [_participant('x', 'X', 10)]),
          'b': _bill(
            hostId: 'x',
            participants: [
              _participant('x', 'X', 1),
              _participant(_me, 'Me', 4),
            ],
          ),
        },
      );
      expect(balances.counterparts.single.netMinor, 600);
      expect(balances.netMinor, 600);
    });

    test('drops people who net to zero and keeps top 3', () {
      final balances = computeWidgetBalances(
        uid: _me,
        currency: 'USD',
        bills: {
          'a': _bill(
            hostId: _me,
            participants: [
              for (var i = 1; i <= 5; i++) _participant('p$i', 'P$i', i),
            ],
          ),
          'b': _bill(hostId: 'p5', participants: [_participant(_me, 'Me', 5)]),
        },
      );
      expect(balances.counterparts.map((c) => c.id), ['p4', 'p3', 'p2', 'p1']);
      expect(balances.top.map((c) => c.id), ['p4', 'p3', 'p2']);
    });

    test('uses hostName when the host is not in participants', () {
      final balances = computeWidgetBalances(
        uid: _me,
        currency: 'USD',
        bills: {
          'a': _bill(
            hostId: 'h',
            hostName: 'Omar',
            participants: [_participant(_me, 'Me', 3)],
          ),
        },
      );
      expect(balances.counterparts.single.name, 'Omar');
    });

    test('rounds shares to the currency minor units', () {
      final jpy = computeWidgetBalances(
        uid: _me,
        currency: 'jpy',
        bills: {
          'a': _bill(
            hostId: _me,
            participants: [_participant('x', 'X', 1200.4)],
          ),
        },
      );
      expect(jpy.currency, 'JPY');
      expect(jpy.netMinor, 1200);

      final kwd = computeWidgetBalances(
        uid: _me,
        currency: 'KWD',
        bills: {
          'a': _bill(
            hostId: _me,
            participants: [_participant('x', 'X', 1.2345)],
          ),
        },
      );
      expect(kwd.netMinor, 1235);
    });

    test('ignores malformed documents', () {
      final balances = computeWidgetBalances(
        uid: _me,
        currency: 'USD',
        bills: {
          'empty': {},
          'bad': {
            'hostId': _me,
            'participants': [
              'nope',
              {'id': 'x', 'status': 'PENDING'},
              {'id': 'y', 'status': 'PENDING', 'share': double.nan},
            ],
          },
        },
      );
      expect(balances.netMinor, 0);
      expect(balances.counterparts, isEmpty);
    });
  });

  group('formatting', () {
    test('signed money uses currency decimals and real minus sign', () {
      expect(_plain(formatSignedMoney(6240, 'USD', 'en')), r'+$62.40');
      expect(_plain(formatSignedMoney(-1200, 'JPY', 'en')), '\u2212¥1,200');
      expect(_plain(formatSignedMoney(1235, 'KWD', 'en')), '+KWD 1.235');
      expect(_plain(formatSignedMoney(0, 'USD', 'en')), r'$0.00');
    });

    test('row amounts have no symbol, as in the design', () {
      expect(_plain(formatSignedAmount(5410, 'USD', 'en')), '+54.10');
      expect(_plain(formatSignedAmount(-2400, 'USD', 'en')), '\u221224.00');
      expect(_plain(formatSignedAmount(-500, 'JPY', 'en')), '\u2212500');
      expect(_plain(formatSignedAmount(123456, 'EUR', 'de')), '+1.234,56');
    });

    test('amounts are isolated as LTR for RTL widgets', () {
      final s = formatSignedAmount(100, 'USD', 'ar');
      expect(s.startsWith('\u2066'), isTrue);
      expect(s.endsWith('\u2069'), isTrue);
    });

    test('rtl detection', () {
      expect(isRtlLanguage('ar'), isTrue);
      expect(isRtlLanguage('ur'), isTrue);
      expect(isRtlLanguage('en'), isFalse);
      expect(isRtlLanguage('ja'), isFalse);
    });
  });

  group('buildWidgetPayload', () {
    test('signed out has the prompt and no amounts', () {
      final json =
          jsonDecode(
                buildWidgetPayload(
                  balances: null,
                  strings: _strings,
                  locale: 'en',
                ),
              )
              as Map<String, dynamic>;
      expect(json['v'], widgetPayloadVersion);
      expect(json['state'], 'signedOut');
      expect(json['strings']['signIn'], 'Sign in to see balances');
      expect(json.containsKey('balance'), isFalse);
      expect(json.containsKey('people'), isFalse);
      expect(json['scanUrl'], 'splitbill://widget/scan?homeWidget');
    });

    test('ready payload carries label, sign, value and top people', () {
      final balances = computeWidgetBalances(
        uid: _me,
        currency: 'USD',
        bills: {
          'b1': _bill(
            hostId: _me,
            participants: [_participant('sara', 'Sara', 54.10)],
          ),
          'b2': _bill(
            hostId: 'mona',
            hostName: 'Mona',
            participants: [_participant(_me, 'Me', 60)],
          ),
        },
      );
      final json =
          jsonDecode(
                buildWidgetPayload(
                  balances: balances,
                  strings: _strings,
                  locale: 'ar',
                ),
              )
              as Map<String, dynamic>;
      expect(json['state'], 'ready');
      expect(json['dir'], 'rtl');
      final balance = json['balance'] as Map<String, dynamic>;
      expect(balance['label'], 'You owe');
      expect(balance['sign'], -1);
      expect(balance['value'], closeTo(-5.90, 1e-9));
      expect(balance['count'], 2);
      final people = json['people'] as List;
      expect(people.map((p) => p['name']), ['Mona', 'Sara']);
      expect(people.first['sign'], -1);
      final route = WidgetRoute.tryParse(Uri.parse(people.last['url']));
      expect(route, WidgetRoute.friend('sara', billId: 'b1'));
    });

    test('all settled label at zero', () {
      final balances = computeWidgetBalances(
        uid: _me,
        currency: 'USD',
        bills: const {},
      );
      final json =
          jsonDecode(
                buildWidgetPayload(
                  balances: balances,
                  strings: _strings,
                  locale: 'en',
                ),
              )
              as Map<String, dynamic>;
      expect(json['balance']['label'], 'All settled up');
      expect(json['balance']['sign'], 0);
      expect(json['people'], isEmpty);
      expect(json['dir'], 'ltr');
    });
  });

  group('WidgetRoute', () {
    test('round-trips through URIs with the homeWidget marker', () {
      final friend = WidgetRoute.friend('u 1&x', billId: 'b/2');
      final uri = friend.toUri();
      expect(uri.scheme, 'splitbill');
      expect(uri.queryParameters.containsKey('homeWidget'), isTrue);
      expect(WidgetRoute.tryParse(uri), friend);
      expect(WidgetRoute.tryParse(WidgetRoute.scan.toUri()), WidgetRoute.scan);
      expect(WidgetRoute.tryParse(WidgetRoute.home.toUri()), WidgetRoute.home);
    });

    test('parses hand-written and unknown widget URIs', () {
      expect(
        WidgetRoute.tryParse(Uri.parse('SPLITBILL://Widget/Scan')),
        WidgetRoute.scan,
      );
      expect(
        WidgetRoute.tryParse(Uri.parse('splitbill://widget/balance')),
        WidgetRoute.home,
      );
      expect(
        WidgetRoute.tryParse(Uri.parse('splitbill://widget/friend')),
        WidgetRoute.home,
        reason: 'friend without id falls back to home',
      );
      expect(
        WidgetRoute.tryParse(Uri.parse('splitbill://widget/friend?id=a')),
        WidgetRoute.friend('a'),
      );
      expect(
        WidgetRoute.tryParse(Uri.parse('splitbill://widget/whatever')),
        WidgetRoute.home,
      );
    });

    test('ignores non-widget links so bill deep links keep working', () {
      expect(
        WidgetRoute.tryParse(
          Uri.parse('https://splitbillapp-ffc39.web.app/bill/abc'),
        ),
        isNull,
      );
      expect(WidgetRoute.tryParse(Uri.parse('splitbill://bill/abc')), isNull);
      expect(WidgetRoute.tryParse(null), isNull);
    });
  });

  group('WidgetLaunchDeduper', () {
    test('drops the same URI within the window only', () {
      var now = DateTime(2026, 1, 1, 12);
      final deduper = WidgetLaunchDeduper(clock: () => now);
      final scan = WidgetRoute.scan.toUri();
      expect(deduper.shouldHandle(scan), isTrue);
      expect(deduper.shouldHandle(scan), isFalse);
      now = now.add(const Duration(seconds: 3));
      expect(deduper.shouldHandle(scan), isTrue);
      expect(deduper.shouldHandle(WidgetRoute.home.toUri()), isTrue);
    });
  });
}
