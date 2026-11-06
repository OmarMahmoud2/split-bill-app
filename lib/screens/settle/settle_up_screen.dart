/// Settle up: the fewest payments that square a group (simplifyDebts), or
/// everything between the user and one friend. Each row pays (payments
/// registry -> launcher), records cash, or nudges.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/ledger_math.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/domain/settlement.dart';
import 'package:split_bill_app/screens/settle/pay_sheet.dart';
import 'package:split_bill_app/screens/settle/settle_actions.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// One suggested payment and where it belongs.
class SettleRow {
  const SettleRow({
    required this.transfer,
    required this.groupId,
    required this.label,
  });
  final Transfer transfer;
  final String? groupId;
  final String label;

  String get key =>
      '${groupId ?? ''}|${transfer.currency}|${transfer.from}|${transfer.to}';
}

/// Rows for everything between [me] and [friend] (one per group/currency).
List<SettleRow> friendSettleRows(Counterparty friend, String me) => [
  for (final c in friend.contexts)
    for (final e in c.net.entries)
      if (e.value != 0)
        SettleRow(
          groupId: c.groupId,
          label: c.label,
          transfer: e.value > 0
              ? Transfer(
                  currency: e.key,
                  from: friend.id,
                  to: me,
                  amount: e.value,
                )
              : Transfer(
                  currency: e.key,
                  from: me,
                  to: friend.id,
                  amount: -e.value,
                ),
        ),
];

class SettleUpScreen extends StatefulWidget {
  /// Settle a whole group.
  const SettleUpScreen.group({super.key, required String this.groupId})
    : friendId = null;

  /// Settle everything with one person.
  const SettleUpScreen.friend({super.key, required String this.friendId})
    : groupId = null;

