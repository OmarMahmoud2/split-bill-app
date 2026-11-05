import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:split_bill_app/screens/admin/admin_overview_stats.dart';
import 'package:split_bill_app/services/admin_ai_usage_service.dart';

/// Rows shaped exactly like split_bill.ai_usage.daily_summary().
final sampleBody = {
  'days': 7,
  'start': '2026-10-30',
  'end': '2026-11-05',
  'active_users': 1000,
  'models': {
    'receipt': ['claude-sonnet-5-5'],
    'voice_assign': ['claude-haiku-5-5'],
  },
  'stages': {'extract': 100, 'repair': 6, 'assign': 40},
  'rows': [
    {
      'day': '2026-11-05',
      'feature': 'receipt',
      'provider': 'anthropic',
      'calls': 60,
      'errors': 2,
      'error_rate': 0.0333,
      'fallbacks': 0,
      'unpriced_calls': 0,
      'input_tokens': 500000,
      'output_tokens': 120000,
      'cache_read_tokens': 90000,
      'cache_write_tokens': 2000,
      'cost_usd': 2.5,
      'avg_latency_ms': 6100,
    },
    {
      'day': '2026-11-05',
      'feature': 'receipt',
      'provider': 'openai',
      'calls': 4,
      'errors': 0,
      'error_rate': 0.0,
      'fallbacks': 4,
      'unpriced_calls': 4,
      'input_tokens': 30000,
      'output_tokens': 8000,
      'cache_read_tokens': 0,
      'cache_write_tokens': 0,
      'cost_usd': 0.0,
      'avg_latency_ms': 7000,
    },
    {
      'day': '2026-11-03',
      'feature': 'voice_assign',
      'provider': 'anthropic',
      'calls': 40,
      'errors': 0,
      'error_rate': 0.0,
      'fallbacks': 0,
      'unpriced_calls': 0,
      'input_tokens': 40000,
      'output_tokens': 4000,
      'cache_read_tokens': 0,
      'cache_write_tokens': 0,
      'cost_usd': 0.25,
      'avg_latency_ms': 900,
    },
  ],
};

AdminAiUsageService _service(http.Client client, {String? token = 't0k'}) =>
    AdminAiUsageService(client: client, idToken: () async => token);

void main() {
  group('AdminAiUsageService', () {
    test('200 parses daily_summary rows and sends the bearer token', () async {
      late http.Request seen;
      final client = MockClient((req) async {
        seen = req;
        return http.Response(jsonEncode(sampleBody), 200);
      });
      final result = await _service(client).fetch(days: 7);

      expect(seen.method, 'GET');
      expect(seen.url.path, '/api/split-bill/admin/ai-usage/');
      expect(seen.url.queryParameters['days'], '7');
      expect(seen.headers['Authorization'], 'Bearer t0k');

      expect(result, isA<AiUsageLoaded>());
      final report = (result as AiUsageLoaded).report;
      expect(report.totalCalls, 104);
      expect(report.totalCostUsd, closeTo(2.75, 1e-9));
      expect(report.fallbackCalls, 4);
      expect(report.unpricedCalls, 4);
      expect(report.repairRate, closeTo(0.06, 1e-9));
      expect(report.costPerActiveUser, closeTo(0.00275, 1e-9));

      final features = report.byFeature;
      expect(features.first.feature, 'receipt');
      expect(features.first.calls, 64);
      expect(features.first.providers, {'anthropic', 'openai'});
      expect(features.first.models, {'claude-sonnet-5-5'});

      final daily = report.dailyCost;
      expect(daily.length, 7);
      expect(daily.first.key, DateTime.utc(2026, 10, 30));
      expect(daily.last.value, closeTo(2.5, 1e-9));
      expect(daily[4].value, closeTo(0.25, 1e-9)); // 3 Nov
    });

    test('a bare daily_summary list is accepted', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode(sampleBody['rows']), 200),
      );
      final result = await _service(client).fetch(days: 30);
      final report = (result as AiUsageLoaded).report;
      expect(report.days, 30);
      expect(report.activeUsers, isNull);
      expect(report.repairRate, isNull);
      expect(report.totalCalls, 104);
    });

    test('404 means the endpoint is not deployed', () async {
      final client = MockClient((_) async => http.Response('Not found', 404));
      expect(await _service(client).fetch(), isA<AiUsageNotDeployed>());
    });

    test('401 and 403 mean not authorized', () async {
      for (final code in [401, 403]) {
        final client = MockClient((_) async => http.Response('{}', code));
        expect(await _service(client).fetch(), isA<AiUsageUnauthorized>());
      }
    });

    test('no token means not authorized without a request', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      expect(
        await _service(client, token: null).fetch(),
        isA<AiUsageUnauthorized>(),
      );
      expect(called, isFalse);
    });

    test('500 and bad JSON are failures', () async {
      final c500 = MockClient((_) async => http.Response('oops', 500));
      expect(await _service(c500).fetch(), isA<AiUsageFailed>());
      final bad = MockClient((_) async => http.Response('not json', 200));
      expect(await _service(bad).fetch(), isA<AiUsageFailed>());
    });

    test('feature flag off skips the request', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final service = AdminAiUsageService(
        client: client,
        idToken: () async => 't',
        enabled: false,
      );
      expect(await service.fetch(), isA<AiUsageDisabled>());
    });
  });

  group('AdminOverviewStats', () {
    final now = DateTime(2026, 11, 5, 12);
    Map<String, dynamic> user({
      int? daysAgo,
      bool pro = false,
      bool admin = false,
      String? phone,
      String? email,
    }) => {
      if (daysAgo != null) 'createdAt': now.subtract(Duration(days: daysAgo)),
      'isPremium': pro,
      'isAdmin': admin,
      'phoneNumber': ?phone,
      'email': ?email,
    };

    test('counts the period, the period before and the funnel', () {
      final stats = AdminOverviewStats.compute(
        [
          user(daysAgo: 1, phone: '+1', pro: true),
          user(daysAgo: 3, phone: '+2'),
          user(daysAgo: 5, email: 'a@b.c'),
          user(daysAgo: 9, email: 'x@y.z'),
          user(daysAgo: 40, admin: true, email: 'admin@x.y'),
          user(),
        ],
        days: 7,
        now: now,
      );

      expect(stats.totalUsers, 6);
      expect(stats.admins, 1);
      expect(stats.proUsers, 1);
      expect(stats.newSignups, 3);
      expect(stats.previousSignups, 1);
      expect(stats.newWithPhone, 2);
      expect(stats.newPro, 1);
      expect(stats.missingContact, 1);
      expect(stats.unknownSignupDate, 1);
      expect(stats.signupChangePercent, closeTo(200, 1e-9));
      expect(stats.proSharePercent, closeTo(100 / 6, 1e-9));
    });

    test('no previous sign-ups gives no fake percentage', () {
      final stats = AdminOverviewStats.compute(
        [user(daysAgo: 1)],
        days: 7,
        now: now,
      );
      expect(stats.signupChangePercent, isNull);
      expect(
        AdminOverviewStats.compute(const [], days: 7).proSharePercent,
        isNull,
      );
    });
  });
}
