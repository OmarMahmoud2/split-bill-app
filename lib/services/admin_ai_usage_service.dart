/// Admin AI usage analytics, read from the backend's `daily_summary`
/// aggregation (split_bill/ai_usage.py) through
/// `GET /api/split-bill/admin/ai-usage/?days=N`.
///
/// The endpoint is proposed, not deployed yet: a 404 becomes
/// [AiUsageNotDeployed] so the screen can say so instead of erroring.
library;

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:split_bill_app/config/backend_config.dart';

/// Compile-time switch for the admin AI analytics screen.
/// `--dart-define=ADMIN_AI_USAGE=false` hides the data fetch.
const bool kAdminAiUsageEnabled = bool.fromEnvironment(
  'ADMIN_AI_USAGE',
  defaultValue: true,
);

/// One `daily_summary` row: per day, feature and provider.
class AiUsageRow {
  const AiUsageRow({
    required this.day,
    required this.feature,
    required this.provider,
    required this.calls,
    this.errors = 0,
    this.errorRate = 0,
    this.fallbacks = 0,
    this.unpricedCalls = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
    this.costUsd = 0,
    this.avgLatencyMs = 0,
  });

  factory AiUsageRow.fromJson(Map<String, dynamic> json) => AiUsageRow(
    day: _date(json['day']),
    feature: (json['feature'] ?? '').toString(),
    provider: (json['provider'] ?? '').toString(),
    calls: _int(json['calls']),
    errors: _int(json['errors']),
    errorRate: _double(json['error_rate']),
    fallbacks: _int(json['fallbacks']),
    unpricedCalls: _int(json['unpriced_calls']),
    inputTokens: _int(json['input_tokens']),
    outputTokens: _int(json['output_tokens']),
    cacheReadTokens: _int(json['cache_read_tokens']),
    cacheWriteTokens: _int(json['cache_write_tokens']),
    costUsd: _double(json['cost_usd']),
    avgLatencyMs: _int(json['avg_latency_ms']),
  );

  final DateTime? day;
  final String feature;
  final String provider;
  final int calls;
  final int errors;
  final double errorRate;
  final int fallbacks;
  final int unpricedCalls;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
  final double costUsd;
  final int avgLatencyMs;
}

/// Totals for one feature across the period.
class AiFeatureUsage {
  AiFeatureUsage(this.feature);

  final String feature;
  final Set<String> providers = {};
  final Set<String> models = {};
  int calls = 0;
  int errors = 0;
  int fallbacks = 0;
  double costUsd = 0;
}

/// The whole response.
class AiUsageReport {
  AiUsageReport({
    required this.days,
    required this.rows,
    this.start,
    this.end,
    this.activeUsers,
    this.modelsByFeature = const {},
    this.stageCalls = const {},
  });

  factory AiUsageReport.fromJson(Map<String, dynamic> json, {int? days}) {
    final rawRows = json['rows'];
    final rows = <AiUsageRow>[
      if (rawRows is List)
        for (final r in rawRows)
          if (r is Map) AiUsageRow.fromJson(Map<String, dynamic>.from(r)),
    ];
    final models = <String, List<String>>{};
    final rawModels = json['models'];
    if (rawModels is Map) {
      rawModels.forEach((k, v) {
        if (v is List) models[k.toString()] = [for (final m in v) '$m'];
      });
    }
    final stages = <String, int>{};
    final rawStages = json['stages'];
    if (rawStages is Map) {
      rawStages.forEach((k, v) => stages[k.toString()] = _int(v));
    }
    return AiUsageReport(
      days: _int(json['days'] ?? days ?? 7).clamp(1, 366),
      rows: rows,
      start: _date(json['start']),
      end: _date(json['end']),
      activeUsers: json['active_users'] == null
          ? null
          : _int(json['active_users']),
      modelsByFeature: models,
      stageCalls: stages,
    );
  }

  final int days;
  final List<AiUsageRow> rows;
  final DateTime? start;
  final DateTime? end;

  /// Distinct `uid_hash` values with at least one call, when sent.
  final int? activeUsers;

  /// Optional `{feature: [model, ...]}`.
  final Map<String, List<String>> modelsByFeature;

  /// Optional `{stage: calls}`, e.g. `extract`, `repair`, `assign`.
  final Map<String, int> stageCalls;

  int get totalCalls => rows.fold(0, (s, r) => s + r.calls);
  double get totalCostUsd => rows.fold(0.0, (s, r) => s + r.costUsd);
  int get fallbackCalls => rows.fold(0, (s, r) => s + r.fallbacks);
  int get unpricedCalls => rows.fold(0, (s, r) => s + r.unpricedCalls);
  int get errorCalls => rows.fold(0, (s, r) => s + r.errors);
  bool get isEmpty => totalCalls == 0;

  /// Share of calls that went to the fallback provider, 0..1.
  double get fallbackRate => totalCalls == 0 ? 0 : fallbackCalls / totalCalls;

