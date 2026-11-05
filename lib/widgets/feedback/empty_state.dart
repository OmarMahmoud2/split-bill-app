import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_spacing.dart';
import 'package:split_bill_app/theme/app_typography.dart';

/// "Nothing here yet" with one next step. No illustration: a quiet icon in
/// a tonal circle, a title, one line of help and an optional action.
///
/// ```dart
/// EmptyState(
///   icon: Icons.receipt_long_rounded,
///   title: 'no_bills_yet'.tr(),
///   message: 'scan_a_receipt_to_start'.tr(),
///   actionLabel: 'scan_receipt'.tr(),
///   onAction: _scan,
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;

  /// Defaults to `feedback_empty_title`.
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Smaller paddings for use inside a card or list section.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final circle = compact ? 48.0 : 64.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.lg : 28,
          vertical: compact ? AppSpacing.lg : AppSpacing.xxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: circle,
                  height: circle,
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: circle * 0.45, color: p.onAccentSoft),
                ),
              ),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.xl),
              Text(
                title ?? 'feedback_empty_title'.tr(),
                textAlign: TextAlign.center,
                style:
                    (compact
                            ? AppTypography.titleLarge
                            : AppTypography.headlineMedium)
                        .copyWith(color: p.textPrimary),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge.copyWith(
                    color: p.textSecondary,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xxl),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
