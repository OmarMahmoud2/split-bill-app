import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_colors.dart';

/// Semantic color roles for the app, with a light and a dark value each.
///
/// This is the single source of truth for themable colors. Widgets read it
/// through `context.palette` and never hard-code `Colors.*` for surfaces,
/// text or brand colors.
///
/// Values follow the v3 "Quiet ledger" system (design `v3/System.dc.html`):
/// warm neutrals, one teal [accent], amber for what you owe ([owe]), red
/// ([error]) only for errors and destructive actions. A sign or a word must
/// always sit next to a color.
///
/// The pre-v3 role names ([primary], [success], [danger], [warning], ...)
/// are kept and mapped onto v3 values so existing call sites keep compiling:
///
/// | legacy role          | v3 meaning                         |
/// |----------------------|------------------------------------|
/// | background           | canvas                             |
/// | border               | hairline                           |
/// | borderSubtle         | row divider                        |
/// | primary / accent     | teal accent                        |
/// | primarySoft          | teal soft ([accentSoft])           |
/// | success              | teal accent (owed to you)          |
/// | danger / dangerAccent| error red                          |
/// | warning              | owe amber                          |
///
/// Note: `danger` is error red, not "you owe". Use [owe] for amounts the
/// user owes.
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
    required this.borderStrong,
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
    required this.accentSoft,
    required this.onAccentSoft,
    required this.owe,
    required this.oweSoft,
    required this.oweInk,
    required this.error,
    required this.onError,
    required this.errorSoft,
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
    required this.skeleton,
    required this.skeletonHighlight,
    required this.shadow,
    required this.scrim,
  });

  final Brightness brightness;

  // ---------------------------------------------------------------- surfaces
  /// Scaffold / page background (v3 canvas).
  final Color background;

  /// Cards, sheets, dialogs, inputs.
  final Color surface;

  /// Muted fill on top of a surface: chips, tiles, segmented controls.
  final Color surfaceVariant;

  /// Very subtle fill / alternative page background.
  final Color surfaceMuted;

  /// Default border: the v3 1 px hairline around cards and inputs.
  final Color border;

  /// Divider between rows inside a card.
  final Color borderSubtle;

  /// Stronger outline: secondary (ghost) buttons, radio rings.
  final Color borderStrong;

  // -------------------------------------------------------------------- text
  /// Body text and titles (v3 ink).
  final Color textPrimary;

  /// Maximum-emphasis text.
  final Color textStrong;

  /// Between primary and secondary.
  final Color textMedium;

  /// Secondary text, captions, icons (v3 muted).
  final Color textSecondary;

  /// Tertiary text and hints (still 4.5:1 on every surface).
  final Color textTertiary;

  /// Disabled text and icons (exempt from contrast rules).
  final Color textDisabled;

  // ------------------------------------------------------------------- brand
  /// Teal accent for selection, links, switches and focus. Primary filled
  /// buttons use [inverseSurface] (ink), per the v3 mockups.
  final Color primary;

  /// Higher-contrast teal for small accent text.
  final Color primaryStrong;

  /// Teal tint for selected chips / badge backgrounds.
  final Color primarySoft;

  /// Text and icons on [primary] and on [primaryGradient].
  final Color onPrimary;

  /// Legacy brand gradient (now a quiet teal ramp).
  final LinearGradient primaryGradient;

  /// The one v3 accent (teal). Same as [primary].
  final Color accent;
  final Color onAccent;

  /// Teal soft fill and the text color to use on it.
  final Color accentSoft;
  final Color onAccentSoft;

  // ------------------------------------------------------------------ money
  /// "You owe" amounts: amber, never red.
  final Color owe;

  /// Amber soft fill and the text color to use on it.
  final Color oweSoft;
  final Color oweInk;

  // ---------------------------------------------------------------- semantic
  /// Errors and destructive actions only.
  final Color error;
  final Color onError;
  final Color errorSoft;

  /// Positive state (teal, like owed-to-you amounts).
  final Color success;
  final Color successStrong;
  final Color successSoft;

  /// Legacy name for [error].
  final Color danger;
  final Color dangerStrong;
  final Color dangerSoft;
  final Color dangerAccent;

  /// Caution (amber, the same hue as [owe]).
  final Color warning;
  final Color warningStrong;
  final Color warningSoft;

  final Color info;
  final Color infoStrong;
  final Color infoSoft;
  final Color infoAccent;

  /// Premium gold (fixed in both modes).
  final Color premium;
  final Color premiumStrong;
  final Color onPremium;

  // ------------------------------------------------------------------ inverse
  /// Ink fill (primary pill buttons, offline banner, toasts) and its
  /// foreground.
  final Color inverseSurface;
  final Color onInverseSurface;

  // ------------------------------------------------------------------ effects
  /// Skeleton loader base and shimmer highlight.
  final Color skeleton;
  final Color skeletonHighlight;

  /// Base shadow color; apply alpha at the call site.
  final Color shadow;

  /// Modal barrier / image scrim.
  final Color scrim;

  // ----------------------------------------------------------------- aliases
  bool get isDark => brightness == Brightness.dark;

  /// v3 name for [background].
  Color get canvas => background;

  /// v3 name for [border].
  Color get hairline => border;

  /// Amount someone owes the current user (teal).
  Color get owed => accent;

  /// Soft fill / ink for "owed to you" chips.
  Color get owedSoft => accentSoft;
  Color get owedInk => onAccentSoft;

  /// Neutral amount (settled or informational).
  Color get neutralAmount => textPrimary;

  /// Avatar tints for telling people apart; text on them is [textPrimary].
  List<Color> get avatarTints =>
      isDark ? AppColors.avatarTintsDark : AppColors.avatarTintsLight;

  /// Stable avatar tint for a person id/name.
  Color avatarTintFor(String key) {
    final tints = avatarTints;
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return tints[hash % tints.length];
  }

  /// The one soft shadow v3 allows (sheets and menus), light mode only. In
  /// dark mode depth comes from a lighter surface tone, so this is empty.
  List<BoxShadow> get sheetShadow => isDark
      ? const []
      : [
          BoxShadow(
            color: shadow.withValues(alpha: 0.08),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ];

  /// Light tint background for a category hue: returns [lightTint] in light
  /// mode and [hue] at [darkAlpha] in dark mode, e.g.
  /// `p.tint(Colors.blueGrey[50]!, Colors.blueGrey)`.
  Color tint(Color lightTint, Color hue, {double darkAlpha = 0.18}) =>
      isDark ? hue.withValues(alpha: darkAlpha) : lightTint;

  // ----------------------------------------------------------------- presets
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: AppColors.canvasLight, // #F7F7F5
    surface: AppColors.surfaceLight, // #FFFFFF
    surfaceVariant: AppColors.surface2Light, // #F2F1EE
    surfaceMuted: AppColors.canvasLight,
    border: AppColors.hairlineLight, // #E7E6E1
    borderSubtle: AppColors.dividerSubtleLight, // #EFEEEA
    borderStrong: AppColors.borderStrongLight, // #D9D8D3
    textPrimary: AppColors.inkLight, // #111312
    textStrong: AppColors.inkLight,
    textMedium: AppColors.inkMediumLight, // #3A3D3B
    textSecondary: AppColors.mutedLight, // #5F6360
    textTertiary: AppColors.tertiaryLight, // #6B6F6C
    textDisabled: AppColors.disabledLight,
    primary: AppColors.tealLight, // #0F766E
    primaryStrong: AppColors.tealStrongLight,
    primarySoft: AppColors.tealSoftLight, // #E6F2F0
    onPrimary: Color(0xFFFFFFFF),
    primaryGradient: AppColors.primaryGradient,
    accent: AppColors.tealLight,
    onAccent: Color(0xFFFFFFFF),
    accentSoft: AppColors.tealSoftLight,
    onAccentSoft: AppColors.tealInkLight, // #0B4F49
    owe: AppColors.amberLight, // #B45309
    oweSoft: AppColors.amberSoftLight, // #FBF1E6
    oweInk: AppColors.amberInkLight, // #7A3E06
    error: AppColors.errorRedLight, // #B42318
    onError: Color(0xFFFFFFFF),
    errorSoft: AppColors.errorSoftLight,
    success: AppColors.tealLight,
    successStrong: AppColors.tealStrongLight,
    successSoft: AppColors.tealSoftLight,
    danger: AppColors.errorRedLight,
    dangerStrong: AppColors.errorStrongLight,
    dangerSoft: AppColors.errorSoftLight,
    dangerAccent: AppColors.errorRedLight,
    warning: AppColors.amberLight,
    warningStrong: AppColors.amberInkLight,
    warningSoft: AppColors.amberSoftLight,
    info: AppColors.info, // #3B5B7A
    infoStrong: Color(0xFF2A445E),
    infoSoft: AppColors.infoLight,
    infoAccent: AppColors.info,
    premium: Color(0xFFFFD700),
    premiumStrong: Color(0xFFFFA500),
    onPremium: Color(0xFF000000),
    inverseSurface: AppColors.inkLight,
    onInverseSurface: Color(0xFFFFFFFF),
    skeleton: AppColors.dividerSubtleLight, // #EFEEEA
    skeletonHighlight: AppColors.canvasLight,
    shadow: AppColors.inkLight,
    scrim: Color(0x59111312), // ink 35%
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: AppColors.canvasDark, // #0E0F0E
    surface: AppColors.surfaceDarkV3, // #171918
    surfaceVariant: AppColors.surface2Dark, // #1F221F
    surfaceMuted: Color(0xFF131514),
    border: AppColors.hairlineDark, // #262927
    borderSubtle: AppColors.dividerSubtleDark, // #222523
    borderStrong: AppColors.borderStrongDark,
    textPrimary: AppColors.inkDark, // #F2F3F1
    textStrong: AppColors.inkDark,
    textMedium: AppColors.inkMediumDark,
    textSecondary: AppColors.mutedDark, // #A3A8A5
    textTertiary: AppColors.tertiaryDark,
    textDisabled: AppColors.disabledDark,
    primary: AppColors.tealDark, // #34C5B0
    primaryStrong: AppColors.tealStrongDark,
    primarySoft: AppColors.tealSoftDark, // #12322E
    onPrimary: AppColors.canvasDark,
    primaryGradient: LinearGradient(
      colors: [AppColors.tealDark, Color(0xFF2BA894)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accent: AppColors.tealDark,
    onAccent: AppColors.canvasDark,
    accentSoft: AppColors.tealSoftDark,
    onAccentSoft: AppColors.tealInkDark,
    owe: AppColors.amberDark, // #F0B35E
    oweSoft: AppColors.amberSoftDark,
    oweInk: AppColors.amberInkDark,
    error: AppColors.errorRedDark,
    onError: AppColors.canvasDark,
    errorSoft: AppColors.errorSoftDark,
    success: AppColors.tealDark,
    successStrong: AppColors.tealStrongDark,
    successSoft: AppColors.tealSoftDark,
    danger: AppColors.errorRedDark,
    dangerStrong: AppColors.errorStrongDark,
    dangerSoft: AppColors.errorSoftDark,
    dangerAccent: AppColors.errorRedDark,
    warning: AppColors.amberDark,
    warningStrong: AppColors.amberInkDark,
    warningSoft: AppColors.amberSoftDark,
    info: Color(0xFF8DB3D9),
    infoStrong: Color(0xFFB5CDE6),
    infoSoft: Color(0xFF16222E),
    infoAccent: Color(0xFF8DB3D9),
    premium: Color(0xFFFFD700),
    premiumStrong: Color(0xFFFFA500),
    onPremium: Color(0xFF000000),
    inverseSurface: AppColors.inkDark,
    onInverseSurface: AppColors.canvasDark,
    skeleton: AppColors.dividerSubtleDark,
    skeletonHighlight: Color(0xFF2A2D2B),
    shadow: Color(0xFF000000),
    scrim: Color(0x99000000), // black 60%
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
    Color? borderStrong,
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
    Color? accentSoft,
    Color? onAccentSoft,
    Color? owe,
    Color? oweSoft,
    Color? oweInk,
    Color? error,
    Color? onError,
    Color? errorSoft,
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
    Color? skeleton,
    Color? skeletonHighlight,
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
      borderStrong: borderStrong ?? this.borderStrong,
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
      accentSoft: accentSoft ?? this.accentSoft,
      onAccentSoft: onAccentSoft ?? this.onAccentSoft,
      owe: owe ?? this.owe,
      oweSoft: oweSoft ?? this.oweSoft,
      oweInk: oweInk ?? this.oweInk,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      errorSoft: errorSoft ?? this.errorSoft,
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
      skeleton: skeleton ?? this.skeleton,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
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
      borderStrong: c(borderStrong, other.borderStrong),
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
      accentSoft: c(accentSoft, other.accentSoft),
      onAccentSoft: c(onAccentSoft, other.onAccentSoft),
      owe: c(owe, other.owe),
      oweSoft: c(oweSoft, other.oweSoft),
      oweInk: c(oweInk, other.oweInk),
      error: c(error, other.error),
      onError: c(onError, other.onError),
      errorSoft: c(errorSoft, other.errorSoft),
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
      skeleton: c(skeleton, other.skeleton),
      skeletonHighlight: c(skeletonHighlight, other.skeletonHighlight),
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
