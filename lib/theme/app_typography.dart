import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography system using Inter font family
/// Provides consistent text styles across the app
class AppTypography {
  AppTypography._(); // Private constructor

  // ==================== FONT FAMILY ====================

  static TextTheme get _baseTextTheme => GoogleFonts.interTextTheme();

  // ==================== DISPLAY STYLES ====================

  /// Large, bold headers (e.g., app name on login)
  static TextStyle displayLarge = _baseTextTheme.displayLarge!.copyWith(
    fontSize: 42,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Medium headers (e.g., bill totals)
  static TextStyle displayMedium = _baseTextTheme.displayMedium!.copyWith(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.25,
    height: 1.2,
  );

  /// Small headers (e.g., section titles)
  static TextStyle displaySmall = _baseTextTheme.displaySmall!.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  // ==================== HEADLINE STYLES ====================

  /// Page titles
  static TextStyle headlineLarge = _baseTextTheme.headlineLarge!.copyWith(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  /// Card titles
  static TextStyle headlineMedium = _baseTextTheme.headlineMedium!.copyWith(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
  );

  /// Subsection titles
  static TextStyle headlineSmall = _baseTextTheme.headlineSmall!.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
  );

  // ==================== TITLE STYLES ====================

  /// List item titles
  static TextStyle titleLarge = _baseTextTheme.titleLarge!.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  /// Small component titles
  static TextStyle titleMedium = _baseTextTheme.titleMedium!.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.5,
  );

  /// Chip labels, badges
  static TextStyle titleSmall = _baseTextTheme.titleSmall!.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // ==================== BODY STYLES ====================

  /// Primary content text
  static TextStyle bodyLarge = _baseTextTheme.bodyLarge!.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  );

  /// Secondary content text
  static TextStyle bodyMedium = _baseTextTheme.bodyMedium!.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  );

  /// Tertiary content text
  static TextStyle bodySmall = _baseTextTheme.bodySmall!.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
  );

  // ==================== LABEL STYLES ====================

  /// Button text large
  static TextStyle labelLarge = _baseTextTheme.labelLarge!.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  /// Button text standard
  static TextStyle labelMedium = _baseTextTheme.labelMedium!.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  /// Label text small (form labels, etc.)
  static TextStyle labelSmall = _baseTextTheme.labelSmall!.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // ==================== CAPTION STYLES ====================

  /// Timestamps, metadata
  static TextStyle caption = _baseTextTheme.bodySmall!.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.3,
  );

  /// Very small helper text
  static TextStyle overline = _baseTextTheme.labelSmall!.copyWith(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
    height: 1.6,
  );

  // ==================== CUSTOM UTILITY STYLES ====================

  /// Currency display (large amounts)
  static TextStyle currency = displayMedium.copyWith(
    fontWeight: FontWeight.w700,
    fontFeatures: [const FontFeature.tabularFigures()], // Monospace numbers
  );

  /// Small currency
  static TextStyle currencySmall = titleLarge.copyWith(
    fontWeight: FontWeight.w600,
    fontFeatures: [const FontFeature.tabularFigures()],
  );

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
}
