import 'package:flutter/material.dart';

/// Color primitives for the v3 "Quiet ledger" design.
///
/// Warm neutrals carry the screen, one teal accent marks what you can act
/// on, and owing is amber, never alarm red. Red is only for errors and
/// destructive actions.
///
/// Widgets should not read these directly: use the semantic roles in
/// `context.palette` (see `app_palette.dart`), which pick the light or dark
/// value. The old names (`primary`, `secondary`, `owingRed`, ...) are kept so
/// existing call sites keep compiling; they now point at v3 values.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ==================== V3 LIGHT ====================

  static const Color canvasLight = Color(0xFFF7F7F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFF2F1EE);
  static const Color hairlineLight = Color(0xFFE7E6E1);
  static const Color dividerSubtleLight = Color(0xFFEFEEEA);
  static const Color borderStrongLight = Color(0xFFD9D8D3);
  static const Color inkLight = Color(0xFF111312);
  static const Color inkMediumLight = Color(0xFF3A3D3B);
  static const Color mutedLight = Color(0xFF5F6360);
  static const Color tertiaryLight = Color(0xFF6B6F6C);
  static const Color disabledLight = Color(0xFFA8ABA8);
  static const Color tealLight = Color(0xFF0F766E);
  static const Color tealStrongLight = Color(0xFF0B5F58);
  static const Color tealSoftLight = Color(0xFFE6F2F0);
  static const Color tealInkLight = Color(0xFF0B4F49);
  static const Color amberLight = Color(0xFFB45309);
  static const Color amberSoftLight = Color(0xFFFBF1E6);
  static const Color amberInkLight = Color(0xFF7A3E06);
  static const Color errorRedLight = Color(0xFFB42318);
  static const Color errorStrongLight = Color(0xFF912018);
  static const Color errorSoftLight = Color(0xFFFDECEA);

  // ==================== V3 DARK ====================

  static const Color canvasDark = Color(0xFF0E0F0E);
  static const Color surfaceDarkV3 = Color(0xFF171918);
  static const Color surface2Dark = Color(0xFF1F221F);
  static const Color hairlineDark = Color(0xFF262927);
  static const Color dividerSubtleDark = Color(0xFF222523);
  static const Color borderStrongDark = Color(0xFF3A3E3B);
  static const Color inkDark = Color(0xFFF2F3F1);
  static const Color inkMediumDark = Color(0xFFC9CCCA);
  static const Color mutedDark = Color(0xFFA3A8A5);
  static const Color tertiaryDark = Color(0xFF8E9390);
  static const Color disabledDark = Color(0xFF5C605D);
  static const Color tealDark = Color(0xFF34C5B0);
  static const Color tealStrongDark = Color(0xFF5ED6C4);
  static const Color tealSoftDark = Color(0xFF12322E);
  static const Color tealInkDark = Color(0xFF8FE3D6);
  static const Color amberDark = Color(0xFFF0B35E);
  static const Color amberSoftDark = Color(0xFF33240F);
  static const Color amberInkDark = Color(0xFFF6C987);
  static const Color errorRedDark = Color(0xFFF97066);
  static const Color errorStrongDark = Color(0xFFFDA29B);
  static const Color errorSoftDark = Color(0xFF3A1A17);

  // ==================== LEGACY NAMES (mapped to v3) ====================

  /// Brand accent (teal). Prefer `context.palette.accent`.
  static const Color primary = tealLight;
  static const Color primaryDark = tealStrongLight;
  static const Color primaryLight = tealDark;

  /// Quiet, nearly flat brand gradient for legacy hero headers.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [tealLight, tealStrongLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// v3 has a single accent; the old coral secondary now maps to teal.
  static const Color secondary = tealLight;
  static const Color secondaryDark = tealStrongLight;
  static const Color secondaryLight = tealSoftLight;

  static const Color success = tealLight;
  static const Color successLight = tealSoftLight;
  static const Color successDark = tealStrongLight;

  static const Color error = errorRedLight;
  static const Color errorLight = errorSoftLight;
  static const Color errorDark = errorStrongLight;

  static const Color warning = amberLight;
  static const Color warningLight = amberSoftLight;

  static const Color info = Color(0xFF3B5B7A);
  static const Color infoLight = Color(0xFFEAF0F5);

  static const Color backgroundLight = canvasLight;
  static const Color cardLight = surfaceLight;
  static const Color textPrimaryLight = inkLight;
  static const Color textSecondaryLight = mutedLight;
  static const Color textDisabledLight = disabledLight;
  static const Color dividerLight = hairlineLight;
  static const Color borderLight = hairlineLight;
  static const Color overlayLight = Color(0x14111312);
  static const Color shadowLight = Color(0x14111312); // 8% ink

  static const Color backgroundDark = canvasDark;
  static const Color surfaceDark = surfaceDarkV3;
  static const Color cardDark = surface2Dark;
  static const Color textPrimaryDark = inkDark;
  static const Color textSecondaryDark = mutedDark;
  static const Color textDisabledDark = disabledDark;
  static const Color dividerDark = hairlineDark;
  static const Color borderDark = hairlineDark;
  static const Color overlayDark = Color(0x14FFFFFF);
  static const Color shadowDark = Color(0x00000000); // no shadows in dark

  // ==================== BILL STATUS COLORS ====================

  /// "You owe": amber, never alarm red.
  static const Color owingRed = amberLight;

  /// "Owed to you": the teal accent.
  static const Color owedGreen = tealLight;

  static const Color pending = amberLight;
  static const Color settled = tealLight;

  // ==================== PARTICIPANT COLORS ====================

  /// Desaturated avatar tints (light mode) from the v3 mockups. Text on them
  /// is always ink at full strength.
  static const List<Color> avatarTintsLight = [
    Color(0xFFF3ECE1), // sand
    Color(0xFFE6F2F0), // teal
    Color(0xFFF4E6E6), // rose
    Color(0xFFEDEFF2), // slate
    Color(0xFFE9EAF5), // lavender
    Color(0xFFEAF2E3), // sage
    Color(0xFFF5EEDC), // straw
    Color(0xFFE5EEF6), // sky
  ];

  /// Dark-mode avatar tints (same hues, low lightness). Text is `inkDark`.
  static const List<Color> avatarTintsDark = [
    Color(0xFF3A3226),
    Color(0xFF12322E),
    Color(0xFF3B2828),
    Color(0xFF2A2E33),
    Color(0xFF2B2D40),
    Color(0xFF283323),
    Color(0xFF3A321D),
    Color(0xFF223040),
  ];

  /// Legacy saturated participant palette, kept for charts and chips that
  /// still use it. New UI should use [avatarTintsLight]/[avatarTintsDark].
  static const List<Color> participantColors = [
    Color(0xFF0F766E), // teal
    Color(0xFFB45309), // amber
    Color(0xFF3B5B7A), // slate blue
    Color(0xFF7A4E8C), // plum
    Color(0xFF4D7C3A), // moss
    Color(0xFFA34A5C), // rose
    Color(0xFF52599E), // indigo
    Color(0xFF8A6D1F), // ochre
    Color(0xFF2B7A99), // sea
    Color(0xFF6B6F6C), // graphite
  ];
}