  /// Share of receipt scans that needed a repair pass, 0..1; null when the
  /// response has no stage breakdown.
  double? get repairRate {
    final repair = stageCalls['repair'];
    final extract = stageCalls['extract'];
    if (repair == null || extract == null || extract == 0) return null;
    return repair / extract;
  }

  /// Cost per active user, when [activeUsers] is known and non-zero.
  double? get costPerActiveUser => (activeUsers == null || activeUsers == 0)
      ? null
      : totalCostUsd / activeUsers!;

  /// Per-feature totals, most expensive first.
  List<AiFeatureUsage> get byFeature {
    final map = <String, AiFeatureUsage>{};
    for (final r in rows) {
      final f = map.putIfAbsent(r.feature, () => AiFeatureUsage(r.feature));
      f.providers.add(r.provider);
      f.calls += r.calls;
      f.errors += r.errors;
      f.fallbacks += r.fallbacks;
      f.costUsd += r.costUsd;
    }
    for (final f in map.values) {
      f.models.addAll(modelsByFeature[f.feature] ?? const []);
    }
    return map.values.toList()..sort((a, b) {
      final c = b.costUsd.compareTo(a.costUsd);
      return c != 0 ? c : b.calls.compareTo(a.calls);
    });
  }

  /// Cost per calendar day, oldest first, one entry per day of the period
  /// (days without calls are 0).
  List<MapEntry<DateTime, double>> get dailyCost {
    final totals = <DateTime, double>{};
    for (final r in rows) {
      final d = r.day;
      if (d == null) continue;
      totals[d] = (totals[d] ?? 0) + r.costUsd;
    }
    final last =
        end ??
        (totals.keys.isEmpty
            ? null
            : totals.keys.reduce((a, b) => a.isAfter(b) ? a : b));
    if (last == null) return const [];
    final first = start ?? last.subtract(Duration(days: days - 1));
    final out = <MapEntry<DateTime, double>>[];
    for (
      var d = DateTime.utc(first.year, first.month, first.day);
      !d.isAfter(last);
      d = d.add(const Duration(days: 1))
    ) {
      out.add(MapEntry(d, totals[d] ?? 0));
    }
    return out;
  }
}

/// Outcome of [AdminAiUsageService.fetch].
sealed class AiUsageResult {
  const AiUsageResult();
}

class AiUsageLoaded extends AiUsageResult {
  const AiUsageLoaded(this.report);
  final AiUsageReport report;
}

/// 404: the backend hasn't shipped the endpoint yet.
class AiUsageNotDeployed extends AiUsageResult {
  const AiUsageNotDeployed();
}

/// 401/403, or no signed-in user: the server didn't accept the caller.
class AiUsageUnauthorized extends AiUsageResult {
  const AiUsageUnauthorized();
}

/// The build has the feature flag off.
class AiUsageDisabled extends AiUsageResult {
  const AiUsageDisabled();
}

class AiUsageFailed extends AiUsageResult {
  const AiUsageFailed(this.reason);
  final String reason;
}

typedef IdTokenProvider = Future<String?> Function();

class AdminAiUsageService {
  AdminAiUsageService({
    http.Client? client,
    IdTokenProvider? idToken,
    this.enabled = kAdminAiUsageEnabled,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client,
       _idToken = idToken ?? _firebaseIdToken;

  final http.Client? _client;
  final IdTokenProvider _idToken;
  final bool enabled;
  final Duration timeout;

  static Future<String?> _firebaseIdToken() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  Future<AiUsageResult> fetch({int days = 7}) async {
    if (!enabled) return const AiUsageDisabled();
    final String? token;
    try {
      token = await _idToken();
    } catch (e) {
      return AiUsageFailed('token: $e');
    }
    if (token == null || token.isEmpty) return const AiUsageUnauthorized();

    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(
            BackendConfig.adminAiUsageUri(days: days),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);
      switch (response.statusCode) {
        case 200:
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map) {
            return AiUsageLoaded(
              AiUsageReport.fromJson(
                Map<String, dynamic>.from(decoded),
                days: days,
              ),
            );
          }
          if (decoded is List) {
            // Bare daily_summary list.
            return AiUsageLoaded(
              AiUsageReport.fromJson({'rows': decoded}, days: days),
            );
          }
          return const AiUsageFailed('unexpected body');
        case 404:
          return const AiUsageNotDeployed();
        case 401:
        case 403:
          return const AiUsageUnauthorized();
        default:
          return AiUsageFailed('HTTP ${response.statusCode}');
      }
    } on TimeoutException {
      return const AiUsageFailed('timeout');
    } on FormatException catch (e) {
      return AiUsageFailed('bad json: ${e.message}');
    } catch (e) {
      return AiUsageFailed('$e');
    } finally {
      if (_client == null) client.close();
    }
  }
}

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse('${v ?? ''}') ?? 0;
}

double _double(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

DateTime? _date(Object? v) {
  if (v == null) return null;
  final parsed = DateTime.tryParse(v.toString());
  if (parsed == null) return null;
  return DateTime.utc(parsed.year, parsed.month, parsed.day);
}
