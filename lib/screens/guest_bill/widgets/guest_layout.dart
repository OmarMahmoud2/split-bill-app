import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:split_bill_app/theme/theme.dart';

import 'guest_chrome.dart';

/// Page layout by viewport width: phone < 600, tablet < 1024, desktop.
enum GuestSize {
  phone,
  tablet,
  desktop;

  static GuestSize of(double width) => width < 600
      ? phone
      : width < 1024
      ? tablet
      : desktop;

  /// Side padding shared by the top bar and the body so they line up.
  double get hPad => this == desktop ? 24 : 20;
}

const double kGuestColumnMax = 640;
const double kGuestDesktopMax = 1120;
const double kGuestBarHeight = 60;

/// Soft layered colour orbs behind the page (pre-blurred radial gradients,
/// one cheap repaint boundary, no real blur).
class GuestOrbs extends StatelessWidget {
  const GuestOrbs({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final alpha = p.isDark ? 0.16 : 0.13;
    Widget orb(Color color, Alignment at, double size) => Align(
      alignment: at,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: alpha),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: LayoutBuilder(
            builder: (context, c) {
              final s = c.biggest.shortestSide.clamp(360.0, 900.0) * 1.3;
              return Stack(
                children: [
                  orb(p.primary, const Alignment(-1.1, -1), s),
                  orb(p.sky, const Alignment(1.1, -0.2), s * 0.9),
                  orb(p.coral, const Alignment(-0.5, 1.2), s * 0.7),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Pinned, translucent top bar: wordmark left, language + "Get the app"
/// right, hairline below. [maxWidth] aligns it with the body.
class GuestTopBar extends SliverPersistentHeaderDelegate {
  GuestTopBar({required this.maxWidth, required this.hPad, required this.top});

  final double maxWidth;
  final double hPad;
  final double top;

  @override
  double get minExtent => kGuestBarHeight + top;
  @override
  double get maxExtent => kGuestBarHeight + top;

  @override
  bool shouldRebuild(covariant GuestTopBar old) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final p = context.palette;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: p.background.withValues(alpha: 0.78),
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: const Row(
                    children: [
                      GuestBrand(),
                      Spacer(),
                      Flexible(child: GuestLanguageButton()),
                      SizedBox(width: 8),
                      Flexible(child: GuestGetAppPill()),
                    ],
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

/// Keeps [child] in view while the page scrolls: it is placed by layout from
/// the scroll offset (so hit-testing is right) and never leaves its parent.
class GuestSticky extends StatelessWidget {
  const GuestSticky({
    super.key,
    required this.controller,
    required this.child,
    this.slack = 8,
  });

  final ScrollController controller;
  final Widget child;

  /// Scroll distance before the panel starts to stick.
  final double slack;

  @override
  Widget build(BuildContext context) => CustomSingleChildLayout(
    delegate: _StickyDelegate(controller, slack),
    child: child,
  );
}

class _StickyDelegate extends SingleChildLayoutDelegate {
  _StickyDelegate(this.controller, this.slack) : super(relayout: controller);

  final ScrollController controller;
  final double slack;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) =>
      BoxConstraints(minWidth: c.maxWidth, maxWidth: c.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final room = (size.height - childSize.height).clamp(0.0, double.infinity);
    if (!controller.hasClients) return Offset.zero;
    final pos = controller.position;
    // A panel taller than the window scrolls until its bottom is in view,
    // then sticks, so its last control is never unreachable.
    final overflow =
        (childSize.height - (pos.viewportDimension - kGuestBarHeight - 32))
            .clamp(0.0, double.infinity);
    return Offset(0, (pos.pixels - slack - overflow).clamp(0.0, room));
  }

  @override
  bool shouldRelayout(_StickyDelegate old) =>
      old.controller != controller || old.slack != slack;
}
