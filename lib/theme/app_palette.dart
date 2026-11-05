import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_colors.dart';

/// Semantic color roles for the app, with a light and a dark value each.
///
/// This is the single source of truth for themable colors. Widgets read it
/// through `context.palette` and never hard-code `Colors.*` for surfaces,
/// text or brand colors.
///
/// The light values reproduce the current look exactly (they are the
/// Material shades the screens used before the token migration). A rebrand
/// is a change to [AppPalette.light] / [AppPalette.dark] (and the
/// primitives in [AppColors]) only.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.surfaceMuted,
    required this.border,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textStrong,
    required this.textMedium,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.onPrimary,
    required this.primaryGradient,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.successStrong,
    required this.successSoft,
    required this.danger,
    required this.dangerStrong,
    required this.dangerSoft,
    required this.dangerAccent,
    required this.warning,
    required this.warningStrong,
    required this.warningSoft,
    required this.info,
    required this.infoStrong,
    required this.infoSoft,
    required this.infoAccent,
    required this.premium,
    required this.premiumStrong,
    required this.onPremium,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.shadow,
    required this.scrim,
  });

  final Brightness brightness;

  // ---------------------------------------------------------------- surfaces
  /// Scaffold / page background.
  final Color background;

  /// Cards, sheets, dialogs, inputs (white in light mode).
  final Color surface;

  /// Muted fill on top of a surface: chips, tiles, input backgrounds
  /// (light: Material grey 100).
  final Color surfaceVariant;

  /// Very subtle fill / alternative page background (light: grey 50).
  final Color surfaceMuted;

  /// Default border and divider (light: grey 300).
  final Color border;

  /// Hairline / subtle border (light: grey 200).
  final Color borderSubtle;

  // -------------------------------------------------------------------- text
  /// Body text and titles (light: #212121, the same as black87 on white).
  final Color textPrimary;

  /// Maximum-emphasis text: pure black in light mode, white in dark mode.
  final Color textStrong;

  /// Between primary and secondary (light: grey 700).
  final Color textMedium;

  /// Secondary text, captions, icons (light: grey 600 / black54).
  final Color textSecondary;

  /// Tertiary text, hints, placeholder icons (light: grey 500).
  final Color textTertiary;

  /// Disabled text and icons (light: grey 400).
  final Color textDisabled;

  // ------------------------------------------------------------------- brand
  /// Brand color for buttons, links, selection.
  final Color primary;

  /// Higher-contrast brand color for brand-colored text on surfaces.
  final Color primaryStrong;

  /// Brand tint for selected chips / badges backgrounds.
  final Color primarySoft;

  /// Text and icons on [primary] and on [primaryGradient].
  final Color onPrimary;

  /// Brand gradient for headers and hero cards.
  final LinearGradient primaryGradient;

  /// Secondary brand accent (coral).
  final Color accent;
  final Color onAccent;

  // ---------------------------------------------------------------- semantic
  /// Positive state; also "owed to you" amounts.
  final Color success;

  /// Success color for text on surfaces.
  final Color successStrong;

  /// Success tint background.
  final Color successSoft;

  /// Errors, destructive actions; also "you owe" amounts.
  final Color danger;
  final Color dangerStrong;
  final Color dangerSoft;

  /// Brighter red (Material redAccent) used for destructive icons/badges.
  final Color dangerAccent;

  final Color warning;
  final Color warningStrong;
  final Color warningSoft;

  final Color info;
  final Color infoStrong;
  final Color infoSoft;

  /// Material blueAccent, used for secondary actions / links.
  final Color infoAccent;

  /// Premium gold (fixed in both modes).
  final Color premium;
  final Color premiumStrong;
  final Color onPremium;

  // ------------------------------------------------------------------ inverse
  /// High-contrast "inverted" fill (black buttons in light mode, near-white in
  /// dark mode) and its foreground.
  final Color inverseSurface;
  final Color onInverseSurface;

  // ------------------------------------------------------------------ effects
  /// Base shadow color; apply alpha at the call site.
  final Color shadow;

  /// Modal barrier / image scrim.
  final Color scrim;

  // ----------------------------------------------------------------- aliases
  bool get isDark => brightness == Brightness.dark;

  /// Amount someone owes the current user.
  Color get owed => success;

  /// Amount the current user owes.
  Color get owe => danger;

  /// Light tint background for a category hue: returns [lightTint] in light
  /// mode (so the existing look is kept) and [hue] at [darkAlpha] in dark
  /// mode, e.g. `p.tint(Colors.blueGrey[50]!, Colors.blueGrey)`.
  Color tint(Color lightTint, Color hue, {double darkAlpha = 0.18}) =>
      isDark ? hue.withValues(alpha: darkAlpha) : lightTint;

  // ----------------------------------------------------------------- presets
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: AppColors.backgroundLight, // #F5F7FA
    surface: AppColors.surfaceLight, // #FFFFFF
    surfaceVariant: Color(0xFFF5F5F5), // grey 100
    surfaceMuted: Color(0xFFFAFAFA), // grey 50
    border: AppColors.borderLight, // #E0E0E0 grey 300
    borderSubtle: Color(0xFFEEEEEE), // grey 200
    textPrimary: AppColors.textPrimaryLight, // #212121
    textStrong: Color(0xFF000000),
    textMedium: Color(0xFF616161), // grey 700
    textSecondary: AppColors.textSecondaryLight, // #757575 grey 600
    textTertiary: Color(0xFF9E9E9E), // grey 500
    textDisabled: AppColors.textDisabledLight, // #BDBDBD grey 400
    primary: AppColors.primary, // #00ACC1
    primaryStrong: AppColors.primaryDark, // #00838F
    primarySoft: Color(0xFFE0F7FA), // cyan 50
    onPrimary: Color(0xFFFFFFFF),
    primaryGradient: AppColors.primaryGradient,
    accent: AppColors.secondary, // #FF7043
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF4CAF50), // Colors.green
    successStrong: Color(0xFF388E3C), // green 700
    successSoft: Color(0xFFE8F5E9), // green 50
    danger: Color(0xFFF44336), // Colors.red
    dangerStrong: Color(0xFFD32F2F), // red 700
    dangerSoft: Color(0xFFFFEBEE), // red 50
    dangerAccent: AppColors.owingRed, // #FF5252 redAccent
    warning: Color(0xFFFF9800), // Colors.orange
    warningStrong: Color(0xFFEF6C00), // orange 800
    warningSoft: Color(0xFFFFF3E0), // orange 50
    info: Color(0xFF2196F3), // Colors.blue
    infoStrong: Color(0xFF1565C0), // blue 800
    infoSoft: Color(0xFFE3F2FD), // blue 50
    infoAccent: Color(0xFF448AFF), // blueAccent
    premium: Color(0xFFFFD700),
    premiumStrong: Color(0xFFFFA500),
    onPremium: Color(0xFF000000),
    inverseSurface: Color(0xFF000000),
    onInverseSurface: Color(0xFFFFFFFF),
    shadow: Color(0xFF000000),
    scrim: Color(0x8A000000), // black54
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: AppColors.backgroundDark, // #121212
    surface: AppColors.surfaceDark, // #1E1E1E
    surfaceVariant: AppColors.cardDark, // #2C2C2C
    surfaceMuted: Color(0xFF181818),
    border: AppColors.borderDark, // #404040
    borderSubtle: Color(0xFF333333),
    textPrimary: AppColors.textPrimaryDark, // #FFFFFF
    textStrong: Color(0xFFFFFFFF),
    textMedium: Color(0xFFC2C2C2),
    textSecondary: AppColors.textSecondaryDark, // #B0B0B0
    textTertiary: Color(0xFF9A9A9A),
    textDisabled: AppColors.textDisabledDark, // #707070
    // Brand stays the same in dark mode so buttons, chips and partially
    // migrated widgets keep white-on-primary.
    primary: AppColors.primary, // #00ACC1
    primaryStrong: AppColors.primaryLight, // #4DD0E1
    primarySoft: Color(0xFF0D3236),
    onPrimary: Color(0xFFFFFFFF),
    primaryGradient: LinearGradient(
      colors: [Color(0xFF0097A7), Color(0xFF006064)], // cyan 700 -> 900
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accent: Color(0xFFFF8A65), // deep orange 300
    onAccent: Color(0xFF000000),
    success: Color(0xFF66BB6A), // green 400
    successStrong: Color(0xFF81C784), // green 300
    successSoft: Color(0xFF1B2E1C),
    danger: Color(0xFFEF5350), // red 400
    dangerStrong: Color(0xFFE57373), // red 300
    dangerSoft: Color(0xFF3A1C1C),
    dangerAccent: Color(0xFFFF6E6E),
    warning: Color(0xFFFFA726), // orange 400
    warningStrong: Color(0xFFFFB74D), // orange 300
    warningSoft: Color(0xFF3A2A14),
    info: Color(0xFF42A5F5), // blue 400
    infoStrong: Color(0xFF90CAF9), // blue 200
    infoSoft: Color(0xFF102A43),
    // Same as light: it is used as a filled background under white icons.
    infoAccent: Color(0xFF448AFF),
    premium: Color(0xFFFFD700),
    premiumStrong: Color(0xFFFFA500),
    onPremium: Color(0xFF000000),
    inverseSurface: Color(0xFFF5F5F5),
    onInverseSurface: Color(0xFF000000),
    shadow: Color(0xFF000000),
    scrim: Color(0xB3000000), // black 70%
  );

  @override
  AppPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? surfaceMuted,
    Color? border,
    Color? borderSubtle,
    Color? textPrimary,
    Color? textStrong,
    Color? textMedium,
    Color? textSecondary,
    Color? textTertiary,
    Color? textDisabled,
    Color? primary,
    Color? primaryStrong,
    Color? primarySoft,
    Color? onPrimary,
    LinearGradient? primaryGradient,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? successStrong,
    Color? successSoft,
    Color? danger,
    Color? dangerStrong,
    Color? dangerSoft,
    Color? dangerAccent,
    Color? warning,
    Color? warningStrong,
    Color? warningSoft,
    Color? info,
    Color? infoStrong,
    Color? infoSoft,
    Color? infoAccent,
    Color? premium,
    Color? premiumStrong,
    Color? onPremium,
    Color? inverseSurface,
    Color? onInverseSurface,
    Color? shadow,
    Color? scrim,
  }) {
    return AppPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      textPrimary: textPrimary ?? this.textPrimary,
      textStrong: textStrong ?? this.textStrong,
      textMedium: textMedium ?? this.textMedium,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textDisabled: textDisabled ?? this.textDisabled,
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primarySoft: primarySoft ?? this.primarySoft,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      successStrong: successStrong ?? this.successStrong,
      successSoft: successSoft ?? this.successSoft,
      danger: danger ?? this.danger,
      dangerStrong: dangerStrong ?? this.dangerStrong,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      dangerAccent: dangerAccent ?? this.dangerAccent,
      warning: warning ?? this.warning,
      warningStrong: warningStrong ?? this.warningStrong,
      warningSoft: warningSoft ?? this.warningSoft,
      info: info ?? this.info,
      infoStrong: infoStrong ?? this.infoStrong,
      infoSoft: infoSoft ?? this.infoSoft,
      infoAccent: infoAccent ?? this.infoAccent,
      premium: premium ?? this.premium,
      premiumStrong: premiumStrong ?? this.premiumStrong,
      onPremium: onPremium ?? this.onPremium,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      onInverseSurface: onInverseSurface ?? this.onInverseSurface,
      shadow: shadow ?? this.shadow,
      scrim: scrim ?? this.scrim,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      surfaceVariant: c(surfaceVariant, other.surfaceVariant),
      surfaceMuted: c(surfaceMuted, other.surfaceMuted),
      border: c(border, other.border),
      borderSubtle: c(borderSubtle, other.borderSubtle),
      textPrimary: c(textPrimary, other.textPrimary),
      textStrong: c(textStrong, other.textStrong),
      textMedium: c(textMedium, other.textMedium),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      textDisabled: c(textDisabled, other.textDisabled),
      primary: c(primary, other.primary),
      primaryStrong: c(primaryStrong, other.primaryStrong),
      primarySoft: c(primarySoft, other.primarySoft),
      onPrimary: c(onPrimary, other.onPrimary),
      primaryGradient: LinearGradient.lerp(
        primaryGradient,
        other.primaryGradient,
        t,
      )!,
      accent: c(accent, other.accent),
      onAccent: c(onAccent, other.onAccent),
      success: c(success, other.success),
      successStrong: c(successStrong, other.successStrong),
      successSoft: c(successSoft, other.successSoft),
      danger: c(danger, other.danger),
      dangerStrong: c(dangerStrong, other.dangerStrong),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      dangerAccent: c(dangerAccent, other.dangerAccent),
      warning: c(warning, other.warning),
      warningStrong: c(warningStrong, other.warningStrong),
      warningSoft: c(warningSoft, other.warningSoft),
      info: c(info, other.info),
      infoStrong: c(infoStrong, other.infoStrong),
      infoSoft: c(infoSoft, other.infoSoft),
      infoAccent: c(infoAccent, other.infoAccent),
      premium: c(premium, other.premium),
      premiumStrong: c(premiumStrong, other.premiumStrong),
      onPremium: c(onPremium, other.onPremium),
      inverseSurface: c(inverseSurface, other.inverseSurface),
      onInverseSurface: c(onInverseSurface, other.onInverseSurface),
      shadow: c(shadow, other.shadow),
      scrim: c(scrim, other.scrim),
    );
  }
}

/// `context.palette.textPrimary`, `context.palette.surface`, ...
extension AppPaletteContext on BuildContext {
  /// The active [AppPalette]. Falls back to the palette matching the theme
  /// brightness if a theme without the extension is in scope.
  AppPalette get palette {
    final theme = Theme.of(this);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark
            ? AppPalette.dark
            : AppPalette.light);
  }

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
