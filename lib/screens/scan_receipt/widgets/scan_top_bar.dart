import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// A 44 pt round hairline icon button (back, close, view photo).
class ScanRoundButton extends StatelessWidget {
  const ScanRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;

  /// Tooltip and screen reader label.
  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: p.surface,
          shape: CircleBorder(side: BorderSide(color: p.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 18, color: color ?? p.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// v3 top bar for the scan and manual screens: round back/close button, a
/// title with an optional subtitle, and trailing actions.
class ScanTopBar extends StatelessWidget implements PreferredSizeWidget {
  const ScanTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.close = false,
    this.onLeading,
    this.onTitleTap,
    this.titleTapLabel,
    this.trailing = const [],
  });

  final String title;
  final String? subtitle;

  /// Show an X instead of a back chevron.
  final bool close;

  /// Defaults to popping the route.
  final VoidCallback? onLeading;

  /// Makes the title tappable (e.g. edit store name and date).
  final VoidCallback? onTitleTap;
  final String? titleTapLabel;
  final List<Widget> trailing;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final titleColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: p.textPrimary,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              color: p.textSecondary,
            ),
          ),
      ],
    );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 10),
        child: Row(
          children: [
            ScanRoundButton(
              icon: close
                  ? AppIcons.close
                  : AppIcons.chevronLeft,
              label: close ? 'close'.tr() : 'back'.tr(),
              onPressed: onLeading ?? () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: onTitleTap == null
                  ? titleColumn
                  : Semantics(
                      button: true,
                      hint: titleTapLabel,
                      child: InkWell(
                        onTap: onTitleTap,
                        borderRadius: AppRadii.rowRadius,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: titleColumn,
                          ),
                        ),
                      ),
                    ),
            ),
            for (final w in trailing) ...[
              const SizedBox(width: AppSpacing.sm),
              w,
            ],
          ],
        ),
      ),
    );
  }
}
