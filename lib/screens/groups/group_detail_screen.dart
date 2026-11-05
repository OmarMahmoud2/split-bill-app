/// Group or trip: balances, bills and totals, with the budget bar.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:split_bill_app/config/app_links.dart';
import 'package:split_bill_app/data/insights.dart';
import 'package:split_bill_app/data/ledger_math.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/screens/groups/create_group_screen.dart';
import 'package:split_bill_app/screens/groups/group_currencies_screen.dart';
import 'package:split_bill_app/screens/groups/member_picker.dart';
import 'package:split_bill_app/screens/settle/settle_up_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/home/new_sheet.dart';
import 'package:split_bill_app/widgets/money_text.dart';

enum _Tab { balances, bills, totals }

/// Budget numbers for the bar ("$232 left for 1 day · about $58 each").
class BudgetStatus {
  const BudgetStatus({required this.spentMinor, required this.budgetMinor, required this.daysLeft, required this.members});
  final int spentMinor;
  final int budgetMinor;
  final int? daysLeft;
  final int members;

  int get leftMinor => budgetMinor - spentMinor;
  double get fraction => budgetMinor <= 0 ? 0 : spentMinor / budgetMinor;
  int get eachMinor => members <= 0 || leftMinor <= 0 ? 0 : leftMinor ~/ members;

