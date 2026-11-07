import 'package:flutter/material.dart';
import 'package:split_bill_app/theme/app_colors.dart';

/// Semantic color roles for the app, with a light and a dark value each.
///
/// This is the single source of truth for themable colors. Widgets read it
/// through `context.palette` and never hard-code `Colors.*` for surfaces,
/// text or brand colors.
///
/// Values follow the "Midnight & Mint" system (docs/2.0/PREMIUM_POLISH.md):
/// blue-tinted neutrals, mint [accent] for what is owed to you and for
/// selection/focus, coral ([owe]) for what you owe, sky ([sky]) for pending
/// confirmation, red ([error]) only for errors and destructive actions. A sign
/// or a word must always sit next to a color.
///
/// The pre-v3 role names ([primary], [success], [danger], [warning], ...)
/// are kept and mapped onto these values so existing call sites keep compiling:
///
/// | legacy role          | meaning                            |
/// |----------------------|------------------------------------|
/// | background           | canvas                             |
/// | border               | hairline                           |
/// | borderSubtle         | row divider                        |
/// | primary / accent     | mint accent                        |
/// | primarySoft          | mint soft ([accentSoft])           |
/// | success              | mint accent (owed to you)          |
/// | danger / dangerAccent| error red                          |
/// | warning              | coral (same as [owe])              |
/// | info                 | sky                                |
///
/// Extra roles that are derived from brightness (no constructor field):
/// [raised], [onMint], [coral], [coralSoft], [onCoralSoft], [coralText],
/// [sky], [skySoft], [hero], [onHero], [heroLine], [heroShadow], [softShadow],
/// [toast], [onToast], [gold].
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
  /// Mint accent for selection, links, switches and focus. Primary filled
  /// buttons use [inverseSurface] (ink in light, mint in dark).
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
  /// "You owe" amounts: coral, never red.
  final Color owe;

  /// Coral soft fill and the text color to use on it.
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

  /// Caution (coral, the same hue as [owe]).
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

  /// Muted fill for chips, tiles and the segmented track.
  Color get raised => surfaceVariant;

  /// Text and icons on the filled mint accent.
  Color get onMint => isDark ? AppColors.onMintDark : const Color(0xFFFFFFFF);

  /// Brand coral for icons and fills (amount text uses [owe] / [coralText],
  /// the darker coral in light mode).
  Color get coral => isDark ? AppColors.coralDark : AppColors.coralLight;
  Color get coralSoft => oweSoft;
  Color get onCoralSoft => oweInk;

  /// Coral that passes contrast for small amount text.
  Color get coralText => owe;

  /// Waiting / pending confirmation.
  Color get sky => isDark ? AppColors.skyDark : AppColors.skyLight;
  Color get skySoft => isDark ? AppColors.skySoftDark : AppColors.skySoftLight;

  /// Balance hero card fill (ink in light, raised navy in dark).
  Color get hero => isDark ? AppColors.surface2Dark : AppColors.inkLight;

  /// 1px inner line on the dark hero card (transparent in light).
  Color get heroLine => isDark ? AppColors.heroLineDark : const Color(0x00000000);

  /// Text on [hero].
  Color get onHero => isDark ? AppColors.inkDark : const Color(0xFFFFFFFF);

  /// Shadow under the hero card (light mode only).
  List<BoxShadow> get heroShadow => isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x380E1526),
            offset: Offset(0, 16),
            blurRadius: 32,
          ),
        ];

  /// Soft shadow under primary buttons and the floating nav.
  List<BoxShadow> get softShadow => [
    BoxShadow(
      color: (isDark ? const Color(0xFF000000) : AppColors.inkLight)
          .withValues(alpha: isDark ? 0.4 : 0.14),
      offset: const Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  /// Toast / snackbar / offline banner fill and its text color (ink in
  /// light, raised navy in dark; never the loud mint of [inverseSurface]).
  Color get toast => isDark ? AppColors.surface2Dark : AppColors.inkLight;
  Color get onToast => isDark ? AppColors.inkDark : const Color(0xFFFFFFFF);

  /// Premium gold (on ink).
  Color get gold => AppColors.goldPremium;

  /// v3 name for [background].
  Color get canvas => background;

  /// v3 name for [border].
  Color get hairline => border;

  /// Amount someone owes the current user (mint).
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
    background: AppColors.canvasLight, // #F5F7FB
    surface: AppColors.surfaceLight, // #FFFFFF
    surfaceVariant: AppColors.surface2Light, // #EEF1F6
    surfaceMuted: AppColors.canvasLight,
    border: AppColors.hairlineLight, // #E3E7EF
    borderSubtle: AppColors.dividerSubtleLight, 
    borderStrong: AppColors.borderStrongLight, 
    textPrimary: AppColors.inkLight, // #0E1526
    textStrong: AppColors.inkLight,
    textMedium: AppColors.inkMediumLight, 
    textSecondary: AppColors.mutedLight, // #5B6478
    textTertiary: AppColors.tertiaryLight, // #6B7489
    textDisabled: AppColors.disabledLight,
    primary: AppColors.tealLight, // #0E7C72
    primaryStrong: AppColors.tealStrongLight,
    primarySoft: AppColors.tealSoftLight, // #E3F7F3
    onPrimary: Color(0xFFFFFFFF),
    primaryGradient: AppColors.primaryGradient,
    accent: AppColors.tealLight,
    onAccent: Color(0xFFFFFFFF),
    accentSoft: AppColors.tealSoftLight,
    onAccentSoft: AppColors.tealInkLight, // #0A5F57
    owe: AppColors.coralTextLight, // #C2452D (text-safe coral)
    oweSoft: AppColors.coralSoftLight, // #FBF1E6
    oweInk: AppColors.coralInkLight, // #A8381F
    error: AppColors.errorRedLight, // #C62828
    onError: Color(0xFFFFFFFF),
    errorSoft: AppColors.errorSoftLight,
    success: AppColors.tealLight,
    successStrong: AppColors.tealStrongLight,
    successSoft: AppColors.tealSoftLight,
    danger: AppColors.errorRedLight,
    dangerStrong: AppColors.errorStrongLight,
    dangerSoft: AppColors.errorSoftLight,
    dangerAccent: AppColors.errorRedLight,
    warning: AppColors.coralTextLight,
    warningStrong: AppColors.coralInkLight,
    warningSoft: AppColors.coralSoftLight,
    info: AppColors.skyLight,
    infoStrong: Color(0xFF2B55B8),
    infoSoft: AppColors.skySoftLight,
    infoAccent: AppColors.skyLight,
    premium: AppColors.goldPremium,
    premiumStrong: Color(0xFFFFA500),
    onPremium: Color(0xFF000000),
    inverseSurface: AppColors.inkLight,
    onInverseSurface: Color(0xFFFFFFFF),
    skeleton: AppColors.dividerSubtleLight, 
    skeletonHighlight: AppColors.canvasLight,
    shadow: AppColors.inkLight,
    scrim: Color(0x590E1526), // ink 35%
  );

  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: AppColors.canvasDark, // #0A0F1C
    surface: AppColors.surfaceDarkV3, // #121A2B
    surfaceVariant: AppColors.surface2Dark, // #1A2438
    surfaceMuted: Color(0xFF0E1525),
    border: AppColors.hairlineDark, // #22304A
    borderSubtle: AppColors.dividerSubtleDark, 
    borderStrong: AppColors.borderStrongDark,
    textPrimary: AppColors.inkDark, // #E8EDF7
    textStrong: AppColors.inkDark,
    textMedium: AppColors.inkMediumDark,
    textSecondary: AppColors.mutedDark, // #9AA4B8
    textTertiary: AppColors.tertiaryDark,
    textDisabled: AppColors.disabledDark,
    primary: AppColors.tealDark, // #34D7C0
    primaryStrong: AppColors.tealStrongDark,
    primarySoft: AppColors.tealSoftDark, 
    onPrimary: AppColors.onMintDark,
    primaryGradient: LinearGradient(
      colors: [AppColors.tealDark, Color(0xFF22B8A4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accent: AppColors.tealDark,
    onAccent: AppColors.onMintDark,
    accentSoft: AppColors.tealSoftDark,
    onAccentSoft: AppColors.tealInkDark,
    owe: AppColors.coralDark, // #FF8A70
    oweSoft: AppColors.coralSoftDark,
    oweInk: AppColors.coralDark,
    error: AppColors.errorRedDark,
    onError: AppColors.onMintDark,
    errorSoft: AppColors.errorSoftDark,
    success: AppColors.tealDark,
    successStrong: AppColors.tealStrongDark,
    successSoft: AppColors.tealSoftDark,
    danger: AppColors.errorRedDark,
    dangerStrong: AppColors.errorStrongDark,
    dangerSoft: AppColors.errorSoftDark,
    dangerAccent: AppColors.errorRedDark,
    warning: AppColors.coralDark,
    warningStrong: AppColors.coralDark,
    warningSoft: AppColors.coralSoftDark,
    info: AppColors.skyDark,
    infoStrong: Color(0xFFA8C2FF),
    infoSoft: AppColors.skySoftDark,
    infoAccent: AppColors.skyDark,
    premium: AppColors.goldPremium,
    premiumStrong: Color(0xFFFFA500),
    onPremium: Color(0xFF000000),
    inverseSurface: AppColors.tealDark,
    onInverseSurface: AppColors.onMintDark,
    skeleton: AppColors.dividerSubtleDark,
    skeletonHighlight: Color(0xFF26324A),
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
