import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// The scan start screen: take or choose a photo, type it in, or snap now
/// and split later. With an [image] (a resumed draft, or after a failed
/// read) it shows the photo with "Read receipt" and "Retake photo".
///
/// [errorCard] (a `ScanErrorCard`) sits on top when the last try failed.
class ScanEmptyState extends StatelessWidget {
  const ScanEmptyState({
    super.key,
    required this.image,
    required this.onSnapAndSave,
    required this.onAnalyze,
    required this.onTakePhoto,
    required this.onChoosePhoto,
    required this.onTypeItIn,
    this.errorCard,
  });

  final File? image;
  final VoidCallback onSnapAndSave;
  final VoidCallback onAnalyze;
  final VoidCallback onTakePhoto;
  final VoidCallback onChoosePhoto;
  final VoidCallback onTypeItIn;
  final Widget? errorCard;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasImage = image != null;

    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: AppRadii.rowRadius,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: Image.file(
                  image!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  semanticLabel: 'bf_scan_ready_title'.tr(),
                  errorBuilder: (_, _, _) => const SizedBox(height: 120),
                ),
              ),
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.scan,
                  color: p.onAccentSoft,
                  size: 26,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            hasImage ? 'bf_scan_ready_title'.tr() : 'bf_scan_title'.tr(),
            style: AppTypography.headlineMedium.copyWith(
              fontSize: 24,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            hasImage ? 'bf_scan_ready_hint'.tr() : 'bf_scan_idle_hint'.tr(),
            style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (hasImage) ...[
            FilledButton.icon(
              key: const ValueKey('scan-read-now'),
              onPressed: onAnalyze,
              icon: const Icon(AppIcons.sparkle, size: 18),
              label: Text('bf_scan_read_now'.tr()),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onTakePhoto,
              icon: const Icon(AppIcons.camera, size: 18),
              label: Text('bf_scan_retake'.tr()),
            ),
          ] else ...[
            FilledButton.icon(
              key: const ValueKey('scan-take-photo'),
              onPressed: onTakePhoto,
              icon: const Icon(AppIcons.camera, size: 18),
              label: Text('bf_scan_take_photo'.tr()),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onChoosePhoto,
              icon: const Icon(AppIcons.gallery, size: 18),
              label: Text('bf_scan_choose_photo'.tr()),
            ),
          ],
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (errorCard != null) ...[errorCard!, const SizedBox(height: 14)],
          card,
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              TextButton.icon(
                onPressed: onTypeItIn,
                style: TextButton.styleFrom(foregroundColor: p.accent),
                icon: const Icon(AppIcons.edit, size: 18),
                label: Text('bf_scan_type_it_in'.tr()),
              ),
              if (!hasImage)
                TextButton.icon(
                  onPressed: onSnapAndSave,
                  style: TextButton.styleFrom(foregroundColor: p.accent),
                  icon: const Icon(AppIcons.bolt, size: 18),
                  label: Text('snap_now_and_split_later'.tr()),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
