import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class CreateBillSheet extends StatelessWidget {
  const CreateBillSheet({
    super.key,
    required this.onScanTap,
    required this.onManualTap,
  });

  final VoidCallback onScanTap;
  final VoidCallback onManualTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('start_a_new_bill',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ).tr(),
            const SizedBox(height: 8),
            Text('start_with_the_receipt_not_the_people_you_can_add_participants_right_after_the_bill_is_ready',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.68),
                height: 1.45,
              ),
            ).tr(),
            const SizedBox(height: 18),
            _CreateBillOption(
              icon: Icons.document_scanner_rounded,
              title: 'scan_receipt'.tr(),
              subtitle: 'best_when_you_already_have_the_bill_photo_or_want_camera_import'.tr(),
              accent: colorScheme.primary,
              onTap: onScanTap,
            ),
            const SizedBox(height: 12),
            _CreateBillOption(
              icon: Icons.edit_note_rounded,
              title: 'enter_manually'.tr(),
              subtitle: 'build_the_receipt_yourself_then_continue_to_split_and_add_people'.tr(),
              accent: colorScheme.secondary,
              onTap: onManualTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateBillOption extends StatelessWidget {
  const _CreateBillOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.66),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
