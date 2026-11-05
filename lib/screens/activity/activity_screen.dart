/// Activity: bills and payments, newest first, by day, loaded a page at a
/// time (see [LedgerRepository.fetchActivity]).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/activity.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/money_text.dart';

/// "Sara added Taxi to Blue Hole" with its amount.
class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.item, required this.me, this.onTap});
  final ActivityItem item;
  final String me;
  final VoidCallback? onTap;

  String _what() {
    final title = item.title.isEmpty ? 'bill'.tr() : item.title;
    final other = item.counterpartId == null ? '' : personName(item.counterpartId!, item.counterpartName ?? '', me);
    switch (item.kind) {
      case ActivityKind.billAdded:
        return 'activity_added'.tr(namedArgs: {'title': title});
      case ActivityKind.payment:
        return item.counterpartId == me
            ? 'activity_paid_you'.tr()
            : 'activity_paid'.tr(namedArgs: {'name': other});
      case ActivityKind.iou:
        return item.counterpartId == me
            ? 'activity_owes_you'.tr()
            : 'activity_owes'.tr(namedArgs: {'name': other});
    }
  }

  String _when(BuildContext context) {
    final diff = DateTime.now().difference(item.date);
    final String ago;
    if (diff.inMinutes < 1) {
      ago = 'just_now'.tr();
    } else if (diff.inMinutes < 60) {
      ago = 'minutes_ago'.tr(namedArgs: {'count': '${diff.inMinutes}'});
    } else if (diff.inHours < 24) {
      ago = 'hours_ago'.tr(namedArgs: {'count': '${diff.inHours}'});
    } else {
      ago = DateFormat.MMMd(context.locale.toLanguageTag()).format(item.date);
    }
    final extra = <String>[ago];
    if (item.hasProof) extra.add('activity_proof_attached'.tr());
    if (item.kind == ActivityKind.billAdded && item.tone == ActivityTone.owe) {
      extra.add('activity_you_owe_them'.tr());
    }
    if (item.title.isNotEmpty && item.kind != ActivityKind.billAdded) extra.add(item.title);
    return extra.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final who = personName(item.actorId, item.actorName, me);
    final tone = switch (item.tone) {
      ActivityTone.owed => MoneyTone.owed,
      ActivityTone.owe => MoneyTone.owe,
      ActivityTone.neutral => MoneyTone.neutral,
    };
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: MergeSemantics(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LedgerAvatar(id: item.actorId, name: who),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: who, style: const TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(text: ' ${_what()}'),
                        ],
                      ),
                      style: AppTypography.bodyMedium.copyWith(color: p.textPrimary, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 2),
                    Text(_when(context), style: AppTypography.caption.copyWith(color: p.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MoneyText(
                minor: item.signedMinor,
                currency: item.currency,
                tone: tone,
                size: MoneySize.small,
                sign: item.tone == ActivityTone.neutral ? MoneySign.none : MoneySign.always,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _items = <ActivityItem>[];
  final _scroll = ScrollController();
  ActivityCursor? _cursor;
  bool _loading = false;
  bool _done = false;
  Object? _error;
  LedgerMe? _me;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_me == null) {
      _me = LedgerMe.current();
      _loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _done = false;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    final me = _me;
    if (me == null || _loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await LedgerRepository.instance.fetchActivity(
        me.uid,
        cursor: _cursor,
        fallbackCurrency: preferredCurrency(context),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.next;
        _done = page.next == null;
        _loading = false;
      });
      // Short first pages don't scroll, so keep filling the screen.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_done && _scroll.hasClients && _scroll.position.extentAfter < 400) _loadMore();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  String _dayLabel(BuildContext context, DateTime day) => switch (dayBucket(day, DateTime.now())) {
    DayBucket.today => 'activity_today'.tr(),
    DayBucket.yesterday => 'activity_yesterday'.tr(),
    DayBucket.earlier => DateFormat.MMMMEEEEd(context.locale.toLanguageTag()).format(day),
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final me = _me;
    final days = groupByDay(_items);
    Widget body;
    if (me == null) {
      body = ErrorState(title: 'please_log_in_2'.tr());
    } else if (_items.isEmpty && _error != null) {
      body = ErrorState(message: 'activity_load_failed'.tr(), onRetry: _refresh);
    } else if (_items.isEmpty && (_loading || !_done)) {
      body = const Padding(
        padding: EdgeInsets.all(20),
        child: SkeletonShimmer(
          child: Column(children: [SkeletonListTile(), SkeletonListTile(), SkeletonListTile(), SkeletonListTile()]),
        ),
      );
    } else if (_items.isEmpty) {
      body = EmptyState(icon: Icons.timeline_rounded, title: 'activity_empty_title'.tr(), message: 'activity_empty_body'.tr());
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            for (final (day, items) in days) ...[
              OverlineLabel(_dayLabel(context, day)),
              LedgerCard(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: LedgerRows(
                  children: [
                    for (final item in items)
                      ActivityRow(
                        item: item,
                        me: me.uid,
                        onTap: item.billId == null || item.kind != ActivityKind.billAdded
                            ? null
                            : () => openBill(context, billId: item.billId!, hostId: item.actorId, title: item.title, me: me.uid),
                      ),
                  ],
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: ErrorState.inline(message: 'activity_load_failed'.tr(), onRetry: _loadMore),
              )
            else if (!_done)
              const Padding(
                padding: EdgeInsets.all(20),
                child: SkeletonShimmer(child: SkeletonListTile()),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embedded) const LedgerTopBar(),
            ScreenTitle('activity_title'.tr()),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
