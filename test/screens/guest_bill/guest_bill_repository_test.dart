import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_bill_app/screens/guest_bill/guest_bill_repository.dart';

void main() {
  FirestoreGuestBillRepository repo(
    MockClient client, {
    String? token = 'id-token',
  }) => FirestoreGuestBillRepository(
    httpClient: client,
    idToken: () async => token,
  );

  test(
    'submitPayment posts the REVIEW update to the backend with the token',
    () async {
      late http.Request seen;
      final client = MockClient((request) async {
        seen = request;
        return http.Response('{"success": true}', 200);
      });

      await repo(client).submitPayment(
        billId: 'bill 1',
        participantId: 'p1',
        proofDataUrl: 'data:image/jpeg;base64,AAAA',
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/api/split-bill/bills/bill%201/guest-payment/');
      expect(seen.headers['Authorization'], 'Bearer id-token');
      expect(jsonDecode(seen.body), {
        'participantId': 'p1',
        'status': 'REVIEW',
        'proofImage': 'data:image/jpeg;base64,AAAA',
      });
    },
  );

  test('submitPayment without a proof omits proofImage', () async {
    late Map<String, dynamic> body;
    final client = MockClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    });

    await repo(client).submitPayment(billId: 'b', participantId: 'p1');

    expect(body.containsKey('proofImage'), isFalse);
    expect(body['status'], 'REVIEW');
  });

  test('submitPayment sends the payment method label when given', () async {
    late Map<String, dynamic> body;
    final client = MockClient((request) async {
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('{}', 200);
    });

    await repo(
      client,
    ).submitPayment(billId: 'b', participantId: 'p1', method: ' InstaPay ');
    expect(body['method'], 'InstaPay');

    await repo(
      client,
    ).submitPayment(billId: 'b', participantId: 'p1', method: '');
    expect(body.containsKey('method'), isFalse);
  });

  test('a backend refusal surfaces as GuestPaymentRejected', () async {
    final client = MockClient((_) async => http.Response('{}', 403));

    await expectLater(
      repo(client).submitPayment(billId: 'b', participantId: 'p1'),
      throwsA(
        isA<GuestPaymentRejected>().having((e) => e.statusCode, 'status', 403),
      ),
    );
  });

  test('no token means no request', () async {
    var called = false;
    final client = MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    });

    await expectLater(
      repo(client, token: null).submitPayment(billId: 'b', participantId: 'p1'),
      throwsStateError,
    );
    expect(called, isFalse);
  });
}
