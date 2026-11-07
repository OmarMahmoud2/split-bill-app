import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:split_bill_app/widgets/feedback/app_dialog.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/participant_list.dart';
import 'package:split_bill_app/theme/theme.dart';

/// Actions for one person on the bill: mark paid / not paid, remove.
/// The host (who paid the bill) cannot be removed.
class ParticipantOptionsSheet extends StatelessWidget {
  const ParticipantOptionsSheet({
    super.key,
    required this.participant,
    required this.isPaid,
    required this.canRemove,
    required this.onTogglePaid,
    required this.onRemove,
  });

  final BillParticipantInfo participant;
  final bool isPaid;
  final bool canRemove;
  final VoidCallback onTogglePaid;
  final VoidCallback onRemove;

  static Future<void> show(
    BuildContext context, {
    required BillParticipantInfo participant,
    required bool isPaid,
    required bool canRemove,
    required VoidCallback onTogglePaid,
    required VoidCallback onRemove,
  }) => showLedgerSheet<void>(
    context,
    builder: (_) => SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 24),
      child: ParticipantOptionsSheet(
        participant: participant,
        isPaid: isPaid,
        canRemove: canRemove,
        onTogglePaid: onTogglePaid,
        onRemove: onRemove,
      ),
    ),
  );

  Future<void> _confirmRemove(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ok = await showAppDialog(
      context,
      icon: AppIcons.personRemove,
      title: 'bf_edit_remove_person_title'.tr(
        namedArgs: {'name': participant.name},
      ),
      message: 'bf_edit_remove_person_body'.tr(),
      confirmLabel: 'common_remove'.tr(),
      destructive: true,
    );
    if (ok) {
      AppHaptics.warning();
      navigator.pop();
      onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            EditAvatar(
              id: participant.id,
              name: participant.name,
              photoUrl: participant.photoUrl,
              size: 44,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant.name,
                    style: AppTypography.headlineSmall.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                  if ((participant.phoneNumber ?? '').isNotEmpty)
                    Text(
                      participant.phoneNumber!,
                      textDirection: TextDirection.ltr,
                      style: AppTypography.bodySmall.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            EditStatusChip(paid: isPaid),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        EditCard(
          children: [
            ListTile(
              minTileHeight: 56,
              leading: Icon(
                isPaid ? AppIcons.undo : AppIcons.success,
                color: p.textPrimary,
              ),
              title: Text(
                (isPaid ? 'bf_edit_mark_not_paid' : 'bf_edit_mark_paid').tr(),
                style: AppTypography.titleMedium.copyWith(color: p.textPrimary),
              ),
              onTap: () {
                AppHaptics.selection();
                Navigator.of(context).pop();
                onTogglePaid();
              },
            ),
            if (canRemove)
              ListTile(
                minTileHeight: 56,
                leading: Icon(AppIcons.personRemove, color: p.textPrimary),
                title: Text(
                  'bf_edit_remove_person'.tr(),
                  style: AppTypography.titleMedium.copyWith(
                    color: p.textPrimary,
                  ),
                ),
                onTap: () => _confirmRemove(context),
              ),
          ],
        ),
        if (!canRemove) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'bf_edit_host_cannot_remove'.tr(),
            style: AppTypography.bodySmall.copyWith(color: p.textSecondary),
          ),
        ],
      ],
    );
  }
}
