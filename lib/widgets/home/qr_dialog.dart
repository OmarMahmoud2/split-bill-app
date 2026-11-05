import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/utils/image_utils.dart';

/// "Your code": the current user's QR so a friend can add them to a bill.
class QrDialog {
  static void show(
    BuildContext context,
    String name,
    String? photoUrl,
    String qrData,
  ) {
    showDialog(
      context: context,
      barrierColor: context.palette.scrim,
      builder: (context) =>
          _QrDialogBody(name: name, photoUrl: photoUrl, qrData: qrData),
    );
  }
}

class _QrDialogBody extends StatelessWidget {
  const _QrDialogBody({
    required this.name,
    required this.photoUrl,
    required this.qrData,
  });

  final String name;
  final String? photoUrl;
  final String qrData;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // The code always sits on a light card with ink modules so any camera
    // can read it, in light and dark mode.
    const qrPalette = AppPalette.light;
    final avatar = ImageUtils.getAvatarImage(photoUrl);
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sheet)),
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 32,
                backgroundColor: p.avatarTintFor(name),
                backgroundImage: avatar,
                child: avatar == null
                    ? Text(
                        name.trim().isEmpty
                            ? '?'
                            : name.trim().substring(0, 1).toUpperCase(),
                        style: AppTypography.headlineMedium.copyWith(
                          color: p.textPrimary,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              name,
              textAlign: TextAlign.center,
              style: AppTypography.headlineMedium.copyWith(
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'bf_assign_your_code'.tr(),
              style: AppTypography.titleMedium.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              image: true,
              label: 'bf_assign_your_code_semantics'.tr(),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: qrPalette.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: qrPalette.border),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: qrPalette.surface,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: qrPalette.textPrimary,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: qrPalette.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'bf_assign_your_code_hint'.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: p.inverseSurface,
                  foregroundColor: p.onInverseSurface,
                  shape: const StadiumBorder(),
                  textStyle: AppTypography.labelLarge.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text('close'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
