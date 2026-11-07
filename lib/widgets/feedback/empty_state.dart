import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_spacing.dart';
import 'package:split_bill_app/theme/app_typography.dart';
import 'package:split_bill_app/theme/app_icons.dart';
import 'package:split_bill_app/widgets/home/ledger_ui.dart';

/// "Nothing here yet" with one next step: a group of pal avatars ([palSeeds])
/// or an icon in a mint tile, a title, one line of help and an optional
/// action.
///
/// ```dart
/// EmptyState(
///   icon: AppIcons.receipt,
///   title: 'no_bills_yet'.tr(),
///   message: 'scan_a_receipt_to_start'.tr(),
///   actionLabel: 'scan_receipt'.tr(),
///   onAction: _scan,
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = AppIcons.inbox,
    this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.palSeeds = const [],
  });

  final IconData icon;

  /// Defaults to `feedback_empty_title`.
  final String? title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Smaller paddings for use inside a card or list section.
  final bool compact;

  /// Shows an overlapping group of pals (one per seed) instead of the icon.
  final List<String> palSeeds;

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
                child: palSeeds.isNotEmpty
                    ? AvatarStack(
                        people: [for (final s in palSeeds) (s, s, null)],
                        size: compact ? 40 : 56,
                        max: 4,
                      )
                    : Container(
                        width: circle,
                        height: circle,
                        decoration: BoxDecoration(
                          color: p.accentSoft,
                          borderRadius: AppRadii.cardRadius,
                        ),
                        child: Icon(
                          icon,
                          size: circle * 0.45,
                          color: p.onAccentSoft,
                        ),
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
