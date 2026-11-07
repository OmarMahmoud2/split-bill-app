import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_bill_app/services/added_push.dart';
import 'package:split_bill_app/services/notification_payload.dart';

void main() {
  group('newlyAddedMembers', () {
    test('new bill: everyone but me and guests', () {
      expect(
        newlyAddedMembers(
          before: const [],
          after: ['me', 'a', 'guest_1', 'b', 'a', ''],
          selfUid: 'me',
        ),
        ['a', 'b'],
      );
    });
    test('edit: only people not on the bill before', () {
      expect(
        newlyAddedMembers(
          before: ['me', 'a'],
          after: ['me', 'a', 'c', 'guest_2'],
          selfUid: 'me',
        ),
        ['c'],
      );
    });
    test('nobody new', () {
      expect(
        newlyAddedMembers(
          before: ['me', 'a'],
          after: ['me', 'a'],
          selfUid: 'me',
        ),
        isEmpty,
      );
    });
  });

  group('calls', () {
    test(
      'bill: posts the bill id with the token; skipped when nobody is new',
      () async {
        final seen = <http.Request>[];
        final client = MockClient((r) async {
          seen.add(r);
          return http.Response('{}', 200);
        });
        Future<String?> token() async => 't';
        await notifyBillAdded(
          billId: 'b1',
          selfUid: 'me',
          before: ['me'],
          after: ['me'],
          client: client,
          idToken: token,
        );
        expect(seen, isEmpty);
        await notifyBillAdded(
          billId: 'b1',
          selfUid: 'me',
          before: ['me'],
          after: ['me', 'x'],
          client: client,
          idToken: token,
        );
        expect(
          seen.single.url.path,
          '/api/split-bill/notifications/bill-added/',
        );
        expect(seen.single.headers['Authorization'], 'Bearer t');
        expect(jsonDecode(seen.single.body), {'billId': 'b1'});
      },
    );
    test('iou: failures never throw', () async {
      final client = MockClient((r) async => throw Exception('offline'));
      await notifyIouAdded(
        paymentId: 'p',
        groupId: 'g',
        client: client,
        idToken: () async => 't',
      );
    });
  });

  test('a new_iou push opens the notifications screen', () {
    expect(
      notificationTapTarget({'type': 'new_iou'}),
      NotificationTapTarget.notifications,
    );
  });
}
