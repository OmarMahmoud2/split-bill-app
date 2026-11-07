import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/theme.dart';
import 'package:split_bill_app/widgets/motion/motion.dart';

/// One tab of [FloatingTabBar].
class TabSpec {
  const TabSpec(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The floating pill nav: 16 from the sides, 24 from the bottom, radius 24,
/// 68 high, hairline and soft shadow, with a raised mint "+" in the middle.
/// Tap opens the new-bill sheet; long-press starts a receipt scan.
///
/// [tabs] are four: two left of the "+", two right. The mint pill slides
/// between tabs, the selected icon bounces and swaps to its fill glyph, and
/// the "+" breathes a soft glow a few times. All of it is skipped under
/// Reduce Motion.
///
/// The body extends behind the bar (`extendBody`), so the pill is frosted:
/// a backdrop blur under a translucent surface.
class FloatingTabBar extends StatefulWidget {
  const FloatingTabBar({
    super.key,
    required this.index,
    required this.tabs,
    required this.onSelect,
    required this.onNew,
    required this.onScan,
    required this.newLabel,
    required this.scanHint,
  });

  final int index;
  final List<TabSpec> tabs;
  final ValueChanged<int> onSelect;
  final VoidCallback onNew;
  final VoidCallback onScan;
  final String newLabel;
  final String scanHint;

  static const double pillHeight = 68;
  static const double raise = 26;

  @override
  State<FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends State<FloatingTabBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  bool _glowStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A few breaths, then still: an endless loop would keep frames coming.
    if (!_glowStarted && !AppMotion.reduceMotion(context)) {
      _glowStarted = true;
      _glow.repeat(reverse: true, count: 6);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  // Slots: tab 0, 1, centre gap, tab 2, 3.
  static int _slot(int tab) => tab < 2 ? tab : tab + 1;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dur = AppMotion.durationFor(context, AppMotion.medium);

    Widget item(int i) {
      final t = widget.tabs[i];
      final on = i == widget.index;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: t.label,
          child: Pressable(
            onTap: () => widget.onSelect(i),
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 52,
                    height: 30,
                    child: _BounceIcon(
                      selected: on,
                      icon: t.icon,
                      activeIcon: t.activeIcon,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 14,
                    child: AnimatedDefaultTextStyle(
                      duration: dur,
                      style: AppTypography.labelSmall.copyWith(
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                        color: on ? p.textPrimary : p.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: Text(t.label),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 24),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: FloatingTabBar.pillHeight + FloatingTabBar.raise,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: FloatingTabBar.raise,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: p.softShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.surface.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: p.border),
                            ),
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final slotW = c.maxWidth / 5;
                                return Stack(
                                  children: [
                                    // The mint pill that slides between tabs.
                                    AnimatedPositionedDirectional(
                                      key: const ValueKey('nav_indicator'),
                                      duration: dur,
                                      curve: AppMotion.emphasizedDecelerate,
                                      start:
                                          _slot(widget.index) * slotW +
                                          (slotW - 52) / 2,
                                      top: 9.5,
                                      width: 52,
                                      height: 30,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: p.accentSoft,
                                          borderRadius: AppRadii.fullRadius,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        item(0),
                                        item(1),
                                        const Spacer(),
                                        item(2),
                                        item(3),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: widget.newLabel,
                        onLongPressHint: widget.scanHint,
                        child: Pressable(
                          haptic: true,
                          scale: 0.92,
                          onTap: widget.onNew,
                          onLongPress: widget.onScan,
                          child: AnimatedBuilder(
                            animation: _glow,
                            builder: (context, child) => Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: p.accent,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  ...p.softShadow,
                                  BoxShadow(
                                    color: p.accent.withValues(
                                      alpha: 0.12 + 0.22 * _glow.value,
                                    ),
                                    blurRadius: 12 + 12 * _glow.value,
                                    spreadRadius: 1 + 2 * _glow.value,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                            child: Icon(
                              AppIcons.add,
                              color: p.onMint,
                              size: 28,
                            ),
                          ),
                        ),
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

/// The tab icon: crossfades outline to fill when selected, with a small
/// 1 → 1.12 → 1 bounce.
class _BounceIcon extends StatefulWidget {
  const _BounceIcon({
    required this.selected,
    required this.icon,
    required this.activeIcon,
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;

  @override
  State<_BounceIcon> createState() => _BounceIconState();
}

class _BounceIconState extends State<_BounceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void didUpdateWidget(_BounceIcon old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected && !AppMotion.reduceMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final on = widget.selected;
    return ScaleTransition(
      scale: _scale,
      child: Center(
        child: AnimatedSwitcher(
          duration: AppMotion.durationFor(context, AppMotion.fast),
          child: Icon(
            on ? widget.activeIcon : widget.icon,
            key: ValueKey(on),
            size: 22,
            color: on ? p.textPrimary : p.textSecondary,
          ),
        ),
      ),
    );
  }
}
