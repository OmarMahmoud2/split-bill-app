/// Mixed currencies on a trip: every bill in its original currency, and
/// balances kept per currency.
///
/// TODO(fx): there is no backend FX endpoint yet, so nothing is converted and
/// no rate is invented. Next step: a server endpoint with daily cached rates
/// (rate on the day each bill was added, user-overridable per bill); then
/// enable the "Everything shown in USD/EGP" chips below.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/insights.dart';
import 'package:split_bill_app/data/ledger_math.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/money_text.dart';

class GroupCurrenciesScreen extends StatefulWidget {
  const GroupCurrenciesScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupCurrenciesScreen> createState() => _GroupCurrenciesScreenState();
}

class _GroupCurrenciesScreenState extends State<GroupCurrenciesScreen> {
  Stream<GroupLedgerInput?>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream ??= watchGroupLedger(LedgerRepository.instance, widget.groupId, fallbackCurrency: preferredCurrency(context));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final me = LedgerMe.current()?.uid ?? '';
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: StreamBuilder<GroupLedgerInput?>(
          stream: _stream,
          builder: (context, snap) {
            final g = snap.data;
            final title = g == null ? 'fx_title_short'.tr() : 'fx_title'.tr(namedArgs: {'group': g.group.name});
            Widget body;
            if (snap.hasError) {
              body = ErrorState(onRetry: () => setState(() => _stream = watchGroupLedger(LedgerRepository.instance, widget.groupId)));
            } else if (!snap.hasData) {
              body = const Padding(padding: EdgeInsets.all(20), child: SkeletonShimmer(child: SkeletonCard()));
            } else if (g == null) {
              body = ErrorState(title: 'groups_not_found'.tr(), message: 'groups_not_found_body'.tr());
            } else {
              final bills = g.bills.where((b) => !b.isDraft).toList();
              final totals = totalsByCurrency(bills);
              final mine = g.view.balanceOf(me);
              body = ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('fx_shown_in'.tr(), style: AppTypography.bodyMedium.copyWith(color: p.textSecondary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            ChoiceChip(
                              label: Text('fx_original'.tr()),
                              selected: true,
                              onSelected: (_) {},
                              showCheckmark: false,
                              shape: const RoundedRectangleBorder(borderRadius: AppRadii.chipRadius),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (bills.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: EmptyState(icon: Icons.currency_exchange_rounded, title: 'groups_no_bills_title'.tr(), message: 'groups_no_bills_body'.tr()),
                    )
                  else
                    LedgerCard(
                      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: LedgerRows(
                        children: [
                          for (final b in bills)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: MergeSemantics(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(b.title.isEmpty ? 'bill'.tr() : b.title, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600)),
                                          Text(b.currency, style: AppTypography.bodySmall.copyWith(color: p.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    MoneyText(minor: b.totalMinor, currency: b.currency, tone: MoneyTone.neutral),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (totals.isNotEmpty) ...[
                    OverlineLabel('fx_totals_by_currency'.tr()),
                    LedgerCard(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      child: LedgerRows(
                        children: [
                          for (final e in totals.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: MergeSemantics(
                                child: Row(
                                  children: [
                                    Expanded(child: Text(e.key, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600))),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        MoneyText(minor: e.value, currency: e.key, tone: MoneyTone.neutral),
                                        if ((mine[e.key] ?? 0) != 0)
                                          Text(
                                            (mine[e.key]! > 0 ? 'fx_you_are_owed' : 'fx_you_owe').tr(
                                              namedArgs: {'amount': moneyLabel(context, mine[e.key]!.abs(), e.key)},
                                            ),
                                            style: AppTypography.bodySmall.copyWith(color: mine[e.key]! > 0 ? p.owed : p.owe),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  LedgerCard(
                    margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('fx_no_conversion_title'.tr(), style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('fx_no_conversion_body'.tr(), style: AppTypography.bodySmall.copyWith(color: p.textSecondary, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(children: [LedgerTopBar(title: title), Expanded(child: body)]);
          },
        ),
      ),
    );
  }
}
