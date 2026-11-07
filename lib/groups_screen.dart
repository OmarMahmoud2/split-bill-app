import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/ledger_math.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/screens/groups/create_group_screen.dart';
import 'package:split_bill_app/screens/groups/group_detail_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// Groups and trips, with the user's balance in each.
///
/// Inside the Home shell it shares the shell's [state] stream; opened on
/// its own (e.g. from Profile) it starts its own.
class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key, this.state, this.embedded = false});

  final Stream<HomeLedgerState>? state;

  /// In the tab bar (no back button).
  final bool embedded;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  Stream<HomeLedgerState>? _own;
  LedgerMe? _me;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _me ??= LedgerMe.current();
    if (widget.state == null && _own == null && _me != null) {
      _own = watchHomeLedger(
        LedgerRepository.instance,
        _me!.uid,
        fallbackCurrency: preferredCurrency(context),
        looseLabel: 'friend_direct_label'.tr(),
      ).asBroadcastStream();
    }
  }

  void _create() {
    AppHaptics.light();
    Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CreateGroupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final me = _me;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embedded) LedgerTopBar(actions: [RoundIconButton(icon: AppIcons.add, tooltip: 'groups_new_title'.tr(), onPressed: _create)]),
            ScreenTitle(
              'groups'.tr(),
              trailing: widget.embedded
                  ? RoundIconButton(icon: AppIcons.add, tooltip: 'groups_new_title'.tr(), onPressed: _create)
                  : null,
            ),
            Expanded(
              child: me == null
                  ? ErrorState(title: 'please_log_in_2'.tr())
                  : StreamBuilder<HomeLedgerState>(
                      stream: widget.state ?? _own,
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return ErrorState(onRetry: () => setState(() { _own = null; didChangeDependencies(); }));
                        }
                        if (!snap.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(20),
                            child: SkeletonShimmer(
                              child: Column(children: [SkeletonCard(), SizedBox(height: 10), SkeletonCard(), SizedBox(height: 10), SkeletonCard()]),
                            ),
                          );
                        }
                        final state = snap.data!;
                        if (state.groups.isEmpty) {
                          return EmptyState(
                            icon: AppIcons.people,
                            title: 'groups_empty_title'.tr(),
                            message: 'groups_empty_body'.tr(),
                            actionLabel: 'groups_new_title'.tr(),
                            onAction: _create,
                          );
                        }
                        final active = state.groups.where((g) => !g.archived).toList();
                        final archived = state.groups.where((g) => g.archived).toList();
                        return ListView(
                          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 120),
                          children: [
                            for (final (i, g) in active.indexed)
                              StaggeredEntrance(
                                index: i,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GroupCard(group: g, input: state.input(g.id), me: me.uid),
                                ),
                              ),
                            if (archived.isNotEmpty) ...[
                              OverlineLabel('groups_archived_section'.tr(), padding: const EdgeInsets.only(top: 12, bottom: 8)),
                              for (final g in archived)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GroupCard(group: g, input: null, me: me.uid),
                                ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One group in the list: name, bills, the user's balance and members.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.group, required this.input, required this.me, this.compact = false});

  final LedgerGroup group;
  final GroupLedgerInput? input;
  final String me;

  /// Home's two-up variant: name, subtitle, amount.
  final bool compact;

  static String subtitle(LedgerGroup group, GroupLedgerInput? input, BuildContext context) {
    final bills = input?.bills.where((b) => !b.isDraft).length ?? 0;
    final parts = <String>[
      bills == 1 ? 'groups_one_bill'.tr() : 'groups_n_bills'.tr(namedArgs: {'count': '$bills'}),
    ];
    final end = group.endDate;
    if (end != null && !group.archived) {
      final today = DateTime.now();
      final days = DateTime(end.year, end.month, end.day).difference(DateTime(today.year, today.month, today.day)).inDays;
      if (days == 0) {
        parts.add('groups_ends_today'.tr());
      } else if (days == 1) {
        parts.add('groups_ends_tomorrow'.tr());
      } else if (days > 1 && days <= 14) {
        parts.add('groups_ends_in_days'.tr(namedArgs: {'count': '$days'}));
      }
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final view = input?.view;
    final balance = view?.balanceOf(me) ?? const <String, int>{};
    final headline = headlineAmount(balance, group.currency ?? preferredCurrency(context));
    final amount = group.archived
        ? Text('groups_archived_tag'.tr(), style: AppTypography.labelMedium.copyWith(color: p.textSecondary))
        : headline == null
        ? Text('groups_settled'.tr(), style: AppTypography.amount.copyWith(color: p.textSecondary, fontSize: compact ? 16 : 17))
        : MoneyText(minor: headline.value, currency: headline.key, sign: MoneySign.always, style: compact ? const TextStyle(fontSize: 16) : null);
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: group.id)));

    if (compact) {
      return LedgerCard(
        onTap: open,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              '${plainMemberCount(group.members.length)} · ${subtitle(group, input, context)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: p.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            AvatarStack(people: [for (final m in group.members) (m.id, m.name, m.photoUrl)], size: 22, max: 3),
            const SizedBox(height: 8),
            amount,
          ],
        ),
      );
    }

    return LedgerCard(
      onTap: open,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle(group, input, context), style: AppTypography.bodySmall.copyWith(color: p.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              amount,
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AvatarStack(people: [for (final m in group.members) (m.id, m.name, m.photoUrl)]),
              const Spacer(),
              Text(group.type.labelKey.tr(), style: AppTypography.labelSmall.copyWith(color: p.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
