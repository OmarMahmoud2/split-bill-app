import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:split_bill_app/bill_flow/bill_document.dart';
import 'package:split_bill_app/screens/edit_bill/widgets/participant_list.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/premium_bottom_sheet.dart';

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
  }) => PremiumBottomSheet.show<void>(
    context: context,
    child: ParticipantOptionsSheet(
      participant: participant,
      isPaid: isPaid,
      canRemove: canRemove,
      onTogglePaid: onTogglePaid,
      onRemove: onRemove,
    ),
  );

  Future<void> _confirmRemove(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'bf_edit_remove_person_title'.tr(
            namedArgs: {'name': participant.name},
          ),
        ),
        content: Text('bf_edit_remove_person_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('common_cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('common_remove'.tr()),
          ),
        ],
      ),
    );
    if (ok == true) {
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
                isPaid ? Icons.undo_rounded : Icons.check_circle_outline,
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
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: p.textPrimary,
                ),
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
