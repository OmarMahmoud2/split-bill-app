import 'dart:math' as math;

import 'package:split_bill_app/widgets/layout/app_scaffold.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:split_bill_app/services/admin_ai_usage_service.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/money_format.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/settings/v3_settings.dart';

typedef AiUsageLoader = Future<AiUsageResult> Function(int days);

/// Formats a USD cost; [decimals] above 2 for per-user figures.
String formatUsdCost(double usd, {int decimals = 2}) {
  if (decimals <= 2) {
    return formatMoneyMinor((usd * 100).round(), 'USD');
  }
  final pattern = '#,##0.${'0' * decimals}';
  return '\$${NumberFormat(pattern, 'en').format(usd)}';
}

/// Admin-only AI usage and cost (board "AI usage and cost").
class AdminAiUsageScreen extends StatefulWidget {
  const AdminAiUsageScreen({super.key, this.loader, this.initialDays = 7});

  /// Injected for tests; defaults to [AdminAiUsageService.fetch].
  final AiUsageLoader? loader;
  final int initialDays;

  @override
  State<AdminAiUsageScreen> createState() => _AdminAiUsageScreenState();
}

class _AdminAiUsageScreenState extends State<AdminAiUsageScreen> {
  static const _ranges = [7, 30, 90];
  late int _days = widget.initialDays;
  late Future<AiUsageResult> _future = _load();

  Future<AiUsageResult> _load() {
    final loader =
        widget.loader ?? (days) => AdminAiUsageService().fetch(days: days);
    return loader(_days);
  }

