/// Insights: the user's share of shared spending this month, by week, by
/// category (or by group when bills carry no category), and payback speed.
library;

import 'package:split_bill_app/widgets/layout/app_scaffold.dart';
import 'package:split_bill_app/widgets/layout/adaptive_body.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/insights.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/money_text.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key, this.state, this.month});
  final Stream<HomeLedgerState>? state;
  final DateTime? month;

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  Stream<HomeLedgerState>? _stream;
  late DateTime _month =
      widget.month ?? DateTime(DateTime.now().year, DateTime.now().month);
  LedgerMe? _me;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _me ??= LedgerMe.current();
    if (_stream == null && _me != null) {
      _stream =
          widget.state ??
          watchHomeLedger(
            LedgerRepository.instance,
            _me!.uid,
            fallbackCurrency: preferredCurrency(context),
          );
    }
  }

  void _shift(int months) {
    AppHaptics.selection();
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final title = DateFormat.yMMMM(localeTag(context)).format(_month);
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AppScaffold(
      body: AdaptiveBody(
        child: SafeArea(
          child: Column(
            children: [
              LedgerTopBar(
                title: title,
                actions: [
                  IconButton(
                    tooltip: 'insights_previous_month'.tr(),
                    icon: Icon(
                      rtl ? AppIcons.chevronRight : AppIcons.chevronLeft,
                    ),
                    onPressed: () => _shift(-1),
                  ),
                  IconButton(
                    tooltip: 'insights_next_month'.tr(),
                    icon: Icon(
                      rtl ? AppIcons.chevronLeft : AppIcons.chevronRight,
                    ),
                    onPressed: isCurrent ? null : () => _shift(1),
                  ),
                ],
              ),
              Expanded(
                child: StreamBuilder<HomeLedgerState>(
                  stream: _stream,
                  builder: (context, snap) {
                    if (snap.hasError)
                      return ErrorState(
                        onRetry: () => setState(() {
                          _stream = null;
                          didChangeDependencies();
                        }),
                      );
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: SkeletonShimmer(
                          child: Column(
                            children: [
                              SkeletonCard(),
                              SizedBox(height: 12),
                              SkeletonCard(),
                            ],
                          ),
                        ),
                      );
                    }
                    return _content(context, snap.data!);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, HomeLedgerState state) {
    final p = context.palette;
    final me = _me!.uid;
    final billsById = <String, BillRecord>{
      for (final b in state.recentBills) b.id: b,
      for (final g in state.groupInputs)
        for (final b in g.bills)
          if (b.share(me) != null) b.id: b,
    };
    final payments = [
      ...state.directPayments,
      for (final g in state.groupInputs) ...g.payments,
    ];
    final i = computeInsights(
      me: me,
      month: _month,
      currency: preferredCurrency(context),
      bills: billsById.values,
      payments: payments,
    );
    final groupNames = {for (final g in state.groups) g.id: g.name};
    if (i.billCount == 0) {
      return EmptyState(
        icon: AppIcons.insights,
        palSeeds: const ['mona', 'sara', 'ali'],
        title: 'insights_empty_title'.tr(),
        message: i.otherCurrencies.isEmpty
            ? 'insights_empty_body'.tr()
            : 'insights_other_currencies'.tr(
                namedArgs: {'codes': i.otherCurrencies.join(', ')},
              ),
      );
    }
    final change = i.changeVsPrevious;
    final bills = i.billCount == 1
        ? 'groups_one_bill'.tr()
        : 'groups_n_bills'.tr(namedArgs: {'count': '${i.billCount}'});
    final changeText = change == null
        ? null
        : change < 0
        ? 'insights_less_than_last'.tr(
            namedArgs: {'percent': '${(-change * 100).round()}'},
          )
        : 'insights_more_than_last'.tr(
            namedArgs: {'percent': '${(change * 100).round()}'},
          );

    String sliceName(InsightSlice s) {
      if (i.byCategory)
        return s.key.isEmpty ? 'insights_uncategorized'.tr() : s.key;
      return s.key.isEmpty
          ? 'insights_no_group'.tr()
          : (groupNames[s.key] ?? 'insights_no_group'.tr());
    }

    String? payback;
    if (i.paybackDays != null) {
      final days = i.paybackDays!.round().clamp(0, 365);
      payback = days <= 1
          ? 'insights_payback_fast'.tr()
          : 'insights_payback_days'.tr(namedArgs: {'count': '$days'});
      final slow = i.slowestPayer;
      if (slow != null && slow.days.round() > days) {
        payback =
            '$payback ${'insights_payback_slowest'.tr(namedArgs: {'name': slow.name, 'count': '${slow.days.round()}'})}';
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'insights_your_share'.tr(),
                style: AppTypography.bodyMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
              MoneyText(
                minor: i.totalMinor,
                currency: i.currency,
                tone: MoneyTone.neutral,
                size: MoneySize.large,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
                animate: true,
              ),
              Text(
                [bills, ?changeText].join(' · '),
                style: AppTypography.bodyMedium.copyWith(
                  color: p.textSecondary,
                ),
              ),
              if (i.otherCurrencies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'insights_other_currencies'.tr(
                      namedArgs: {'codes': i.otherCurrencies.join(', ')},
                    ),
                    style: AppTypography.bodySmall.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        LedgerCard(
          margin: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          padding: const EdgeInsets.all(20),
          child: WeeklyBars(weekly: i.weekly, peak: i.peakWeek),
        ),
        if (i.slices.isNotEmpty)
          LedgerCard(
            margin: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
            child: LedgerRows(
              children: [
                for (final (idx, s) in i.slices.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: MergeSemantics(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: [p.accent, p.coral, p.sky][idx % 3],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  sliceName(s),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: p.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                '${(s.amountMinor * 100 / i.totalMinor).round()}%',
                                style: AppTypography.bodySmall.copyWith(
                                  color: p.textSecondary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 96,
                                child: MoneyText(
                                  minor: s.amountMinor,
                                  currency: i.currency,
                                  tone: MoneyTone.neutral,
                                  textAlign: TextAlign.end,
                                  size: MoneySize.small,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: AppRadii.chipRadius,
                            child: LinearProgressIndicator(
                              value: (s.amountMinor / i.totalMinor).clamp(
                                0.0,
                                1.0,
                              ),
                              minHeight: 6,
                              backgroundColor: p.raised,
                              color: [p.accent, p.coral, p.sky][idx % 3],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (payback != null)
          Container(
            margin: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: AppRadii.rowRadius,
            ),
            child: Row(
              children: [
                Icon(AppIcons.success, size: 20, color: p.onAccentSoft),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    payback,
                    style: AppTypography.labelMedium.copyWith(
                      color: p.onAccentSoft,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Four or five weekly bars; the busiest week in the accent color.
class WeeklyBars extends StatelessWidget {
  const WeeklyBars({super.key, required this.weekly, required this.peak});
  final List<int> weekly;
  final int peak;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final weeks = weekly.last == 0 ? weekly.sublist(0, 4) : weekly;
    final max = weeks.fold(0, (a, b) => a > b ? a : b);
    return Semantics(
      label: 'insights_chart_label'.tr(namedArgs: {'week': '${peak + 1}'}),
      child: ExcludeSemantics(
        child: SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var w = 0; w < weeks.length; w++) ...[
                if (w > 0) const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: max == 0 ? 0 : weeks[w] / max,
                        ),
                        duration: AppMotion.durationFor(
                          context,
                          AppMotion.money,
                        ),
                        curve: AppMotion.quiet,
                        builder: (context, v, _) => Container(
                          height: 4 + 106 * v,
                          decoration: BoxDecoration(
                            color: w == peak && weeks[w] > 0
                                ? p.accent
                                : p.raised,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'insights_week_short'.tr(namedArgs: {'n': '${w + 1}'}),
                        style: AppTypography.caption.copyWith(
                          color: p.textSecondary,
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
