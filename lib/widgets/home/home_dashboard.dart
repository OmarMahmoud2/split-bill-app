/// The Home tab: net balance hero, quick actions, "Settle with", groups,
/// recent activity, and the first-day empty state.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/activity.dart';
import 'package:split_bill_app/data/insights.dart';
import 'package:split_bill_app/data/ledger_math.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/groups_screen.dart';
import 'package:split_bill_app/screens/activity/activity_screen.dart';
import 'package:split_bill_app/screens/friends/friend_detail_screen.dart';
import 'package:split_bill_app/screens/friends/people_screen.dart';
import 'package:split_bill_app/screens/insights/insights_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/home/new_sheet.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Callbacks into the Home shell.
class HomeActions {
  const HomeActions({
    required this.onNew,
    required this.onQuickIou,
    required this.onStartGroup,
    required this.onOpenGroups,
    required this.onOpenActivity,
    required this.onOpenProfile,
    required this.onOpenNotifications,
  });

  final VoidCallback onNew;
  final VoidCallback onQuickIou;
  final VoidCallback onStartGroup;
  final VoidCallback onOpenGroups;
  final VoidCallback onOpenActivity;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenNotifications;
}

/// The newest [limit] activity items from what Home already loaded.
List<ActivityItem> recentActivity(HomeLedgerState s, String me, {int limit = 5}) {
  final seen = <String>{};
  final items = <ActivityItem>[];
  for (final b in [...s.recentBills, for (final g in s.groupInputs) ...g.bills]) {
    if (b.isDraft || !seen.add('b:${b.id}')) continue;
    if (b.hostId != me && b.share(me) == null) continue;
    items.add(activityFromBill(b, me));
  }
  for (final p in [...s.directPayments, for (final g in s.groupInputs) ...g.payments]) {
    if (!seen.add('p:${p.id}')) continue;
    if (p.from != me && p.to != me) continue;
    items.add(activityFromPayment(p, me));
  }
  items.sort((a, b) => b.date.compareTo(a.date));
  return items.take(limit).toList();
}

class HomeDashboard extends StatelessWidget {
  const HomeDashboard({
    super.key,
    required this.stream,
    required this.actions,
    required this.onRetry,
    this.unread,
    this.footer,
  });

  final VoidCallback onRetry;

  final Stream<HomeLedgerState> stream;
  final Stream<bool>? unread;
  final HomeActions actions;