  void _setDays(int days) {
    if (days == _days) return;
    setState(() {
      _days = days;
      _future = _load();
    });
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V3TopBar(
              leading: V3IconButton.back(context),
              title: 'adm3_ai_title'.tr(namedArgs: {'days': '$_days'}),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final d in _ranges)
                    V3ChoiceChip(
                      key: ValueKey('ai-range-$d'),
                      label: 'adm3_range_days'.tr(namedArgs: {'days': '$d'}),
                      selected: d == _days,
                      onTap: () => _setDays(d),
                    ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<AiUsageResult>(
                future: _future,
                builder: (context, snap) {
                  final Widget child;
                  if (snap.connectionState != ConnectionState.done) {
                    child = const _AiUsageSkeleton(key: ValueKey('loading'));
                  } else if (snap.hasError) {
                    child = ErrorState(
                      key: const ValueKey('error'),
                      onRetry: _retry,
                    );
                  } else {
                    child = KeyedSubtree(
                      key: ValueKey('result-$_days'),
                      child: _buildResult(snap.data!),
                    );
                  }
                  return AnimatedSwitcher(
                    duration: AppMotion.durationFor(context, AppMotion.medium),
                    child: child,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(AiUsageResult result) {
    return switch (result) {
      AiUsageNotDeployed() => EmptyState(
        icon: AppIcons.cloudOff,
        title: 'adm3_ai_not_deployed_title'.tr(),
        message: 'adm3_ai_not_deployed_message'.tr(),
        actionLabel: 'adm3_try_again'.tr(),
        onAction: _retry,
      ),
      AiUsageDisabled() => EmptyState(
        icon: AppIcons.toggle,
        title: 'adm3_ai_not_deployed_title'.tr(),
        message: 'adm3_ai_disabled'.tr(),
      ),
      AiUsageUnauthorized() => ErrorState(
        icon: AppIcons.lock,
        title: 'adm3_ai_unauthorized_title'.tr(),
        message: 'adm3_ai_unauthorized_message'.tr(),
        onRetry: _retry,
      ),
      AiUsageFailed() => ErrorState(onRetry: _retry),
      AiUsageLoaded(:final report) =>
        report.isEmpty
            ? EmptyState(icon: AppIcons.sparkle, title: 'adm3_ai_empty'.tr())
            : _AiUsageBody(report: report),
    };
  }
}

class _AiUsageBody extends StatelessWidget {
  const _AiUsageBody({required this.report});

  final AiUsageReport report;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final perUser = report.costPerActiveUser;
    final calls = NumberFormat.decimalPattern('en').format(report.totalCalls);
    final caption = [
      'adm3_ai_calls_caption'.tr(namedArgs: {'calls': calls}),
      if (perUser != null)
        'adm3_ai_per_user'.tr(
          namedArgs: {'amount': formatUsdCost(perUser, decimals: 3)},
        ),
    ].join(' · ');
    final daily = report.dailyCost;
    final repair = report.repairRate;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatUsdCost(report.totalCostUsd),
                key: const ValueKey('ai-total'),
                style: AppTypography.displayMedium.copyWith(
                  color: p.textPrimary,
                  fontSize: 40,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              Text(
                caption,
                style: AppTypography.bodyMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (daily.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: _CostChartCard(daily: daily),
          ),
        const SizedBox(height: 12),
        SettingsCard(
          children: [
            _FeatureHeaderRow(),
            for (final f in report.byFeature) _FeatureRow(usage: f),
          ],
        ),
        if (report.fallbackCalls > 0 || repair != null)
          _AmberNote(
            text: [
              if (report.fallbackCalls > 0)
                'adm3_ai_fallback_note'.tr(
                  namedArgs: {
                    'calls': '${report.fallbackCalls}',
                    'percent': (report.fallbackRate * 100).toStringAsFixed(0),
                  },
                ),
              if (repair != null)
                'adm3_ai_repair_note'.tr(
                  namedArgs: {'percent': (repair * 100).toStringAsFixed(0)},
                ),
            ].join(' · '),
          ),
        if (report.unpricedCalls > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'adm3_ai_unpriced_note'.tr(
                namedArgs: {'count': '${report.unpricedCalls}'},
              ),
              style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
            ),
          ),
      ],
    );
  }
}

String featureLabel(String feature) => switch (feature) {
  'receipt' => 'adm3_ai_feature_receipt'.tr(),
  'voice_assign' => 'adm3_ai_feature_voice_assign'.tr(),
  'voice_transcribe' => 'adm3_ai_feature_voice_transcribe'.tr(),
  _ => feature,
};

String _providerLabel(String provider) => switch (provider) {
  'anthropic' => 'Anthropic',
  'openai' => 'OpenAI',
  _ => provider,
};

class _FeatureHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = AppTypography.titleMedium.copyWith(
      color: context.palette.textPrimary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text('adm3_ai_col_feature'.tr(), style: style)),
          SizedBox(
            width: 64,
            child: Text(
              'adm3_ai_col_calls'.tr(),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              'adm3_ai_col_cost'.tr(),
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.usage});

  final AiFeatureUsage usage;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sub = [
      ...usage.providers.map(_providerLabel),
      ...usage.models,
    ].join(' · ');
    final num = AppTypography.amountSmall.copyWith(
      color: p.textPrimary,
      fontFeatures: AppTypography.tabularFigures,
    );
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      featureLabel(usage.feature),
                      style: AppTypography.bodyLarge.copyWith(
                        color: p.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    if (sub.isNotEmpty)
                      Text(
                        sub,
                        style: AppTypography.labelSmall.copyWith(
                          color: p.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  NumberFormat.decimalPattern('en').format(usage.calls),
                  style: num,
                  textAlign: TextAlign.end,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  formatUsdCost(usage.costUsd),
                  style: num.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmberNote extends StatelessWidget {
  const _AmberNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.oweSoft,
        borderRadius: AppRadii.rowRadius,
      ),
      child: Text(
        text,
        style: AppTypography.titleSmall.copyWith(color: p.oweInk),
      ),
    );
  }
}

class _CostChartCard extends StatelessWidget {
  const _CostChartCard({required this.daily});

  final List<MapEntry<DateTime, double>> daily;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final values = daily.map((e) => e.value).toList();
    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final locale = context.locale.toLanguageTag();
    final fmt = DateFormat.E(locale);
    return Material(
      color: p.surface,
      shape: AppRadii.cardShape(p.hairline),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Semantics(
          image: true,
          label: 'adm3_ai_chart_label'.tr(
            namedArgs: {'min': formatUsdCost(min), 'max': formatUsdCost(max)},
          ),
          child: ExcludeSemantics(
            child: Column(
              children: [
                SizedBox(
                  height: 92,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: AiCostChartPainter(
                      values: values,
                      color: p.accent,
                      grid: p.borderSubtle,
                      rtl: Directionality.of(context) == TextDirection.rtl,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      fmt.format(daily.first.key),
                      style: AppTypography.labelSmall.copyWith(
                        color: p.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      fmt.format(daily.last.key),
                      style: AppTypography.labelSmall.copyWith(
                        color: p.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple polyline of daily cost; time runs with the reading direction.
class AiCostChartPainter extends CustomPainter {
  AiCostChartPainter({
    required this.values,
    required this.color,
    required this.grid,
    this.rtl = false,
  });

  final List<double> values;
  final Color color;
  final Color grid;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 1),
      Offset(size.width, size.height - 1),
      gridPaint,
    );
    final maxV = values.reduce(math.max);
    final top = maxV <= 0 ? 1.0 : maxV;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      var x = size.width * i / (values.length - 1);
      if (rtl) x = size.width - x;
      final y = size.height - 4 - (values[i] / top) * (size.height - 8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(AiCostChartPainter old) =>
      old.values != values || old.color != color || old.rtl != rtl;
}

class _AiUsageSkeleton extends StatelessWidget {
  const _AiUsageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          Skeleton.line(width: 160, height: 40),
          SizedBox(height: 8),
          Skeleton.line(width: 220),
          SizedBox(height: 16),
          Skeleton(height: 120, borderRadius: AppRadii.cardRadius),
          SizedBox(height: 12),
          SkeletonCard(),
        ],
      ),
    );
  }
}
