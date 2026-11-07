/// Small building blocks shared by Home, Groups, Settle and Activity
/// (v3 "Quiet ledger": hairline cards, tinted initials, pill buttons).
library;

import 'package:easy_localization/easy_localization.dart' show StringTranslateExtension;
import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/pal_avatar.dart';

/// A round avatar: the photo when there is one, else the person's pal.
class LedgerAvatar extends StatelessWidget {
  const LedgerAvatar({
    super.key,
    required this.id,
    required this.name,
    this.photoUrl,
    this.size = 40,
    this.selected = false,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final double size;
  final bool selected;

  /// Pal seed: the id, else the lowercased name.
  static String seedOf(String id, String name) =>
      id.isEmpty ? name.trim().toLowerCase() : id;

  @override
  Widget build(BuildContext context) {
    return PalAvatar(
      seed: seedOf(id, name),
      name: name,
      photoUrl: photoUrl,
      size: size,
      ringColor: selected ? context.palette.accent : null,
    );
  }
}

/// Overlapping avatars (group cards): -6 overlap, surface-coloured ring.
class AvatarStack extends StatelessWidget {
  const AvatarStack({
    super.key,
    required this.people,
    this.size = 28,
    this.max = 4,
  });

  /// (id, name, photoUrl)
  final List<(String, String, String?)> people;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shown = people.take(max).toList();
    const ring = PalAvatar.ringWidth;
    final item = size + ring * 2;
    final step = item - 6;
    return SizedBox(
      height: item,
      width: shown.isEmpty ? 0 : step * (shown.length - 1) + item,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            PositionedDirectional(
              start: i * step,
              child: PalAvatar(
                seed: LedgerAvatar.seedOf(shown[i].$1, shown[i].$2),
                name: shown[i].$2,
                photoUrl: shown[i].$3,
                size: size,
                ringColor: p.surface,
              ),
            ),
        ],
      ),
    );
  }
}

/// A surface card with a hairline border and the 20 radius.
class LedgerCard extends StatelessWidget {
  const LedgerCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
    this.borderColor,
    this.borderWidth = AppRadii.hairline,
    this.semanticsLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final shape = RoundedRectangleBorder(
      borderRadius: AppRadii.cardRadius,
      side: BorderSide(color: borderColor ?? p.border, width: borderWidth),
    );
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = InkWell(onTap: onTap, customBorder: shape, child: content);
    }
    return Padding(
      padding: margin,
      child: Semantics(
        button: onTap != null,
        label: semanticsLabel,
        child: Material(
          color: color ?? p.surface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: content,
        ),
      ),
    );
  }
}

/// Rows inside a card, separated by hairlines.
class LedgerRows extends StatelessWidget {
  const LedgerRows({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: p.borderSubtle),
          children[i],
        ],
      ],
    );
  }
}

/// "Settle with ............ All"
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 22, 12, 8),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppTypography.titleMedium.copyWith(
                  color: p.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: p.textSecondary),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Muted, upper-case label above a section ("TODAY", "ACROSS 2 GROUPS").
class OverlineLabel extends StatelessWidget {
  const OverlineLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 8),
  });
  final String text;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: AppTypography.labelMedium.copyWith(
          color: context.palette.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );
}

/// A 44 pt round, bordered icon button (back, close, notifications).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: p.surface,
          shape: CircleBorder(side: BorderSide(color: p.border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 18, color: p.textPrimary),
                  if (badge)
                    PositionedDirectional(
                      top: 9,
                      end: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: p.owe,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back button + title row used at the top of v3 detail screens.
class LedgerTopBar extends StatelessWidget {
  const LedgerTopBar({
    super.key,
    this.title,
    this.close = false,
    this.actions = const [],
    this.onBack,
  });

  final String? title;
  final bool close;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
      child: Row(
        children: [
          RoundIconButton(
            icon: close
                ? AppIcons.close
                : Directionality.of(context) == TextDirection.rtl
                ? AppIcons.chevronRight
                : AppIcons.chevronLeft,
            tooltip: close ? l.closeButtonTooltip : l.backButtonTooltip,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: title == null
                ? const SizedBox.shrink()
                : Semantics(
                    header: true,
                    child: Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: p.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ],
      ),
    );
  }
}

/// A big screen title ("Groups", "Activity").
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 0),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              text,
              style: AppTypography.headlineLarge.copyWith(
                color: context.palette.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Two or three segments ("Balances · Bills · Totals").
class LedgerSegmented<T> extends StatelessWidget {
  const LedgerSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surfaceVariant,
        borderRadius: AppRadii.rowRadius,
      ),
      child: Row(
        children: [
          for (final (value, label) in segments)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (value == selected) return;
                    AppHaptics.selection();
                    onChanged(value);
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.durationFor(context, AppMotion.fast),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == selected
                          ? p.surface
                          : p.surfaceVariant.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: value == selected
                            ? p.textPrimary
                            : p.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the app's bottom sheet: never full screen (height = content, at
/// most 85% of the screen), 32 top radius, 40x5 drag handle, optional
/// [title] / [subtitle] header with a 40 px close button, springs in.
///
/// Keyboard-aware: the sheet is padded by the keyboard height, so fields and
/// the action button stay above it while the content scrolls if it must.
/// [builder] returns the body; wrap long bodies in a scroll view.
Future<T?> showLedgerSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  String? subtitle,
  bool showClose = true,
  bool isDismissible = true,
}) {
  final p = context.palette;
  final reduce = AppMotion.reduceMotion(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    backgroundColor: p.isDark ? p.surfaceVariant : p.surface,
    barrierColor: p.scrim,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetRadius),
    clipBehavior: Clip.antiAlias,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
    ),
    sheetAnimationStyle: AnimationStyle(
      duration: reduce ? AppMotion.fast : const Duration(milliseconds: 380),
      reverseDuration: AppMotion.slow,
      curve: AppMotion.quiet,
      reverseCurve: AppMotion.emphasizedAccelerate,
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 14),
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: p.borderStrong,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            if (title != null)
              _SheetHeader(
                title: title,
                subtitle: subtitle,
                showClose: showClose,
              ),
            Flexible(child: builder(context)),
          ],
        ),
      ),
    ),
  );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    this.subtitle,
    required this.showClose,
  });

  final String title;
  final String? subtitle;
  final bool showClose;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTypography.headlineMedium.copyWith(
                      color: p.textPrimary,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: p.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (showClose) ...[
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: 'close'.tr(),
              excludeSemantics: true,
              child: Material(
                color: p.surfaceVariant,
                borderRadius: AppRadii.rowRadius,
                child: InkWell(
                  borderRadius: AppRadii.rowRadius,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      AppIcons.close,
                      size: 20,
                      color: p.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The thin "spent of budget" bar.
class BudgetBar extends StatelessWidget {
  const BudgetBar({super.key, required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = fraction.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: p.border)),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: f),
              duration: AppMotion.durationFor(context, AppMotion.money),
              curve: AppMotion.quiet,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: v,
                child: ColoredBox(color: fraction > 1 ? p.owe : p.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