  /// Shown below the content (e.g. the banner ad for free users).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final me = LedgerMe.current();
    if (me == null) return ErrorState(title: 'please_log_in_2'.tr());
    return ColoredBox(
      color: p.background,
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<HomeLedgerState>(
          stream: stream,
          builder: (context, snap) {
            final header = _Header(me: me, unread: unread, actions: actions);
            if (snap.hasError) {
              return Column(
                children: [
                  header,
                  Expanded(child: ErrorState(message: 'home_load_failed'.tr(), onRetry: onRetry)),
                ],
              );
            }
            if (!snap.hasData) return Column(children: [header, const Expanded(child: _HomeSkeleton())]);
            final s = snap.data!;
            final empty = s.groups.isEmpty && s.recentBills.where((b) => !b.isDraft).isEmpty && s.directPayments.isEmpty;
            if (empty) return Column(children: [header, Expanded(child: _FirstDay(actions: actions))]);
            return ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                header,
                StaggeredEntrance(index: 0, child: _Hero(summary: s.summary)),
                StaggeredEntrance(index: 1, child: _QuickActions(actions: actions, state: s)),
                if (s.summary.open.isNotEmpty) StaggeredEntrance(index: 2, child: _SettleWith(state: s, stream: stream)),
                if (s.groups.any((g) => !g.archived)) StaggeredEntrance(index: 3, child: _Groups(state: s, me: me.uid, onAll: actions.onOpenGroups)),
                StaggeredEntrance(index: 4, child: _Recent(state: s, me: me.uid, onAll: actions.onOpenActivity)),
                StaggeredEntrance(index: 5, child: _InsightsTeaser(state: s, me: me.uid, stream: stream)),
                ?footer,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.me, required this.unread, required this.actions});
  final LedgerMe me;
  final Stream<bool>? unread;
  final HomeActions actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final first = me.name.trim().split(RegExp(r'\s+')).first;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'home_open_profile'.tr(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: actions.onOpenProfile,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(child: LedgerAvatar(id: me.uid, name: me.name, photoUrl: me.photoUrl)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              first.isEmpty ? 'home_hi_there'.tr() : 'home_hi'.tr(namedArgs: {'name': first}),
              style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          RoundIconButton(icon: Icons.add_rounded, tooltip: 'new_title'.tr(), onPressed: actions.onNew),
          const SizedBox(width: 8),
          StreamBuilder<bool>(
            stream: unread,
            builder: (context, snap) {
              final has = snap.data ?? false;
              return RoundIconButton(
                icon: Icons.notifications_none_rounded,
                tooltip: has ? 'home_notifications_new'.tr() : 'notifications'.tr(),
                badge: has,
                onPressed: actions.onOpenNotifications,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary});
  final BalanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final preferred = preferredCurrency(context);
    final net = summary.net;
    final headline = headlineAmount(net, preferred);
    final known = summary.currencies;
    final currency = headline?.key ??
        (known.isEmpty || known.contains(normalizeCurrencyCode(preferred)) ? normalizeCurrencyCode(preferred) : known.first);
    final value = headline?.value ?? 0;
    final owed = summary.owedToMe[currency] ?? 0;
    final owe = summary.iOwe[currency] ?? 0;
    final label = value > 0
        ? 'home_owed_overall'.tr()
        : value < 0
        ? 'home_owe_overall'.tr()
        : 'home_all_square'.tr();
    final others = summary.currencies.where((c) => c != currency).toList()..sort();
    final sub = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${'home_owed_to_you'.tr()} '),
          TextSpan(text: moneyLabel(context, owed, currency), style: TextStyle(color: p.owed, fontWeight: FontWeight.w700)),
          const TextSpan(text: ' · '),
          TextSpan(text: '${'home_you_owe'.tr()} '),
          TextSpan(text: moneyLabel(context, owe, currency), style: TextStyle(color: p.owe, fontWeight: FontWeight.w700)),
        ],
      ),
      style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.bodyMedium.copyWith(color: p.textSecondary, fontWeight: FontWeight.w500)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: MoneyText(
              minor: value,
              currency: currency,
              sign: MoneySign.always,
              size: MoneySize.hero,
              style: const TextStyle(fontSize: 52),
              animate: true,
              semanticsLabel: '$label ${moneyLabel(context, value, currency)}',
            ),
          ),
          sub,
          if (others.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'home_other_currencies'.tr(namedArgs: {
                  'list': [
                    for (final c in others)
                      if ((net[c] ?? 0) != 0) moneyLabel(context, net[c]!, c, sign: MoneySign.always),
                  ].join(', '),
                }),
                style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

String normalizeCurrencyCode(String c) => c.trim().toUpperCase();

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions, required this.state});
  final HomeActions actions;
  final HomeLedgerState state;

