import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_bill_app/services/admin_account_api.dart';

void main() {
  test('posts disabled and reason with the bearer token', () async {
    late http.Request seen;
    final client = MockClient((r) async {
      seen = r;
      return http.Response('{"success": true}', 200);
    });

    final ok = await disableAccountViaBackend(
      'u 1',
      disabled: true,
      reason: ' spam ',
      client: client,
      idToken: () async => 'tok',
    );

    expect(ok, isTrue);
    expect(seen.url.path, '/api/split-bill/admin/users/u%201/disable');
    expect(seen.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(seen.body), {'disabled': true, 'reason': 'spam'});
  });

  test('false on refusal, network error or missing token', () async {
    expect(
      await disableAccountViaBackend(
        'u1',
        disabled: true,
        client: MockClient((_) async => http.Response('{}', 404)),
        idToken: () async => 'tok',
      ),
      isFalse,
    );
    expect(
      await disableAccountViaBackend(
        'u1',
        disabled: true,
        client: MockClient((_) async => throw http.ClientException('offline')),
        idToken: () async => 'tok',
      ),
      isFalse,
    );
    expect(
      await disableAccountViaBackend(
        'u1',
        disabled: true,
        client: MockClient((_) async => http.Response('{}', 200)),
        idToken: () async => null,
      ),
      isFalse,
    );
  });
}