  static BudgetStatus? of(GroupLedgerInput g, {DateTime? now}) {
    final budget = g.group.budgetMinor;
    final currency = g.group.currency;
    if (budget == null || budget <= 0 || currency == null) return null;
    final spent = totalsByCurrency(g.bills)[currency] ?? 0;
    final today = now ?? DateTime.now();
    final end = g.group.endDate;
    int? days;
    if (end != null) {
      final d = DateTime(end.year, end.month, end.day).difference(DateTime(today.year, today.month, today.day)).inDays + 1;
      days = d > 0 ? d : null;
    }
    return BudgetStatus(spentMinor: spent, budgetMinor: budget, daysLeft: days, members: g.group.members.length);
  }
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  Stream<GroupLedgerInput?>? _stream;
  _Tab _tab = _Tab.balances;
  LedgerMe? _me;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _me ??= LedgerMe.current();
    _stream ??= watchGroupLedger(LedgerRepository.instance, widget.groupId, fallbackCurrency: preferredCurrency(context));
  }

  void _retry() => setState(() => _stream = watchGroupLedger(LedgerRepository.instance, widget.groupId, fallbackCurrency: preferredCurrency(context)));

  Future<void> _editMembers(LedgerGroup g) async {
    var members = [...g.members];
    final saved = await showLedgerSheet<bool>(
      context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('groups_members'.tr(), style: AppTypography.headlineSmall.copyWith(color: context.palette.textPrimary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              MemberPickerField(
                members: members,
                lockedIds: {g.createdBy},
                onChanged: (m) => setSheet(() => members = m),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('common_save_changes'.tr())),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await LedgerRepository.instance.updateGroup(g.id, {
        'members': [for (final m in members) m.toMap()],
        'memberIds': [for (final m in members) m.id],
      });
      if (mounted) AppToast.show(context, message: 'groups_members_saved'.tr(), type: AppToastType.success);
    } catch (_) {
      if (mounted) AppToast.show(context, message: 'groups_save_failed'.tr(), type: AppToastType.error);
    }
  }

  void _invite(LedgerGroup g) {
    SharePlus.instance.share(
      ShareParams(text: 'groups_invite_text'.tr(namedArgs: {'name': _me?.name ?? '', 'group': g.name, 'link': AppLinks.appStoreUrl})),
    );
  }

  Future<void> _setArchived(LedgerGroup g, bool archived) async {
    try {
      await LedgerRepository.instance.updateGroup(g.id, {'archived': archived});
      if (mounted) {
        AppToast.show(context, message: (archived ? 'groups_archived' : 'groups_unarchived').tr(), type: AppToastType.success);
      }
    } catch (_) {
      if (mounted) AppToast.show(context, message: 'groups_save_failed'.tr(), type: AppToastType.error);
    }
  }

  Future<void> _delete(LedgerGroup g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('groups_delete_title'.tr(namedArgs: {'name': g.name})),
        content: Text('groups_delete_body'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('common_cancel'.tr())),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text('groups_delete_confirm'.tr())),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    AppHaptics.warning();
    final nav = Navigator.of(context);
    try {
      await LedgerRepository.instance.deleteGroup(g.id);
      if (!mounted) return;
      AppToast.show(context, message: 'groups_deleted'.tr(), type: AppToastType.success);
      nav.pop();
    } catch (_) {
      if (mounted) AppToast.show(context, message: 'groups_save_failed'.tr(), type: AppToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: StreamBuilder<GroupLedgerInput?>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Column(children: [const LedgerTopBar(), Expanded(child: ErrorState(onRetry: _retry))]);
            }
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return Column(
                children: const [
                  LedgerTopBar(),
                  Padding(
                    padding: EdgeInsets.all(20),
                    child: SkeletonShimmer(child: Column(children: [SkeletonCard(), SizedBox(height: 12), SkeletonCard()])),
                  ),
                ],
              );
            }
            final g = snap.data;
            if (g == null) {
              return Column(
                children: [
                  const LedgerTopBar(),
                  Expanded(child: ErrorState(title: 'groups_not_found'.tr(), message: 'groups_not_found_body'.tr())),
                ],
              );
            }
            return _body(context, g);
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, GroupLedgerInput g) {
    final p = context.palette;
    final me = _me?.uid ?? '';
    final group = g.group;
    final view = g.view;
    final isOwner = group.createdBy == me;
    final currencies = {group.currency ?? preferredCurrency(context), ...totalsByCurrency(g.bills).keys}.toList();
    final df = DateFormat.MMMd(localeTag(context));
    final subtitle = [
      if (group.startDate != null && group.endDate != null) '${df.format(group.startDate!)} – ${df.format(group.endDate!)}',
      plainMemberCount(group.members.length),
      currencies.join(', '),
    ].join(' · ');
    final budget = BudgetStatus.of(g);

    return Column(
      children: [
        LedgerTopBar(
          actions: [
            RoundIconButton(
              icon: Icons.person_add_alt_1_rounded,
              tooltip: isOwner ? 'groups_edit_members'.tr() : 'groups_invite_friends'.tr(),
              onPressed: () => isOwner ? _editMembers(group) : _invite(group),
            ),
            PopupMenuButton<String>(
              tooltip: 'groups_more'.tr(),
              icon: Icon(Icons.more_horiz_rounded, color: p.textPrimary),
              onSelected: (v) {
                switch (v) {
                  case 'currencies':
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupCurrenciesScreen(groupId: group.id)));
                  case 'invite':
                    _invite(group);
                  case 'archive':
                    _setArchived(group, !group.archived);
                  case 'delete':
                    _delete(group);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'currencies', child: Text('fx_title_short'.tr())),
                PopupMenuItem(value: 'invite', child: Text('groups_invite_friends'.tr())),
                PopupMenuItem(value: 'archive', child: Text((group.archived ? 'groups_unarchive' : 'groups_archive').tr())),
                if (isOwner) PopupMenuItem(value: 'delete', child: Text('groups_delete_confirm'.tr())),
              ],
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(group.name, style: AppTypography.headlineLarge.copyWith(color: p.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.bodyMedium.copyWith(color: p.textSecondary)),
                  ],
                ),
              ),
              if (budget != null) _BudgetCard(status: budget, currency: group.currency!),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: LedgerSegmented<_Tab>(
                  segments: [
                    (_Tab.balances, 'groups_tab_balances'.tr()),
                    (_Tab.bills, 'groups_tab_bills'.tr()),
                    (_Tab.totals, 'groups_tab_totals'.tr()),
                  ],
                  selected: _tab,
                  onChanged: (t) => setState(() => _tab = t),
                ),
              ),
              AnimatedSwitcher(
                duration: AppMotion.durationFor(context, AppMotion.medium),
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: switch (_tab) {
                    _Tab.balances => _balances(context, g, view, me),
                    _Tab.bills => _bills(context, g, me),
                    _Tab.totals => _totals(context, g, me),
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showNewSheet(
                    context,
                    members: group.members.where((m) => m.id != me).toList(),
                    groupId: group.id,
                    onQuickIou: () {},
                    onStartGroup: () {},
                  ),
                  child: Text('groups_add_bill'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettleUpScreen.group(groupId: group.id))),
                  child: Text('settle_up_title'.tr()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _balances(BuildContext context, GroupLedgerInput g, LedgerView view, String me) {
    final members = [...g.group.members]..sort((a, b) => a.id == me ? -1 : (b.id == me ? 1 : 0));
    if (members.isEmpty) return const SizedBox.shrink();
    return LedgerCard(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: LedgerRows(
        children: [
          for (final m in members)
            _memberRow(context, m, view.balanceOf(m.id), me),
        ],
      ),
    );
  }

  Widget _memberRow(BuildContext context, GroupMember m, Map<String, int> balance, String me) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: MergeSemantics(
        child: Row(
          children: [
            LedgerAvatar(id: m.id, name: m.name, photoUrl: m.photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Text(personName(m.id, m.name, me), style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            if (balance.isEmpty)
              Text('groups_settled'.tr(), style: AppTypography.labelMedium.copyWith(color: p.textSecondary))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final e in balance.entries)
                    MoneyText(minor: e.value, currency: e.key, sign: MoneySign.always),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _bills(BuildContext context, GroupLedgerInput g, String me) {
    final p = context.palette;
    final bills = g.bills.where((b) => !b.isDraft).toList();
    if (bills.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'groups_no_bills_title'.tr(),
          message: 'groups_no_bills_body'.tr(),
          actionLabel: 'groups_add_bill'.tr(),
          onAction: () => BillEntryPoints.scan(context, members: g.group.members.where((m) => m.id != me).toList(), groupId: g.group.id),
        ),
      );
    }
    final df = DateFormat.MMMd(localeTag(context));
    return LedgerCard(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: LedgerRows(
        children: [
          for (final b in bills)
            InkWell(
              onTap: () => openBill(context, billId: b.id, hostId: b.hostId, title: b.title, me: me),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: MergeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.title.isEmpty ? 'bill'.tr() : b.title, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                            Text(
                              [
                                if (b.date != null) df.format(b.date!),
                                'groups_paid_by'.tr(namedArgs: {'name': personName(b.hostId, b.nameOf(b.hostId), me)}),
                              ].join(' · '),
                              style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      MoneyText(minor: b.totalMinor, currency: b.currency, tone: MoneyTone.neutral),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _totals(BuildContext context, GroupLedgerInput g, String me) {
    final p = context.palette;
    final totals = totalsByCurrency(g.bills);
    if (totals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: EmptyState(icon: Icons.bar_chart_rounded, title: 'groups_no_bills_title'.tr(), message: 'groups_no_bills_body'.tr()),
      );
    }
    // currency -> person -> (paid, share)
    final paid = <String, Map<String, int>>{};
    final share = <String, Map<String, int>>{};
    for (final b in g.bills.where((b) => !b.isDraft)) {
      paid.putIfAbsent(b.currency, () => {}).update(b.hostId, (v) => v + b.totalMinor, ifAbsent: () => b.totalMinor);
      for (final s in b.participants) {
        share.putIfAbsent(b.currency, () => {}).update(s.id, (v) => v + s.shareMinor, ifAbsent: () => s.shareMinor);
      }
    }
    return Column(
      children: [
        for (final e in totals.entries)
          LedgerCard(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('groups_total_spent'.tr(), style: AppTypography.bodyMedium.copyWith(color: p.textSecondary)),
                MoneyText(minor: e.value, currency: e.key, tone: MoneyTone.neutral, size: MoneySize.large),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: SizedBox.shrink()),
                    SizedBox(width: 92, child: Text('groups_paid'.tr(), textAlign: TextAlign.end, style: AppTypography.labelSmall.copyWith(color: p.textSecondary))),
                    SizedBox(width: 92, child: Text('groups_share'.tr(), textAlign: TextAlign.end, style: AppTypography.labelSmall.copyWith(color: p.textSecondary))),
                  ],
                ),
                for (final m in g.group.members)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MergeSemantics(
                      child: Row(
                        children: [
                          Expanded(child: Text(personName(m.id, m.name, me), style: AppTypography.bodyMedium.copyWith(color: p.textPrimary))),
                          SizedBox(width: 92, child: MoneyText(minor: paid[e.key]?[m.id] ?? 0, currency: e.key, tone: MoneyTone.neutral, size: MoneySize.small, textAlign: TextAlign.end)),
                          SizedBox(width: 92, child: MoneyText(minor: share[e.key]?[m.id] ?? 0, currency: e.key, tone: MoneyTone.neutral, size: MoneySize.small, textAlign: TextAlign.end)),
                        ],
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

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.status, required this.currency});
  final BudgetStatus status;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final budget = moneyLabel(context, status.budgetMinor, currency);
    final over = status.leftMinor < 0;
    final left = moneyLabel(context, status.leftMinor.abs(), currency);
    final each = moneyLabel(context, status.eachMinor, currency);
    final String footer;
    if (over) {
      footer = 'groups_budget_over'.tr(namedArgs: {'amount': left});
    } else if (status.daysLeft != null) {
      footer = status.daysLeft == 1
          ? 'groups_budget_left_one_day'.tr(namedArgs: {'amount': left, 'each': each})
          : 'groups_budget_left_days'.tr(namedArgs: {'amount': left, 'days': '${status.daysLeft}', 'each': each});
    } else {
      footer = 'groups_budget_left'.tr(namedArgs: {'amount': left, 'each': each});
    }
    return LedgerCard(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('groups_spent_of_budget'.tr(namedArgs: {'budget': budget}), style: AppTypography.bodyMedium.copyWith(color: p.textSecondary))),
              MoneyText(minor: status.spentMinor, currency: currency, tone: MoneyTone.neutral, size: MoneySize.small, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: 'groups_budget_used'.tr(namedArgs: {'percent': '${(status.fraction * 100).round()}'}),
            child: BudgetBar(fraction: status.fraction),
          ),
          const SizedBox(height: 10),
          Text(footer, style: AppTypography.bodySmall.copyWith(color: over ? p.oweInk : p.textSecondary)),
        ],
      ),
    );
  }
}
