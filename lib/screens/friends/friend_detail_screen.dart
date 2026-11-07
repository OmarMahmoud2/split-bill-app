/// Friend: everything between you two, across groups, bills and IOUs.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/ledger_math.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/screens/groups/group_detail_screen.dart';
import 'package:split_bill_app/screens/settle/quick_iou_sheet.dart';
import 'package:split_bill_app/screens/settle/settle_actions.dart';
import 'package:split_bill_app/screens/settle/settle_up_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/money_text.dart';

class FriendDetailScreen extends StatefulWidget {
  const FriendDetailScreen({super.key, required this.friendId, this.state});

  final String friendId;

  /// The Home shell's stream, when opened from Home.
  final Stream<HomeLedgerState>? state;

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  Stream<HomeLedgerState>? _stream;
  LedgerMe? _me;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _me ??= LedgerMe.current();
    if (_stream == null && _me != null) {
      _stream = widget.state ??
          watchHomeLedger(LedgerRepository.instance, _me!.uid, fallbackCurrency: preferredCurrency(context), looseLabel: 'friend_direct_label'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: StreamBuilder<HomeLedgerState>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Column(children: [const LedgerTopBar(), Expanded(child: ErrorState(onRetry: () => setState(() { _stream = null; didChangeDependencies(); })))]);
            }
            if (!snap.hasData) {
              return Column(
                children: const [
                  LedgerTopBar(),
                  SizedBox(height: 20),
                  SkeletonShimmer(child: Column(children: [Skeleton.circle(size: 72), SizedBox(height: 16), Skeleton.line(width: 120), SizedBox(height: 24), Padding(padding: EdgeInsets.all(20), child: SkeletonCard())])),
                ],
              );
            }
            final state = snap.data!;
            final friend = state.summary.person(widget.friendId);
            if (friend == null) {
              return Column(
                children: [
                  const LedgerTopBar(),
                  Expanded(child: EmptyState(icon: AppIcons.you, title: 'friend_nothing_title'.tr(), message: 'friend_nothing_body'.tr())),
                ],
              );
            }
            return _body(context, state, friend);
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, HomeLedgerState state, Counterparty friend) {
    final p = context.palette;
    final headline = friend.primary(preferredCurrency(context));
    final owesMe = (headline?.value ?? 0) > 0;
    final label = headline == null
        ? 'friend_all_square'.tr(namedArgs: {'name': friend.name})
        : owesMe
        ? 'friend_owes_you'.tr(namedArgs: {'name': friend.name})
        : 'friend_you_owe'.tr(namedArgs: {'name': friend.name});
    final others = friend.net.entries.where((e) => e.key != headline?.key && e.value != 0).toList();
    final bills = [...state.recentBills, for (final g in state.groupInputs) ...g.bills];
    final groupContexts = friend.contexts.where((c) => c.groupId != null).length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        const LedgerTopBar(),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
          child: Column(
            children: [
              LedgerAvatar(id: friend.id, name: friend.name, photoUrl: friend.photoUrl, size: 72),
              const SizedBox(height: 8),
              Semantics(header: true, child: Text(friend.name, style: AppTypography.titleLarge.copyWith(color: p.textPrimary, fontSize: 20, fontWeight: FontWeight.w600))),
              const SizedBox(height: 4),
              Text(label, style: AppTypography.bodyMedium.copyWith(color: p.textSecondary)),
              if (headline != null)
                MoneyText(minor: headline.value, currency: headline.key, sign: MoneySign.always, size: MoneySize.large, style: const TextStyle(fontSize: 40), animate: true),
              for (final e in others)
                MoneyText(minor: e.value, currency: e.key, sign: MoneySign.always, size: MoneySize.small),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: headline == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettleUpScreen.friend(friendId: friend.id))),
                  child: Text('settle_up_title'.tr()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: owesMe
                      ? () => nudgePerson(
                          context,
                          targetId: friend.id,
                          targetName: friend.name,
                          amountMinor: headline!.value,
                          currency: headline.key,
                          bills: bills,
                        )
                      : () => showQuickIouSheet(
                          context,
                          people: const [],
                          initialPerson: GroupMember(id: friend.id, name: friend.name, photoUrl: friend.photoUrl),
                        ),
                  child: Text(owesMe ? 'friend_nudge'.tr() : 'iou_title'.tr()),
                ),
              ),
            ],
          ),
        ),
        OverlineLabel(
          groupContexts == 0
              ? 'friend_history'.tr()
              : groupContexts == 1
              ? 'friend_across_one_group'.tr()
              : 'friend_across_groups'.tr(namedArgs: {'count': '$groupContexts'}),
        ),
        LedgerCard(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          child: LedgerRows(
            children: [
              for (final c in friend.contexts)
                InkWell(
                  onTap: c.groupId == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: c.groupId!))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: MergeSemantics(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.label.isEmpty ? 'friend_direct_label'.tr() : c.label, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                                Text(
                                  c.billCount == 0
                                      ? (c.lastBillTitle ?? 'friend_iou_only'.tr())
                                      : c.billCount == 1
                                      ? 'groups_one_bill'.tr()
                                      : 'groups_n_bills'.tr(namedArgs: {'count': '${c.billCount}'}),
                                  style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if (c.net.isEmpty)
                            MoneyText(minor: 0, currency: headline?.key ?? preferredCurrency(context), tone: MoneyTone.neutral)
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [for (final e in c.net.entries) MoneyText(minor: e.value, currency: e.key, sign: MoneySign.always)],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
          child: TextButton.icon(
            onPressed: () => showQuickIouSheet(
              context,
              people: const [],
              initialPerson: GroupMember(id: friend.id, name: friend.name, photoUrl: friend.photoUrl),
            ),
            icon: const Icon(AppIcons.add),
            label: Text('friend_add_iou'.tr(namedArgs: {'name': friend.name})),
          ),
        ),
      ],
    );
  }
}
