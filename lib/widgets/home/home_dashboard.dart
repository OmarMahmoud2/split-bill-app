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
import 'package:split_bill_app/screens/friends/friend_detail_screen.dart';
import 'package:split_bill_app/screens/friends/people_screen.dart';
import 'package:split_bill_app/screens/insights/insights_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/home/new_sheet.dart';
import 'package:split_bill_app/widgets/money_text.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';

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
List<ActivityItem> recentActivity(
  HomeLedgerState s,
  String me, {
  int limit = 5,
}) {
  final seen = <String>{};
  final items = <ActivityItem>[];
  for (final b in [
    ...s.recentBills,
    for (final g in s.groupInputs) ...g.bills,
  ]) {
    if (b.isDraft || !seen.add('b:${b.id}')) continue;
    if (b.hostId != me && b.share(me) == null) continue;
    items.add(activityFromBill(b, me));
  }
  for (final p in [
    ...s.directPayments,
    for (final g in s.groupInputs) ...g.payments,
  ]) {
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
    return Material(
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
                  Expanded(
                    child: ErrorState(
                      message: 'home_load_failed'.tr(),
                      onRetry: onRetry,
                    ),
                  ),
                ],
              );
            }
            if (!snap.hasData)
              return Column(
                children: [
                  header,
                  const Expanded(child: _HomeSkeleton()),
                ],
              );
            final s = snap.data!;
            final empty =
                s.groups.isEmpty &&
                s.recentBills.where((b) => !b.isDraft).isEmpty &&
                s.directPayments.isEmpty;
            if (empty)
              return Column(
                children: [
                  header,
                  Expanded(child: _FirstDay(actions: actions)),
                ],
              );
            return ListView(
              padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 16),
              children: [
                header,
                StaggeredEntrance(
                  index: 0,
                  child: _Hero(summary: s.summary, stream: stream),
                ),
                StaggeredEntrance(
                  index: 1,
                  child: _QuickActions(actions: actions, state: s),
                ),
                if (s.summary.open.isNotEmpty)
                  StaggeredEntrance(
                    index: 2,
                    child: _People(state: s, stream: stream),
                  ),
                if (s.groups.any((g) => !g.archived))
                  StaggeredEntrance(
                    index: 3,
                    child: _Groups(
                      state: s,
                      me: me.uid,
                      onAll: actions.onOpenGroups,
                    ),
                  ),
                StaggeredEntrance(
                  index: 4,
                  child: _Recent(
                    state: s,
                    me: me.uid,
                    onAll: actions.onOpenActivity,
                  ),
                ),
                StaggeredEntrance(
                  index: 5,
                  child: _InsightsTeaser(state: s, me: me.uid, stream: stream),
                ),
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
  const _Header({
    required this.me,
    required this.unread,
    required this.actions,
  });
  final LedgerMe me;
  final Stream<bool>? unread;
  final HomeActions actions;

  String _greeting() {
    final h = DateTime.now().hour;
    return (h < 12
            ? 'home_good_morning'
            : h < 18
            ? 'home_good_afternoon'
            : 'home_good_evening')
        .tr();
  }

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
                width: 48,
                height: 48,
                child: Center(
                  child: LedgerAvatar(
                    id: me.uid,
                    name: me.name,
                    photoUrl: me.photoUrl,
                    size: 44,
                    selected: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(
                    color: p.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  first.isEmpty ? 'home_hi_there'.tr() : first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineMedium.copyWith(
                    color: p.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StreamBuilder<bool>(
            stream: unread,
            builder: (context, snap) {
              final has = snap.data ?? false;
              return RoundIconButton(
                icon: AppIcons.bell,
                tooltip: has
                    ? 'home_notifications_new'.tr()
                    : 'notifications'.tr(),
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
  const _Hero({required this.summary, required this.stream});
  final BalanceSummary summary;
  final Stream<HomeLedgerState> stream;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final preferred = preferredCurrency(context);
    final net = summary.net;
    final headline = headlineAmount(net, preferred);
    final known = summary.currencies;
    final currency =
        headline?.key ??
        (known.isEmpty || known.contains(normalizeCurrencyCode(preferred))
            ? normalizeCurrencyCode(preferred)
            : known.first);
    final value = headline?.value ?? 0;
    final owed = summary.owedToMe[currency] ?? 0;
    final owe = summary.iOwe[currency] ?? 0;
    final label = value > 0
        ? 'home_owed_overall'.tr()
        : value < 0
        ? 'home_owe_overall'.tr()
        : 'home_all_square'.tr();
    final others = summary.currencies.where((c) => c != currency).toList()
      ..sort();
    final muted = p.onHero.withValues(alpha: 0.7);

    Widget tile(Color dot, String text, int minor) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.onHero.withValues(alpha: 0.08),
          borderRadius: AppRadii.rowRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: MoneyText(
                minor: minor,
                currency: currency,
                tone: MoneyTone.neutral,
                size: MoneySize.row,
                style: TextStyle(color: p.onHero, fontSize: 17),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: AppRadii.heroRadius,
        border: Border.all(color: p.heroLine),
        boxShadow: p.heroShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          // LTR + scaleDown so long amounts (and Arabic digits) shrink, never clip.
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: MoneyText(
                    minor: value,
                    currency: currency,
                    sign: value == 0 ? MoneySign.none : MoneySign.always,
                    tone: MoneyTone.neutral,
                    size: MoneySize.hero,
                    style: TextStyle(
                      fontSize: 48,
                      color: p.onHero,
                      letterSpacing: -1,
                      fontWeight: FontWeight.w800,
                    ),
                    animate: true,
                    semanticsLabel:
                        '$label ${moneyLabel(context, value, currency)}',
                  ),
                ),
              ),
            ),
          ),
          if (others.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'home_other_currencies'.tr(
                  namedArgs: {
                    'list': [
                      for (final c in others)
                        if ((net[c] ?? 0) != 0)
                          moneyLabel(
                            context,
                            net[c]!,
                            c,
                            sign: MoneySign.always,
                          ),
                    ].join(', '),
                  },
                ),
                style: AppTypography.bodySmall.copyWith(color: muted),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              tile(p.owed, 'home_owed_to_you'.tr(), owed),
              const SizedBox(width: 10),
              tile(p.coral, 'home_you_owe'.tr(), owe),
            ],
          ),
          const SizedBox(height: 14),
          // No bulk "Remind N people" action exists (nudges are per person, once a week), so only Settle up.
          Pressable(
            haptic: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => PeopleScreen(state: stream)),
            ),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.onHero,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'settle_up_title'.tr(),
                style: AppTypography.labelLarge.copyWith(
                  color: p.hero,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
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
      (AppIcons.scan, 'home_qa_scan'.tr(), () => BillEntryPoints.scan(context)),
      if (voice != null)
        (AppIcons.mic, 'home_qa_say'.tr(), () => voice(context)),
      (
        AppIcons.add,
        'home_qa_expense'.tr(),
        () => BillEntryPoints.manual(context),
      ),
      (
        AppIcons.swap,
        'home_qa_settle'.tr(),
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PeopleScreen())),
      ),
    ];
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 0),
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
                        Text(
                          t.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMedium.copyWith(
                            color: p.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
    final where = person.contexts
        .where((c) => c.net.isNotEmpty)
        .map((c) => c.label.isEmpty ? 'friend_direct_label'.tr() : c.label)
        .toSet()
        .join(', ');
    final owes = (amount?.value ?? 0) > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: MergeSemantics(
          child: Row(
            children: [
              LedgerAvatar(
                id: person.id,
                name: person.name,
                photoUrl: person.photoUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name.isEmpty ? 'someone_label'.tr() : person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: p.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (where.isNotEmpty)
                      Text(
                        where,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: p.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              if (amount != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      owes ? 'home_owes_you'.tr() : 'home_you_owe_lower'.tr(),
                      style: AppTypography.caption.copyWith(
                        color: p.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    MoneyText(
                      minor: amount.value,
                      currency: amount.key,
                      sign: MoneySign.always,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your people": a strip of avatars with what each person owes / is owed.
class _People extends StatelessWidget {
  const _People({required this.state, required this.stream});
  final HomeLedgerState state;
  final Stream<HomeLedgerState> stream;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final preferred = preferredCurrency(context);
    final open = state.summary.open.take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'home_your_people'.tr(),
          actionLabel: 'home_all'.tr(),
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PeopleScreen(state: stream)),
          ),
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: open.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final person = open[i];
              final amount = person.primary(preferred);
              final name = person.name.isEmpty
                  ? 'someone_label'.tr()
                  : person.name;
              return Semantics(
                button: true,
                child: InkWell(
                  borderRadius: AppRadii.rowRadius,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FriendDetailScreen(
                        friendId: person.id,
                        state: stream,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LedgerAvatar(
                          id: person.id,
                          name: person.name,
                          photoUrl: person.photoUrl,
                          size: 52,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMedium.copyWith(
                            color: p.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (amount != null)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: MoneyText(
                              minor: amount.value,
                              currency: amount.key,
                              sign: MoneySign.always,
                              size: MoneySize.small,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
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
        SectionHeader(
          title: 'groups'.tr(),
          actionLabel: 'home_all'.tr(),
          onAction: onAll,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 12, 8),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, g) in active.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: GroupCard(
                    group: g,
                    input: state.input(g.id),
                    me: me,
                    compact: true,
                  ),
                ),
              ],
              if (active.length == 1) ...[
                const SizedBox(width: 10),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The newest [limit] non-draft bills the user is part of, from what Home loaded.
List<BillRecord> recentBillsFor(HomeLedgerState s, String me, {int limit = 4}) {
  final seen = <String>{};
  final bills = <BillRecord>[];
  for (final b in [
    ...s.recentBills,
    for (final g in s.groupInputs) ...g.bills,
  ]) {
    if (b.isDraft || !seen.add(b.id)) continue;
    if (b.hostId != me && b.share(me) == null) continue;
    bills.add(b);
  }
  bills.sort(
    (a, b) => (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)),
  );
  return bills.take(limit).toList();
}

class _Recent extends StatelessWidget {
  const _Recent({required this.state, required this.me, required this.onAll});
  final HomeLedgerState state;
  final String me;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final bills = recentBillsFor(state, me);
    if (bills.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'home_recent_bills'.tr(),
          actionLabel: 'home_all'.tr(),
          onAction: onAll,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 12, 8),
        ),
        for (final b in bills)
          BillTile(
            bill: b,
            me: me,
            margin: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10),
          ),
      ],
    );
  }
}

/// A bill as a tile: category icon, title, meta, what it means for [me],
/// a stack of people and a paid progress bar.
class BillTile extends StatelessWidget {
  const BillTile({
    super.key,
    required this.bill,
    required this.me,
    this.margin = EdgeInsets.zero,
    this.onTap,
  });
  final BillRecord bill;
  final String me;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final mine = bill.hostId == me;
    final date = bill.date;
    final dayText = date == null
        ? ''
        : switch (dayBucket(date, DateTime.now())) {
            DayBucket.today => 'activity_today'.tr(),
            DayBucket.yesterday => 'activity_yesterday'.tr(),
            DayBucket.earlier => DateFormat.MMMd(
              localeTag(context),
            ).format(date),
          };
    final meta = [
      if (dayText.isNotEmpty) dayText,
      // People count lives in the avatar stack and "x of y paid".
      if (mine) 'groups_paid_by_you'.tr(),
    ].join(' · ');
    final minor = mine
        ? bill.unpaidShares.values.fold<int>(0, (a, v) => a + v)
        : -(bill.share(me)?.outstandingMinor ?? 0);
    final word = minor > 0
        ? 'home_owed_to_you'.tr()
        : minor < 0
        ? 'home_you_owe'.tr()
        : 'groups_settled'.tr();
    // Same count as bill details: the people who owe the payer.
    final debtors = bill.participants.where((x) => x.id != bill.hostId);
    final paid = debtors.where((x) => x.isPaid).length;
    final total = debtors.length;
    final tints = [
      (p.accentSoft, p.accent),
      (p.coralSoft, p.coral),
      (p.skySoft, p.sky),
    ];
    final tint =
        tints[(bill.category ?? bill.title).hashCode.abs() % tints.length];
    final title = bill.title.isEmpty ? 'bill'.tr() : bill.title;
    return LedgerCard(
      margin: margin,
      padding: const EdgeInsets.all(14),
      onTap:
          onTap ??
          () => openBill(
            context,
            billId: bill.id,
            hostId: bill.hostId,
            title: bill.title,
            me: me,
          ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.$1,
                  borderRadius: AppRadii.rowRadius,
                ),
                child: Icon(AppIcons.receipt, color: tint.$2, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: p.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (minor == 0)
                        Text(
                          word,
                          style: AppTypography.labelMedium.copyWith(
                            color: p.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else ...[
                        MoneyText(
                          minor: minor,
                          currency: bill.currency,
                          sign: MoneySign.always,
                        ),
                        Text(
                          word,
                          style: AppTypography.caption.copyWith(
                            color: p.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AvatarStack(
                people: [
                  for (final x in bill.participants) (x.id, x.name, x.photoUrl),
                ],
                size: 24,
                max: 3,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadii.fullRadius,
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : paid / total,
                    minHeight: 6,
                    backgroundColor: p.surfaceVariant,
                    color: p.accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  'home_paid_progress'.tr(
                    namedArgs: {'paid': '$paid', 'total': '$total'},
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: p.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightsTeaser extends StatelessWidget {
  const _InsightsTeaser({
    required this.state,
    required this.me,
    required this.stream,
  });
  final HomeLedgerState state;
  final String me;
  final Stream<HomeLedgerState> stream;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final i = computeInsights(
      me: me,
      month: now,
      currency: preferredCurrency(context),
      bills: state.recentBills,
    );
    if (i.billCount == 0) return const SizedBox.shrink();
    final month = DateFormat.MMMM(localeTag(context)).format(now);
    return LedgerCard(
      margin: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => InsightsScreen(state: stream))),
      child: Row(
        children: [
          Icon(AppIcons.insights, color: p.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'home_insights_teaser'.tr(
                namedArgs: {
                  'month': month,
                  'amount': moneyLabel(context, i.totalMinor, i.currency),
                },
              ),
              style: AppTypography.bodyMedium.copyWith(color: p.textPrimary),
            ),
          ),
          Icon(
            Directionality.of(context) == TextDirection.rtl
                ? AppIcons.chevronLeft
                : AppIcons.chevronRight,
            color: p.textTertiary,
          ),
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
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: AppRadii.cardRadius,
              ),
              child: Icon(AppIcons.receipt, color: p.accent, size: 32),
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              'home_first_title'.tr(),
              style: AppTypography.headlineMedium.copyWith(
                color: p.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'home_first_body'.tr(),
            style: AppTypography.bodyLarge.copyWith(
              color: p.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.accent,
              foregroundColor: p.onAccent,
            ),
            onPressed: () => BillEntryPoints.scan(context),
            child: Text('new_scan_title'.tr()),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => BillEntryPoints.manual(context),
            child: Text('new_expense_title'.tr()),
          ),
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
      padding: EdgeInsetsDirectional.fromSTEB(20, 22, 20, 0),
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
  for (final p in s.people)
    GroupMember(id: p.id, name: p.name, photoUrl: p.photoUrl),
];
