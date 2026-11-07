import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// v3 top bar: round leading button, centered-ish title, text action on the
/// end ("Cancel (x) / Edit bill / Save"). The action shows a small spinner
/// while [busy].
class EditBillHeader extends StatelessWidget {
  const EditBillHeader({
    super.key,
    required this.title,
    required this.onLeading,
    this.leadingIcon = AppIcons.close,
    this.leadingTooltip,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  final String title;
  final VoidCallback onLeading;
  final IconData leadingIcon;
  final String? leadingTooltip;
  final String? actionLabel;

  /// Null disables the action.
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Row(
        children: [
          Tooltip(
            message: leadingTooltip ?? 'common_cancel'.tr(),
            child: Material(
              color: p.surface,
              shape: CircleBorder(side: BorderSide(color: p.border)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onLeading,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    leadingIcon,
                    size: 18,
                    color: p.textPrimary,
                    semanticLabel: leadingTooltip ?? 'common_cancel'.tr(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.titleLarge.copyWith(color: p.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (actionLabel != null)
            busy
                ? SizedBox(
                    width: 64,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.accent,
                        ),
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: p.primaryStrong,
                      textStyle: AppTypography.titleMedium,
                    ),
                    child: Text(actionLabel!),
                  ),
        ],
      ),
    );
  }
}
