/// "New": one sheet for every way to start (scan, say it, expense, Quick IOU,
/// group or trip), plus the entry points other features plug into.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/manual_entry_screen.dart';
import 'package:split_bill_app/scan_receipt_screen.dart';
import 'package:split_bill_app/config/feature_costs.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/plural_text.dart';
import 'package:split_bill_app/utils/wallet_status.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';

typedef BillEntry = void Function(BuildContext context, {List<GroupMember>? members, String? groupId});

/// How ledger screens start a bill. [groupId] (with [members]) is carried
/// scan/manual -> assign -> summary -> the bill's `groupId`.
class BillEntryPoints {
  BillEntryPoints._();

  static List<Map<String, dynamic>>? _participants(List<GroupMember>? members) =>
      members?.map((m) => m.toMap()).toList();

  static BillEntry scan = (context, {members, groupId}) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ScanReceiptScreen(participants: _participants(members), groupId: groupId)),
  );

  static BillEntry manual = (context, {members, groupId}) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ManualEntryScreen(participants: _participants(members), groupId: groupId)),
  );

  /// "Say it": hidden (null) until a standalone voice expense exists. Voice
  /// assign needs items, so opening Scan under this name would mislead.
  static BillEntry? voice;
}

/// One way to start a bill (a method tile) or a secondary row (IOU, group).
class NewSheetOption {
  const NewSheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.cost,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Points a free user pays for this method; null = always free.
  final int? cost;
}

/// Shows the "Split a bill" sheet. Every callback runs after the sheet closes.
/// People are picked later in the flow (after the items), so this sheet is
/// just the method choice: one tap starts, no extra confirm.
Future<void> showNewSheet(
  BuildContext context, {
  required VoidCallback onQuickIou,
  required VoidCallback onStartGroup,
  List<GroupMember>? members,
  String? groupId,
}) {
  final nav = Navigator.of(context);
  void after(VoidCallback f) {
    nav.pop();
    f();
  }

  final voice = BillEntryPoints.voice;
  final methods = [
    NewSheetOption(
      icon: AppIcons.scan,
      title: 'new_scan_title'.tr(),
      subtitle: 'new_scan_sub'.tr(),
      cost: FeatureCosts.receiptScanPoints,
      onTap: () => after(() => BillEntryPoints.scan(context, members: members, groupId: groupId)),
    ),
    NewSheetOption(
      icon: AppIcons.edit,
      title: 'new_type_title'.tr(),
      subtitle: 'new_expense_sub'.tr(),
      onTap: () => after(() => BillEntryPoints.manual(context, members: members, groupId: groupId)),
    ),
    // Hidden until a standalone voice expense exists (voice assign needs items).
    if (voice != null)
      NewSheetOption(
        icon: AppIcons.mic,
        title: 'new_say_title'.tr(),
        subtitle: 'new_say_sub'.tr(),
        cost: FeatureCosts.voiceCommandPoints,
        onTap: () => after(() => voice(context, members: members, groupId: groupId)),
      ),
  ];
  final more = [
    if (groupId == null)
      NewSheetOption(icon: AppIcons.iou, title: 'iou_title'.tr(), subtitle: 'new_iou_sub'.tr(), onTap: () => after(onQuickIou)),
    if (groupId == null)
      NewSheetOption(icon: AppIcons.groups, title: 'new_group_title'.tr(), subtitle: 'new_group_sub'.tr(), onTap: () => after(onStartGroup)),
  ];
  return showLedgerSheet<void>(
    context,
    title: 'new_split_title'.tr(),
    subtitle: 'new_split_sub'.tr(),
    builder: (_) => NewSheet(methods: methods, more: more),
  );
}

class NewSheet extends StatefulWidget {
  const NewSheet({super.key, required this.methods, this.more = const []});
  final List<NewSheetOption> methods;
  final List<NewSheetOption> more;

  @override
  State<NewSheet> createState() => _NewSheetState();
}

class _NewSheetState extends State<NewSheet> {
  late final Future<({bool pro, int points})?> _wallet = loadWalletStatus();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 20),
      child: FutureBuilder(
        future: _wallet,
        builder: (context, snap) {
          final pro = snap.data?.pro ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, o) in widget.methods.indexed) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: _MethodTile(option: o, pro: pro)),
                    ],
                  ],
                ),
              ),
              for (final (i, o) in widget.more.indexed)
                StaggeredEntrance(
                  index: i,
                  child: Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 16 : 8),
                    child: LedgerCard(
                      onTap: () {
                        AppHaptics.light();
                        o.onTap();
                      },
                      semanticsLabel: '${o.title}. ${o.subtitle}',
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: ExcludeSemantics(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: p.surfaceVariant, borderRadius: AppRadii.rowRadius),
                              child: Icon(o.icon, size: 20, color: p.textPrimary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(o.title, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontWeight: FontWeight.w600)),
                                  Text(o.subtitle, style: AppTypography.bodySmall.copyWith(color: p.textSecondary)),
                                ],
                              ),
                            ),
                            Icon(AppIcons.chevronRight, size: 18, color: p.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.option, required this.pro});
  final NewSheetOption option;
  final bool pro;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cost = option.cost;
    final costText = cost == null
        ? 'new_cost_free'.tr()
        : pro
        ? 'new_cost_pro'.tr()
        : pluralText('new_cost_points', cost);
    return LedgerCard(
      onTap: () {
        AppHaptics.light();
        option.onTap();
      },
      semanticsLabel: '${option.title}. $costText',
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: p.accentSoft, borderRadius: AppRadii.rowRadius),
              child: Icon(option.icon, size: 24, color: p.onAccentSoft),
            ),
            const SizedBox(height: 10),
            Text(
              option.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            const SizedBox(height: 4),
            Text(
              costText,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: cost == null || pro ? p.accent : p.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
