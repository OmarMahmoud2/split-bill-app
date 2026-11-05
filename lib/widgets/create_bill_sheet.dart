import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// "Start a new bill": scan a receipt or type it in. Shown inside a
/// bottom sheet; the callbacks decide what happens (the sheet does not pop
/// itself).
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
    final p = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'start_a_new_bill'.tr(),
            style: AppTypography.headlineMedium.copyWith(color: p.textPrimary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _CreateBillOption(
          icon: Icons.document_scanner_outlined,
          title: 'scan_receipt'.tr(),
          subtitle:
              'best_when_you_already_have_the_bill_photo_or_want_camera_import'
                  .tr(),
          onTap: onScanTap,
          emphasized: true,
        ),
        const SizedBox(height: AppSpacing.md),
        _CreateBillOption(
          icon: Icons.edit_note_rounded,
          title: 'enter_manually'.tr(),
          subtitle:
              'build_the_receipt_yourself_then_continue_to_split_and_add_people'
                  .tr(),
          onTap: onManualTap,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _CreateBillOption extends StatelessWidget {
  const _CreateBillOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// The recommended option gets the teal tile; the other a neutral one.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: AppRadii.cardShape(p.border),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            AppHaptics.light();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: emphasized ? p.accentSoft : p.surfaceVariant,
                    borderRadius: AppRadii.rowRadius,
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: emphasized ? p.onAccentSoft : p.textPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: p.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right_rounded, color: p.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
