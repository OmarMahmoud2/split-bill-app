import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_bill_app/services/notification_payload.dart';
import 'package:split_bill_app/services/notification_service.dart';

void main() {
  test('a foreground notification payload round-trips to its FCM data', () {
    final data = {'billId': 'b1', 'uid': 'u2'};
    final back = decodeLocalPayload(jsonEncode(data));
    expect(back, data);
    expect(notificationTapTarget(back!), NotificationTapTarget.bill);
  });

  test('bad or empty payloads are ignored', () {
    expect(decodeLocalPayload(null), isNull);
    expect(decodeLocalPayload(''), isNull);
    expect(decodeLocalPayload('not json'), isNull);
    expect(decodeLocalPayload('[1,2]'), isNull);
  });
}
