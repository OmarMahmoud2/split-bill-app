import 'package:easy_localization/easy_localization.dart'
    show StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// The app's confirm dialog: radius 24, icon tile, title, one sentence and
/// two full-width buttons (confirm on top, cancel below).
///
/// Resolves `true` when confirmed, `false` when cancelled or dismissed.
/// Pass [destructive] for deletes and removals: the tile and the confirm
/// button turn error red (the only place red is allowed).
Future<bool> showAppDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String? cancelLabel,
  IconData icon = AppIcons.help,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: context.palette.scrim,
    builder: (dialogContext) {
      final p = dialogContext.palette;
      final tone = destructive ? p.error : p.accent;
      return Dialog(
        backgroundColor: p.isDark ? p.surfaceVariant : p.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.dialogRadius,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: destructive ? p.errorSoft : p.accentSoft,
                      borderRadius: AppRadii.rowRadius,
                    ),
                    child: Icon(icon, size: 24, color: tone),
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTypography.headlineMedium.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: AppTypography.bodyMedium.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    AppHaptics.light();
                    Navigator.of(dialogContext).pop(true);
                  },
                  style: destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: p.error,
                          foregroundColor: p.onError,
                        )
                      : null,
                  child: Text(confirmLabel),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(cancelLabel ?? 'common_cancel'.tr()),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}