  final String? groupId;
  final String? friendId;

  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  Stream<Object?>? _stream;
  final _done = <String, SettleRow>{};
  final _busy = <String>{};
  LedgerMe? _me;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream != null) return;
    _me = LedgerMe.current();
    final repo = LedgerRepository.instance;
    final fallback = preferredCurrency(context);
    if (_me == null) return;
    _stream = widget.groupId != null
        ? watchGroupLedger(repo, widget.groupId!, fallbackCurrency: fallback)
        : watchHomeLedger(
            repo,
            _me!.uid,
            fallbackCurrency: fallback,
            looseLabel: 'friend_direct_label'.tr(),
          );
  }

  String _name(String id, Map<String, String> names) =>
      personName(id, names[id] ?? '', _me!.uid);

  Future<void> _record(
    SettleRow row,
    String method, {
    required Map<String, String> names,
    required List<SettleRow> open,
    GroupLedgerInput? group,
  }) async {
    final t = row.transfer;
    final me = _me!;
    setState(() => _busy.add(row.key));
    final payment = PaymentRecord(
      id: '',
      from: t.from,
      to: t.to,
      fromName: names[t.from] ?? (t.from == me.uid ? me.name : null),
      toName: names[t.to] ?? (t.to == me.uid ? me.name : null),
      amountMinor: t.amount,
      currency: t.currency,
      method: method,
      groupId: row.groupId,
      createdBy: me.uid,
    );
    final last =
        group != null && open.length == 1 && open.single.key == row.key;
    final myBefore = group?.view.balanceOf(me.uid)[t.currency] ?? 0;
    final ok = await recordPaymentWithFeedback(
      context,
      payment: payment,
      settlesGroup: last,
      groupName: group?.group.name,
      myBalanceBefore: myBefore,
      billCount: group?.bills.where((b) => !b.isDraft).length ?? 0,
      peopleCount: group?.group.members.length ?? 0,
      paymentCount: _done.length + 1,
      onArchive: group == null || group.group.createdBy != me.uid
          ? null
          : () => LedgerRepository.instance.updateGroup(group.group.id, {
              'archived': true,
            }),
    );
    if (!mounted) return;
    setState(() {
      _busy.remove(row.key);
      if (ok) _done[row.key] = row;
    });
  }

  Future<void> _pay(
    SettleRow row,
    Map<String, String> names,
    List<SettleRow> open,
    GroupLedgerInput? group,
    Set<String> guests,
  ) async {
    final t = row.transfer;
    final result = await showPaySheet(
      context,
      recipientId: t.to,
      recipientName: _name(t.to, names),
      amountMinor: t.amount,
      currency: t.currency,
      contextLabel: row.label,
      recipientHasAccount: !guests.contains(t.to),
    );
    if (result == null || !mounted) return;
    await _record(row, result.method, names: names, open: open, group: group);
  }

  Future<void> _cash(
    SettleRow row,
    Map<String, String> names,
    List<SettleRow> open,
    GroupLedgerInput? group,
  ) async {
    final t = row.transfer;
    final ok = await confirmCashPayment(
      context,
      fromName: _name(t.from, names),
      toName: _name(t.to, names),
      amount: moneyLabel(context, t.amount, t.currency),
      fromIsMe: t.from == _me?.uid,
      toIsMe: t.to == _me?.uid,
    );
    if (!ok || !mounted) return;
    await _record(row, 'cash', names: names, open: open, group: group);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final me = _me;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: me == null
            ? ErrorState(title: 'please_log_in_2'.tr())
            : StreamBuilder<Object?>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Column(
                      children: [
                        LedgerTopBar(title: 'settle_up_title'.tr()),
                        Expanded(
                          child: ErrorState(
                            message: 'settle_load_failed'.tr(),
                            onRetry: () => setState(() {
                              _stream = null;
                              didChangeDependencies();
                            }),
                          ),
                        ),
                      ],
                    );
                  }
                  if (!snap.hasData) return _skeleton();
                  return _content(context, snap.data, me);
                },
              ),
      ),
    );
  }

  Widget _skeleton() => Column(
    children: [
      LedgerTopBar(title: 'settle_up_title'.tr()),
      const Padding(
        padding: EdgeInsets.all(20),
        child: SkeletonShimmer(
          child: Column(
            children: [
              SkeletonCard(),
              SizedBox(height: 10),
              SkeletonCard(),
              SizedBox(height: 10),
              SkeletonCard(),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _content(BuildContext context, Object? data, LedgerMe me) {
    final p = context.palette;
    GroupLedgerInput? group;
    final List<SettleRow> open;
    final names = <String, String>{me.uid: me.name};
    final guests = <String>{};
    final List<BillRecord> bills;
    String title;
    int naive = 0;

    if (data is GroupLedgerInput) {
      group = data;
      final view = data.view;
      open = [
        for (final t in view.allTransfers)
          SettleRow(
            transfer: t,
            groupId: data.group.id,
            label: data.group.name,
          ),
      ];
      for (final m in data.group.members) {
        if (m.name.isNotEmpty) names[m.id] = m.name;
        if (m.isGuest) guests.add(m.id);
      }
      for (final b in data.bills) {
        for (final s in b.participants) {
          names.putIfAbsent(s.id, () => s.name);
        }
      }
      bills = data.bills;
      naive = view.unsimplifiedCount;
      title = 'settle_up_in'.tr(namedArgs: {'group': data.group.name});
    } else if (data is HomeLedgerState) {
      final friend = data.summary.person(widget.friendId!);
      open = friend == null ? const [] : friendSettleRows(friend, me.uid);
      if (friend != null) names[friend.id] = friend.name;
      bills = [
        ...data.recentBills,
        for (final g in data.groupInputs) ...g.bills,
      ];
      title = 'settle_up_with'.tr(namedArgs: {'name': friend?.name ?? ''});
    } else {
      return Column(
        children: [
          LedgerTopBar(title: 'settle_up_title'.tr()),
          Expanded(
            child: ErrorState(
              title: 'groups_not_found'.tr(),
              message: 'groups_not_found_body'.tr(),
            ),
          ),
        ],
      );
    }

    final openKeys = {for (final r in open) r.key};
    final done = _done.values.where((r) => !openKeys.contains(r.key)).toList();
    final count = open.length;

    return Column(
      children: [
        LedgerTopBar(title: title),
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 32),
            children: [
              if (count == 0 && done.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'settle_all_square_title'.tr(),
                    message: 'settle_all_square_body'.tr(),
                  ),
                )
              else ...[
                Semantics(
                  header: true,
                  child: Text(
                    count == 0
                        ? 'settle_all_square_title'.tr()
                        : count == 1
                        ? 'settle_one_payment_settles'.tr()
                        : 'settle_n_payments_settle'.tr(
                            namedArgs: {'count': '$count'},
                          ),
                    style: AppTypography.headlineLarge.copyWith(
                      color: p.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (group != null && naive > count && count > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'settle_instead_of'.tr(namedArgs: {'count': '$naive'}),
                      style: AppTypography.bodyMedium.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                for (final (i, row) in open.indexed)
                  StaggeredEntrance(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SettleCard(
                        row: row,
                        me: me.uid,
                        names: names,
                        busy: _busy.contains(row.key),
                        onPay: () => _pay(row, names, open, group, guests),
                        onCash: () => _cash(row, names, open, group),
                        onNudge: () {
                          final debtor = row.transfer.from;
                          nudgePerson(
                            context,
                            targetId: debtor,
                            targetName: _name(debtor, names),
                            amountMinor: row.transfer.amount,
                            currency: row.transfer.currency,
                            bills: bills,
                            contextLabel: row.label,
                          );
                        },
                        canNudge: !guests.contains(row.transfer.from),
                        showContext: group == null,
                      ),
                    ),
                  ),
                for (final row in done)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SettleCard(
                      row: row,
                      me: me.uid,
                      names: names,
                      settled: true,
                      showContext: group == null,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettleCard extends StatelessWidget {
  const _SettleCard({
    required this.row,
    required this.me,
    required this.names,
    this.settled = false,
    this.busy = false,
    this.onPay,
    this.onCash,
    this.onNudge,
    this.canNudge = true,
    this.showContext = false,
  });

  final bool showContext;
  final SettleRow row;
  final String me;
  final Map<String, String> names;
  final bool settled;
  final bool busy;
  final VoidCallback? onPay;
  final VoidCallback? onCash;
  final VoidCallback? onNudge;
  final bool canNudge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = row.transfer;
    final from = names[t.from] ?? '';
    final to = names[t.to] ?? '';
    final String line;
    if (t.from == me) {
      line = 'settle_you_pay'.tr(namedArgs: {'name': to});
    } else if (t.to == me) {
      line = 'settle_pays_you'.tr(namedArgs: {'name': from});
    } else {
      line = 'settle_pays'.tr(namedArgs: {'from': from, 'to': to});
    }
    final tone = t.to == me
        ? MoneyTone.owed
        : (t.from == me ? MoneyTone.owe : MoneyTone.neutral);
    final arrow = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;

    final buttons = <Widget>[];
    if (!settled) {
      if (t.from == me) {
        buttons.add(
          Expanded(
            child: FilledButton(
              onPressed: busy ? null : onPay,
              style: _small,
              child: Text('settle_pay_name'.tr(namedArgs: {'name': to})),
            ),
          ),
        );
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : onCash,
              style: _smallOutlined,
              child: Text('settle_record_cash'.tr()),
            ),
          ),
        );
      } else if (t.to == me) {
        buttons.add(
          Expanded(
            child: FilledButton(
              onPressed: busy || !canNudge ? null : onNudge,
              style: _small,
              child: Text('settle_nudge_name'.tr(namedArgs: {'name': from})),
            ),
          ),
        );
        buttons.add(const SizedBox(width: 8));
        buttons.add(
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : onCash,
              style: _smallOutlined,
              child: Text('settle_record_cash'.tr()),
            ),
          ),
        );
      } else if (canNudge) {
        buttons.add(
          Expanded(
            child: OutlinedButton(
              onPressed: onNudge,
              style: _smallOutlined,
              child: Text('settle_remind_name'.tr(namedArgs: {'name': from})),
            ),
          ),
        );
      }
    }

    return AnimatedOpacity(
      duration: AppMotion.durationFor(context, AppMotion.slow),
      opacity: settled ? 0.6 : 1,
      child: LedgerCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MergeSemantics(
              child: Row(
                children: [
                  LedgerAvatar(id: t.from, name: from),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(arrow, size: 18, color: p.textTertiary),
                  ),
                  LedgerAvatar(id: t.to, name: to),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line,
                          style: AppTypography.titleSmall.copyWith(
                            color: p.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (showContext && row.label.isNotEmpty)
                          Text(
                            row.label,
                            style: AppTypography.bodySmall.copyWith(
                              color: p.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  MoneyText(
                    minor: t.amount,
                    currency: t.currency,
                    tone: tone,
                    sign: MoneySign.none,
                  ),
                ],
              ),
            ),
            if (buttons.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(children: buttons),
            ],
            if (settled)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'settle_settled_label'.tr(),
                  style: AppTypography.labelMedium.copyWith(
                    color: p.owed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static final _small = FilledButton.styleFrom(
    minimumSize: const Size(44, 44),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: AppTypography.labelMedium.copyWith(fontSize: 14),
  );
  static final _smallOutlined = OutlinedButton.styleFrom(
    minimumSize: const Size(44, 44),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    textStyle: AppTypography.labelMedium.copyWith(fontSize: 14),
  );
}
