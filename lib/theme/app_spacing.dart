import 'package:flutter/material.dart';

/// Consistent spacing constants for padding, margins, and gaps
class AppSpacing {
  AppSpacing._(); // Private constructor

  // ==================== SPACING VALUES ====================

  /// 4px - Minimal spacing
  static const double xs = 4.0;

  /// 8px - Small spacing
  static const double sm = 8.0;

  /// 12px - Medium-small spacing
  static const double md = 12.0;

  /// 16px - Standard spacing (default)
  static const double lg = 16.0;

  /// 20px - Large spacing
  static const double xl = 20.0;

  /// 24px - Extra large spacing
  static const double xxl = 24.0;

  /// 32px - Huge spacing
  static const double xxxl = 32.0;

  /// 48px - Massive spacing (section gaps)
  static const double huge = 48.0;

  // ==================== EDGE INSETS PRESETS ====================

  /// No padding
  static const EdgeInsets zero = EdgeInsets.zero;

  /// All sides: 4px
  static const EdgeInsets allXs = EdgeInsets.all(xs);

  /// All sides: 8px
  static const EdgeInsets allSm = EdgeInsets.all(sm);

  /// All sides: 12px
  static const EdgeInsets allMd = EdgeInsets.all(md);

  /// All sides: 16px (most common)
  static const EdgeInsets allLg = EdgeInsets.all(lg);

  /// All sides: 20px
  static const EdgeInsets allXl = EdgeInsets.all(xl);

  /// All sides: 24px
  static const EdgeInsets allXxl = EdgeInsets.all(xxl);

  /// Horizontal: 16px
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);

  /// Horizontal: 20px
  static const EdgeInsets horizontalXl = EdgeInsets.symmetric(horizontal: xl);

  /// Vertical: 16px
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);

  /// Vertical: 20px
  static const EdgeInsets verticalXl = EdgeInsets.symmetric(vertical: xl);

  /// Page padding (horizontal: 20px, vertical: 16px)
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: xl,
    vertical: lg,
  );

  /// Card padding (all sides: 16px)
  static const EdgeInsets cardPadding = allLg;

  /// List item padding (horizontal: 16px, vertical: 12px)
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );

  // ==================== BORDER RADIUS ====================

  /// 4px - Minimal rounding
  static const double radiusXs = 4.0;

  /// 8px - Small rounding
  static const double radiusSm = 8.0;

  /// 12px - Medium rounding
  static const double radiusMd = 12.0;

  /// 16px - Standard rounding (cards, buttons)
  static const double radiusLg = 16.0;

  /// 20px - Large rounding
  static const double radiusXl = 20.0;

  /// 24px - Extra large rounding (bottom sheets)
  static const double radiusXxl = 24.0;

  /// 30px - Huge rounding (hero cards)
  static const double radiusHuge = 30.0;

  /// Circular (pill shape)
  static const double radiusCircular = 9999.0;

  // ==================== BORDER RADIUS PRESETS ====================

  static BorderRadius get borderRadiusXs => BorderRadius.circular(radiusXs);
  static BorderRadius get borderRadiusSm => BorderRadius.circular(radiusSm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(radiusLg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(radiusXl);
  static BorderRadius get borderRadiusXxl => BorderRadius.circular(radiusXxl);
  static BorderRadius get borderRadiusHuge => BorderRadius.circular(radiusHuge);
  static BorderRadius get borderRadiusCircular =>
      BorderRadius.circular(radiusCircular);

  /// Bottom sheet / modal radius (top only)
  static BorderRadius get borderRadiusBottomSheet => const BorderRadius.only(
    topLeft: Radius.circular(radiusXxl),
    topRight: Radius.circular(radiusXxl),
  );

  /// Header card radius (bottom only)
  static BorderRadius get borderRadiusHeader => const BorderRadius.only(
    bottomLeft: Radius.circular(radiusHuge),
    bottomRight: Radius.circular(radiusHuge),
  );

  // ==================== ICON SIZES ====================

  /// 16px - Small icons
  static const double iconSm = 16.0;

  /// 20px - Medium icons
  static const double iconMd = 20.0;

  /// 24px - Standard icons
  static const double iconLg = 24.0;

  /// 28px - Large icons
  static const double iconXl = 28.0;

  /// 32px - Extra large icons
  static const double iconXxl = 32.0;

  /// 48px - Huge icons (empty states)
  static const double iconHuge = 48.0;

  // ==================== ELEVATION / SHADOW ====================

  /// No elevation
  static const double elevationNone = 0.0;

  /// 1 - Subtle elevation (cards)
  static const double elevationXs = 1.0;

  /// 2 - Small elevation (raised cards)
  static const double elevationSm = 2.0;

  /// 4 - Standard elevation (FAB, app bars)
  static const double elevationMd = 4.0;

  /// 6 - Medium elevation (dialogs)
  static const double elevationLg = 6.0;

  /// 8 - Large elevation (bottom sheets)
  static const double elevationXl = 8.0;

  /// 12 - Extra large elevation (modals)
  static const double elevationXxl = 12.0;

  // ==================== AVATAR SIZES ====================

  /// 24px - Tiny avatar
  static const double avatarSm = 24.0;

  /// 32px - Small avatar
  static const double avatarMd = 32.0;

  /// 40px - Standard avatar
  static const double avatarLg = 40.0;

  /// 56px - Large avatar
  static const double avatarXl = 56.0;

  /// 80px - Extra large avatar
  static const double avatarXxl = 80.0;

  // ==================== BUTTON HEIGHTS ====================

  /// 36px - Small button
  static const double buttonSm = 36.0;

  /// 44px - Medium button
  static const double buttonMd = 44.0;

  /// 52px - Large button (standard)
  static const double buttonLg = 52.0;

  /// 60px - Extra large button
  static const double buttonXl = 60.0;
}
