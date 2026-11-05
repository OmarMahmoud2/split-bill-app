import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';

/// Top bar of the bill views: a round back button and round trailing
/// actions (share, more), hairline outlined, 44 pt.
class BillDetailsHeader extends StatelessWidget {
  const BillDetailsHeader({super.key, this.actions = const [], this.onBack});

  final List<Widget> actions;

  /// Defaults to `Navigator.maybePop`.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        0,
      ),
      child: Row(
        children: [
          BillCircleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            semanticLabel: 'bf_bill_back'.tr(),
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.md),
            actions[i],
          ],
        ],
      ),
    );
  }
}

/// 44 pt round, hairline-outlined icon button from the v3 boards.
class BillCircleButton extends StatelessWidget {
  const BillCircleButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Directional icons (the back arrow) mirror themselves in RTL.
    final glyph = Icon(icon, size: 18, color: p.textPrimary);
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: CircleBorder(side: BorderSide(color: p.hairline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Center(child: glyph)),
        ),
      ),
    );
  }
}

/// The 52 pt pill button: ink fill by default, ghost (outlined) with
/// [ghost]. Shows a small spinner when [busy].
class BillPillButton extends StatelessWidget {
  const BillPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.ghost = false,
    this.busy = false,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool ghost;
  final bool busy;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = destructive
        ? p.error
        : ghost
        ? p.textPrimary
        : p.onInverseSurface;
    final bg = ghost ? p.surface : p.inverseSurface;
    return SizedBox(
      height: AppSpacing.buttonLg,
      width: double.infinity,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: ghost
              ? BorderSide(color: destructive ? p.errorSoft : p.borderStrong)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else if (icon != null)
                  Icon(icon, size: 18, color: fg),
                if (busy || icon != null) const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLarge.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
