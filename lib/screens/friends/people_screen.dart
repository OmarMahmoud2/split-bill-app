/// "Settle with": everyone the user has an open balance with.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/ledger_repository.dart';
import 'package:split_bill_app/screens/friends/friend_detail_screen.dart';
import 'package:split_bill_app/screens/settle/quick_iou_sheet.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/feedback/feedback.dart';
import 'package:split_bill_app/widgets/home/home_dashboard.dart';
import 'package:split_bill_app/widgets/home/ledger_session.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/widgets/home/qr_dialog.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, this.state});
  final Stream<HomeLedgerState>? state;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  Stream<HomeLedgerState>? _stream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final me = LedgerMe.current();
    if (_stream == null && me != null) {
      _stream = widget.state ??
          watchHomeLedger(LedgerRepository.instance, me.uid, fallbackCurrency: preferredCurrency(context), looseLabel: 'friend_direct_label'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LedgerTopBar(
              title: 'home_settle_with'.tr(),
              actions: [
                RoundIconButton(
                  icon: AppIcons.qr,
                  tooltip: 'people_my_code'.tr(),
                  onPressed: () {
                    final me = LedgerMe.current();
                    if (me != null) QrDialog.show(context, me.name, me.photoUrl, me.uid);
                  },
                ),
              ],
            ),
            Expanded(
              child: StreamBuilder<HomeLedgerState>(
                stream: _stream,
                builder: (context, snap) {
                  if (snap.hasError) return ErrorState(onRetry: () => setState(() { _stream = null; didChangeDependencies(); }));
                  if (!snap.hasData) {
                    return const Padding(padding: EdgeInsets.all(20), child: SkeletonShimmer(child: Column(children: [SkeletonListTile(), SkeletonListTile(), SkeletonListTile()])));
                  }
                  final s = snap.data!;
                  final open = s.summary.open;
                  if (open.isEmpty) {
                    return EmptyState(
                      icon: AppIcons.success,
                      title: 'settle_all_square_title'.tr(),
                      message: 'people_all_square_body'.tr(),
                      actionLabel: 'iou_title'.tr(),
                      onAction: () => showQuickIouSheet(context, people: peopleAsMembers(s.summary)),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(0, 16, 0, 32),
                    children: [
                      LedgerCard(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: LedgerRows(
                          children: [
                            for (final person in open)
                              PersonBalanceRow(
                                person: person,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => FriendDetailScreen(friendId: person.id, state: widget.state)),
                                ),
                              ),
                          ],
                        ),
                      ),
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
