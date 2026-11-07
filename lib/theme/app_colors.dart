import 'package:flutter/material.dart';

/// Color primitives for the "Midnight & Mint" design (docs/2.0/PREMIUM_POLISH.md).
///
/// Blue-tinted neutrals carry the screen, mint marks what you can act on and
/// what is owed to you, owing is coral, never alarm red. Red is only for
/// errors and destructive actions.
///
/// Widgets should not read these directly: use the semantic roles in
/// `context.palette` (see `app_palette.dart`), which pick the light or dark
/// value. The old names (`primary`, `secondary`, `owingRed`, ...) are kept so
/// existing call sites keep compiling; they now point at v3 values.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ==================== MIDNIGHT & MINT LIGHT ====================

  static const Color canvasLight = Color(0xFFF5F7FB);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFEEF1F6);
  static const Color hairlineLight = Color(0xFFE3E7EF);
  static const Color dividerSubtleLight = Color(0xFFEBEEF4);
  static const Color borderStrongLight = Color(0xFFD4DAE6);
  static const Color inkLight = Color(0xFF0E1526);
  static const Color inkMediumLight = Color(0xFF2E364A);
  static const Color mutedLight = Color(0xFF5B6478);
  static const Color tertiaryLight = Color(0xFF6B7489);
  static const Color disabledLight = Color(0xFFA6AEBF);
  static const Color tealLight = Color(0xFF0E7C72);
  static const Color tealStrongLight = Color(0xFF0A5F57);
  static const Color tealSoftLight = Color(0xFFE3F7F3);
  static const Color tealInkLight = Color(0xFF0A5F57);
  static const Color coralLight = Color(0xFFE8664A);
  static const Color coralTextLight = Color(0xFFC2452D);
  static const Color coralSoftLight = Color(0xFFFFECE6);
  static const Color coralInkLight = Color(0xFFA8381F);
  static const Color skyLight = Color(0xFF3B6FE0);
  static const Color skySoftLight = Color(0xFFE6EDFD);
  static const Color errorRedLight = Color(0xFFC62828);
  static const Color errorStrongLight = Color(0xFF9F1F1F);
  static const Color errorSoftLight = Color(0xFFFDECEC);

  // ==================== MIDNIGHT & MINT DARK ====================

  static const Color canvasDark = Color(0xFF0A0F1C);
  static const Color surfaceDarkV3 = Color(0xFF121A2B);
  static const Color surface2Dark = Color(0xFF1A2438);
  static const Color hairlineDark = Color(0xFF22304A);
  static const Color dividerSubtleDark = Color(0xFF1B2740);
  static const Color borderStrongDark = Color(0xFF2E3D5C);
  static const Color inkDark = Color(0xFFE8EDF7);
  static const Color inkMediumDark = Color(0xFFC5CDDD);
  static const Color mutedDark = Color(0xFF9AA4B8);
  static const Color tertiaryDark = Color(0xFF8A94A8);
  static const Color disabledDark = Color(0xFF55607A);
  static const Color tealDark = Color(0xFF34D7C0);
  static const Color tealStrongDark = Color(0xFF5FE3D0);
  static const Color tealSoftDark = Color(0xFF173540); // 14% mint on surface
  static const Color tealInkDark = Color(0xFF34D7C0);
  static const Color onMintDark = Color(0xFF06231F);
  static const Color coralDark = Color(0xFFFF8A70);
  static const Color coralSoftDark = Color(0xFF332A35); // 14% coral on surface
  static const Color skyDark = Color(0xFF7AA2FF);
  static const Color skySoftDark = Color(0xFF212D49); // 14% sky on surface
  static const Color errorRedDark = Color(0xFFFF6B6B);
  static const Color errorStrongDark = Color(0xFFFF9A9A);
  static const Color errorSoftDark = Color(0xFF332534); // 14% error on surface
  static const Color goldPremium = Color(0xFFFFD36B);
  static const Color heroLineDark = Color(0xFF2A3854);

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

  static const Color warning = coralLight;
  static const Color warningLight = coralSoftLight;

  static const Color info = skyLight;
  static const Color infoLight = skySoftLight;

  static const Color backgroundLight = canvasLight;
  static const Color cardLight = surfaceLight;
  static const Color textPrimaryLight = inkLight;
  static const Color textSecondaryLight = mutedLight;
  static const Color textDisabledLight = disabledLight;
  static const Color dividerLight = hairlineLight;
  static const Color borderLight = hairlineLight;
  static const Color overlayLight = Color(0x140E1526);
  static const Color shadowLight = Color(0x140E1526); // 8% ink

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

  /// "You owe": coral, never alarm red.
  static const Color owingRed = coralTextLight;

  /// "Owed to you": the teal accent.
  static const Color owedGreen = tealLight;

  static const Color pending = skyLight;
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
