/// v3 "Quiet ledger" building blocks for settings-style screens (Profile,
/// Payment methods, Reminders, Subscription, Admin, Export).
///
/// Cards with hairline borders, 44 pt round icon buttons, sentence-case section
/// labels and rows that are at least 52 pt tall. Colors come from
/// `context.palette` only.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';

/// Round 44 pt icon button with a hairline (back, close).
class V3IconButton extends StatelessWidget {
  const V3IconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  /// Back button (mirrors in RTL).
  factory V3IconButton.back(BuildContext context, {VoidCallback? onPressed}) =>
      V3IconButton(
        icon: AppIcons.back,
        semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      );

  /// Close button.
  factory V3IconButton.close(BuildContext context, {VoidCallback? onPressed}) =>
      V3IconButton(
        icon: AppIcons.close,
        semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
      );

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: p.surface,
        shape: CircleBorder(side: BorderSide(color: p.hairline)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 18, color: p.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Top bar used on v3 screens: [leading] round button, title, [trailing].
class V3TopBar extends StatelessWidget {
  const V3TopBar({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.large = false,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  /// A 26–28 pt page title (Admin, Activity) instead of the 17 pt bar title.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: large
                    ? AppTypography.displaySmall.copyWith(
                        color: p.textPrimary,
                      )
                    : AppTypography.titleLarge.copyWith(color: p.textPrimary),
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// Muted sentence-case section caption ("Account", "App").
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 8),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: AppTypography.titleSmall.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 34 pt rounded-square icon tile with a soft tint, the leading of a
/// grouped settings row.
class SettingsIconTile extends StatelessWidget {
  const SettingsIconTile(this.icon, {super.key, this.tint, this.ink});

  final IconData icon;
  final Color? tint;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: tint ?? p.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 18, color: ink ?? p.textPrimary),
    );
  }
}

/// A 20-radius surface card with hairline border; [children] are separated
/// by row dividers.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
    this.divided = true,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;
  final bool divided;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0 && divided) {
        items.add(Divider(height: 1, thickness: 1, color: p.borderSubtle));
      }
      items.add(children[i]);
    }
    return Padding(
      padding: margin,
      child: Material(
        color: p.surface,
        shape: AppRadii.cardShape(p.hairline),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}

/// A tappable row: title (+ optional subtitle), a muted value and a
/// direction-aware chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final titleColor = destructive ? p.error : p.textPrimary;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyLarge.copyWith(
                          color: titleColor,
                          fontWeight: subtitle == null
                              ? FontWeight.w400
                              : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTypography.bodySmall.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (value != null && value!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  // Capped, not Flexible: a Flexible value takes half the
                  // row and wraps short labels.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AppTypography.bodyMedium.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ),
                ],
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                if (showChevron && onTap != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    AppIcons.chevronRight,
                    size: 20,
                    color: p.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row with a title, subtitle and an adaptive switch; ticks a selection
/// haptic when toggled.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null
            ? null
            : () {
                AppHaptics.selection();
                onChanged!(!value);
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMedium.copyWith(
                          color: p.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTypography.bodySmall.copyWith(
                            color: p.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  value: value,
                  // iOS draws the Cupertino switch, which ignores the
                  // Material theme and would be system green.
                  activeTrackColor: p.accent,
                  onChanged: onChanged == null
                      ? null
                      : (v) {
                          AppHaptics.selection();
                          onChanged!(v);
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small ink "PRO" badge.
class ProBadge extends StatelessWidget {
  const ProBadge({super.key, this.label});

  /// Defaults to the localized "PRO".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.inverseSurface,
        borderRadius: AppRadii.chipRadius,
      ),
      child: Text(
        label ?? 'v3_pro_badge'.tr(),
        style: AppTypography.labelSmall.copyWith(
          color: p.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Teal-soft chip ("Default").
class SoftChip extends StatelessWidget {
  const SoftChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: AppRadii.chipRadius,
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: p.onAccentSoft),
      ),
    );
  }
}

/// Selectable choice chip used for segmented options (Weekly / Monthly,
/// 7 / 30 / 90 days): ink when selected, hairline otherwise.
class V3ChoiceChip extends StatelessWidget {
  const V3ChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.inverseSurface : p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.chipRadius,
          side: selected
              ? BorderSide.none
              : BorderSide(color: p.borderStrong),
        ),
        child: InkWell(
          borderRadius: AppRadii.chipRadius,
          onTap: () {
            AppHaptics.selection();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: AppTypography.titleSmall.copyWith(
                    color: selected ? p.onInverseSurface : p.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Radio-style option card (Export "What", paywall plans).
class V3RadioTile extends StatelessWidget {
  const V3RadioTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.child,
    this.radius = AppRadii.row,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: selected ? p.textPrimary : p.hairline,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            AppHaptics.selection();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  V3RadioDot(selected: selected),
                  const SizedBox(width: 12),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The 20 pt radio ring from the mockups.
class V3RadioDot extends StatelessWidget {
  const V3RadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      duration: AppMotion.durationFor(context, AppMotion.fast),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? p.textPrimary : p.borderStrong,
          width: selected ? 6 : 2,
        ),
      ),
    );
  }
}

/// Labeled form field caption used above inputs ("Name shown to friends").
class V3FieldLabel extends StatelessWidget {
  const V3FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.titleSmall.copyWith(
          color: context.palette.textPrimary,
        ),
      ),
    );
  }
}

/// The person's pal (or photo). Keyed by lowercased name unless [id] is set.
class V3Avatar extends StatelessWidget {
  const V3Avatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 64,
    this.id,
  });

  final String name;
  final String? photoUrl;
  final double size;
  final String? id;

  @override
  Widget build(BuildContext context) => PalAvatar(
    seed: (id == null || id!.isEmpty) ? name.trim().toLowerCase() : id!,
    name: name,
    photoUrl: photoUrl,
    size: size,
  );
}