  @override
  Widget build(BuildContext context) {
    final voice = BillEntryPoints.voice;
    final tiles = <(IconData, String, VoidCallback)>[
      (Icons.document_scanner_outlined, 'home_qa_scan'.tr(), () => BillEntryPoints.scan(context)),
      if (voice != null) (Icons.mic_none_rounded, 'home_qa_say'.tr(), () => voice(context)),
      (Icons.add_rounded, 'home_qa_expense'.tr(), () => BillEntryPoints.manual(context)),
      (
        Icons.swap_horiz_rounded,
        'home_qa_settle'.tr(),
        () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PeopleScreen())),
      ),
    ];
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Row(
        children: [
          for (final (i, t) in tiles.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: LedgerCard(
                onTap: () {
                  AppHaptics.light();
                  t.$3();
                },
                semanticsLabel: t.$2,
                child: SizedBox(
                  height: 84,
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(t.$1, size: 22, color: p.textPrimary),
                        const SizedBox(height: 8),
                        Text(t.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.labelMedium.copyWith(color: p.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One person with a balance: avatar, name, where it comes from, amount.
class PersonBalanceRow extends StatelessWidget {
  const PersonBalanceRow({super.key, required this.person, this.onTap});
  final Counterparty person;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final amount = person.primary(preferredCurrency(context));
    final where = person.contexts.where((c) => c.net.isNotEmpty).map((c) => c.label.isEmpty ? 'friend_direct_label'.tr() : c.label).toSet().join(', ');
    final owes = (amount?.value ?? 0) > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: MergeSemantics(
          child: Row(
            children: [
              LedgerAvatar(id: person.id, name: person.name, photoUrl: person.photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.name.isEmpty ? 'someone_label'.tr() : person.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                    if (where.isNotEmpty) Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.bodySmall.copyWith(color: p.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              if (amount != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(owes ? 'home_owes_you'.tr() : 'home_you_owe_lower'.tr(), style: AppTypography.caption.copyWith(color: p.textSecondary, fontSize: 12)),
                    MoneyText(minor: amount.value, currency: amount.key, sign: MoneySign.always),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettleWith extends StatelessWidget {
  const _SettleWith({required this.state, required this.stream});
  final HomeLedgerState state;
  final Stream<HomeLedgerState> stream;

  @override
  Widget build(BuildContext context) {
    final open = state.summary.open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'home_settle_with'.tr(),
          actionLabel: 'home_all'.tr(),
          onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PeopleScreen(state: stream))),
        ),
        LedgerCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: LedgerRows(
            children: [
              for (final person in open.take(3))
                PersonBalanceRow(
                  person: person,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FriendDetailScreen(friendId: person.id, state: stream))),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Groups extends StatelessWidget {
  const _Groups({required this.state, required this.me, required this.onAll});
  final HomeLedgerState state;
  final String me;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final active = state.groups.where((g) => !g.archived).take(2).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'groups'.tr(), actionLabel: 'home_all'.tr(), onAction: onAll, padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 12, 8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, g) in active.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: GroupCard(group: g, input: state.input(g.id), me: me, compact: true)),
              ],
              if (active.length == 1) ...[const SizedBox(width: 10), const Expanded(child: SizedBox.shrink())],
            ],
          ),
        ),
      ],
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.state, required this.me, required this.onAll});
  final HomeLedgerState state;
  final String me;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final items = recentActivity(state, me);
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: 'home_recent_activity'.tr(), actionLabel: 'home_all'.tr(), onAction: onAll, padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 12, 8)),
        LedgerCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: LedgerRows(
            children: [
              for (final item in items)
                ActivityRow(
                  item: item,
                  me: me,
                  onTap: item.kind == ActivityKind.billAdded && item.billId != null
                      ? () => openBill(context, billId: item.billId!, hostId: item.actorId, title: item.title, me: me)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightsTeaser extends StatelessWidget {
  const _InsightsTeaser({required this.state, required this.me, required this.stream});
  final HomeLedgerState state;
  final String me;
  final Stream<HomeLedgerState> stream;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final i = computeInsights(me: me, month: now, currency: preferredCurrency(context), bills: state.recentBills);
    if (i.billCount == 0) return const SizedBox.shrink();
    final month = DateFormat.MMMM(context.locale.toLanguageTag()).format(now);
    return LedgerCard(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => InsightsScreen(state: stream))),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: p.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'home_insights_teaser'.tr(namedArgs: {'month': month, 'amount': moneyLabel(context, i.totalMinor, i.currency)}),
              style: AppTypography.bodyMedium.copyWith(color: p.textPrimary),
            ),
          ),
          Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: p.textTertiary),
        ],
      ),
    );
  }
}

class _FirstDay extends StatelessWidget {
  const _FirstDay({required this.actions});
  final HomeActions actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: p.accentSoft, borderRadius: AppRadii.cardRadius),
              child: Icon(Icons.receipt_long_rounded, color: p.accent, size: 32),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text('home_first_title'.tr(), style: AppTypography.headlineMedium.copyWith(color: p.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, height: 1.15)),
          ),
          const SizedBox(height: 14),
          Text('home_first_body'.tr(), style: AppTypography.bodyLarge.copyWith(color: p.textSecondary, height: 1.5)),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent),
            onPressed: () => BillEntryPoints.scan(context),
            child: Text('new_scan_title'.tr()),
          ),
          const SizedBox(height: 14),
          OutlinedButton(onPressed: () => BillEntryPoints.manual(context), child: Text('new_expense_title'.tr())),
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: p.textSecondary),
            onPressed: actions.onStartGroup,
            child: Text('new_group_title'.tr()),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const SkeletonShimmer(
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton.line(width: 140),
          SizedBox(height: 10),
          Skeleton(width: 220, height: 52),
          SizedBox(height: 10),
          Skeleton.line(width: 260),
          SizedBox(height: 22),
          Skeleton(height: 84, borderRadius: AppRadii.cardRadius),
          SizedBox(height: 22),
          SkeletonCard(),
          SizedBox(height: 12),
          SkeletonCard(),
        ],
      ),
    ),
  );
}

/// Kept for screens that only need the person list.
List<GroupMember> peopleAsMembers(BalanceSummary s) => [
  for (final p in s.people) GroupMember(id: p.id, name: p.name, photoUrl: p.photoUrl),
];
