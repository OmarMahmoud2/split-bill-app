import 'package:flutter/material.dart';

/// "Midnight & Mint" typography.
///
/// * **Inter** (400/500/600/700) for reading, labels and rows.
/// * **Plus Jakarta Sans** (600/700/800) with tabular figures for every
///   amount and for display titles.
///
/// Both are bundled under `assets/fonts/` (SIL Open Font License 1.1, see
/// `assets/fonts/*/OFL.txt`) and registered in `pubspec.yaml`, so nothing
/// is fetched at runtime.
///
/// ### Non-Latin scripts
/// Inter covers Latin, Cyrillic, Greek and Vietnamese. Arabic, Urdu, Hindi,
/// Thai and CJK glyphs fall back to the platform's system fonts (Flutter
/// does this automatically when a glyph is missing from Inter). Those
/// scripts have taller ascenders/descenders and stacked marks, so the line
/// height is multiplied per locale (see [scriptHeightFactor]):
///
/// | locale | factor | why |
/// |--------|--------|-----|
/// | ar     | 1.20   | Naskh marks above and below the baseline |
/// | ur     | 1.25   | iOS renders Urdu in Nastaliq, which needs ~1.8-2.2x line height |
/// | hi     | 1.20   | Devanagari headline (shirorekha) and matras |
/// | th     | 1.20   | Stacked tone marks and vowels |
/// | others | 1.00   | |
///
/// (Research: docs/2.0/COMPETITOR_RESEARCH.md section 4.3, "increase line
/// height by about 15-25% for Arabic, Urdu, Thai and Hindi".)
/// [MaterialApp.builder] applies this via [AppLocaleTypography].
class AppTypography {
  AppTypography._(); // Private constructor

  // ==================== FONT FAMILY ====================

  /// Body / UI font family (bundled asset).
  static const String bodyFamily = 'Inter';

  /// Numbers and display titles (bundled asset).
  static const String displayFamily = 'PlusJakartaSans';

  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static const TextStyle _body = TextStyle(
    fontFamily: bodyFamily,
    leadingDistribution: TextLeadingDistribution.even,
  );

  static const TextStyle _display = TextStyle(
    fontFamily: displayFamily,
    fontFeatures: tabularFigures,
    leadingDistribution: TextLeadingDistribution.even,
  );

  // ==================== DISPLAY STYLES (Plus Jakarta Sans) ====================

  /// Large, bold headers (e.g. hero balance on Home).
  static TextStyle displayLarge = _display.copyWith(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    height: 1.1,
  );

  /// Medium headers (e.g. bill totals).
  static TextStyle displayMedium = _display.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.8,
    height: 1.15,
  );

  /// Small headers (e.g. "3 payments settle everyone").
  static TextStyle displaySmall = _display.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
  );

  // ==================== HEADLINE STYLES ====================

  /// Page titles (Plus Jakarta Sans).
  static TextStyle headlineLarge = _display.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.25,
  );

  /// Card titles, sheet titles (Plus Jakarta Sans).
  static TextStyle headlineMedium = _display.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// Subsection titles (Inter).
  static TextStyle headlineSmall = _body.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.35,
  );

  // ==================== TITLE STYLES (Inter) ====================

  /// List item titles, app bar titles.
  static TextStyle titleLarge = _body.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  /// Row labels.
  static TextStyle titleMedium = _body.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Chip labels, badges.
  static TextStyle titleSmall = _body.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  // ==================== BODY STYLES (Inter) ====================

  /// Primary reading text (16/24).
  static TextStyle bodyLarge = _body.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Secondary content text (15/22).
  static TextStyle bodyMedium = _body.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 22 / 15,
  );

  /// Tertiary content text.
  static TextStyle bodySmall = _body.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.4,
  );

  // ==================== LABEL STYLES (Inter) ====================

  /// Button text large.
  static TextStyle labelLarge = _body.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Button text standard.
  static TextStyle labelMedium = _body.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Small labels.
  static TextStyle labelSmall = _body.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // ==================== CAPTION STYLES ====================

  /// Timestamps, metadata (13/18 w500).
  static TextStyle caption = _body.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Section captions (sentence case, never all caps).
  static TextStyle overline = _body.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    height: 1.4,
  );

  // ==================== AMOUNTS (Plus Jakarta Sans, tabular) ====================

  /// Hero amount (Home net balance, success screen): 56 w700.
  static TextStyle amountHero = _display.copyWith(
    fontSize: 56,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.5,
    height: 1.1,
  );

  /// Large amount (cards): 32 w700.
  static TextStyle amountLarge = _display.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.15,
  );

  /// Row amount: 17 w700.
  static TextStyle amount = _display.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// Small inline amount: 14 w600.
  static TextStyle amountSmall = _display.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Legacy: large currency display.
  static TextStyle currency = displayMedium;

  /// Legacy: small currency.
  static TextStyle currencySmall = amount.copyWith(fontSize: 16);

  // ==================== TEXT THEME FOR MaterialApp ====================

  static TextTheme get textTheme => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );

  // ==================== SCRIPT SUPPORT ====================

  /// Line-height multiplier for scripts that fall back to system fonts.
  static double scriptHeightFactor(Locale? locale) {
    switch (locale?.languageCode) {
      case 'ar':
      case 'hi':
      case 'th':
        return 1.2;
      case 'ur':
        return 1.25;
      default:
        return 1.0;
    }
  }

  /// [theme] with line heights scaled for [locale]'s script.
  static TextTheme localize(TextTheme theme, Locale? locale) {
    final factor = scriptHeightFactor(locale);
    if (factor == 1.0) return theme;
    return theme.apply(heightFactor: factor);
  }
}

/// Re-themes [child] so text line heights suit the active locale's script.
/// Put it in `MaterialApp.builder`.
class AppLocaleTypography extends StatelessWidget {
  const AppLocaleTypography({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    if (AppTypography.scriptHeightFactor(locale) == 1.0) return child;
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        textTheme: AppTypography.localize(theme.textTheme, locale),
      ),
      child: child,
    );
  }
}
