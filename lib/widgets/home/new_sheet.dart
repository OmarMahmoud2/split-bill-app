/// "New": one sheet for every way to start (scan, say it, expense, Quick IOU,
/// group or trip), plus the entry points other features plug into.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/data/models.dart';
import 'package:split_bill_app/manual_entry_screen.dart';
import 'package:split_bill_app/scan_receipt_screen.dart';
import 'package:split_bill_app/theme/theme.dart';
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

class NewSheetOption {
  const NewSheetOption({required this.badge, required this.title, required this.subtitle, required this.onTap, this.accent = false, this.soft = false});
  final String badge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;
  final bool soft;
}

/// Shows the "New" sheet. Every callback runs after the sheet closes.
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
  final options = [
    NewSheetOption(
      badge: 'new_badge_scan'.tr(),
      title: 'new_scan_title'.tr(),
      subtitle: 'new_scan_sub'.tr(),
      accent: true,
      onTap: () => after(() => BillEntryPoints.scan(context, members: members, groupId: groupId)),
    ),
    if (voice != null)
      NewSheetOption(
        badge: 'new_badge_say'.tr(),
        title: 'new_say_title'.tr(),
        subtitle: 'new_say_sub'.tr(),
        soft: true,
        onTap: () => after(() => voice(context, members: members, groupId: groupId)),
      ),
    NewSheetOption(
      badge: '+',
      title: 'new_expense_title'.tr(),
      subtitle: 'new_expense_sub'.tr(),
      onTap: () => after(() => BillEntryPoints.manual(context, members: members, groupId: groupId)),
    ),
    if (groupId == null)
      NewSheetOption(badge: 'new_badge_iou'.tr(), title: 'iou_title'.tr(), subtitle: 'new_iou_sub'.tr(), onTap: () => after(onQuickIou)),
    if (groupId == null)
      NewSheetOption(badge: 'new_badge_trip'.tr(), title: 'new_group_title'.tr(), subtitle: 'new_group_sub'.tr(), onTap: () => after(onStartGroup)),
  ];
  return showLedgerSheet<void>(context, builder: (_) => NewSheet(options: options));
}

class NewSheet extends StatelessWidget {
  const NewSheet({super.key, required this.options});
  final List<NewSheetOption> options;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('new_title'.tr(), style: AppTypography.headlineSmall.copyWith(color: p.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          for (final (i, o) in options.indexed)
            StaggeredEntrance(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LedgerCard(
                  onTap: () {
                    AppHaptics.light();
                    o.onTap();
                  },
                  semanticsLabel: '${o.title}. ${o.subtitle}',
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: o.accent ? p.accent : (o.soft ? p.accentSoft : p.surfaceVariant),
                            borderRadius: AppRadii.rowRadius,
                          ),
                          child: Text(
                            o.badge,
                            maxLines: 1,
                            style: AppTypography.labelSmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: o.accent ? p.onAccent : (o.soft ? p.onAccentSoft : p.textPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.title, style: AppTypography.titleSmall.copyWith(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                              Text(o.subtitle, style: AppTypography.bodySmall.copyWith(color: p.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
