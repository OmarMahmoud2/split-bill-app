import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/theme/app_colors.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_spacing.dart';
import 'package:split_bill_app/theme/app_typography.dart';

/// Builds the app's [ThemeData] for light and dark mode from [AppPalette].
///
/// Every color here comes from the palette (or the brand primitives in
/// [AppColors]); change those, not this file, to restyle the app.
class AppTheme {
  AppTheme._(); // Private constructor

  static ThemeData get lightTheme => _build(
    AppPalette.light,
    colorScheme: ColorScheme.light(
      primary: AppPalette.light.primary,
      onPrimary: AppPalette.light.onPrimary,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.secondaryLight,
      onSecondaryContainer: AppColors.secondaryDark,
      tertiary: AppColors.info,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorLight,
      onErrorContainer: AppColors.errorDark,
      surface: AppPalette.light.surface,
      onSurface: AppPalette.light.textPrimary,
      surfaceContainerHighest: AppPalette.light.background,
      outline: AppPalette.light.border,
      shadow: AppColors.shadowLight,
    ),
    cardShadow: AppColors.shadowLight,
    snackBarBackground: AppPalette.light.textPrimary,
    snackBarForeground: Colors.white,
    chipBackground: AppColors.primaryLight,
  );

  static ThemeData get darkTheme => _build(
    AppPalette.dark,
    colorScheme: ColorScheme.dark(
      primary: AppPalette.dark.primary,
      onPrimary: AppPalette.dark.onPrimary,
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: AppColors.primaryLight,
      secondary: AppPalette.dark.accent,
      onSecondary: AppPalette.dark.onAccent,
      secondaryContainer: AppColors.secondaryDark,
      onSecondaryContainer: AppColors.secondaryLight,
      tertiary: AppColors.info,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorDark,
      onErrorContainer: AppColors.errorLight,
      surface: AppPalette.dark.surface,
      onSurface: AppPalette.dark.textPrimary,
      onSurfaceVariant: AppPalette.dark.textSecondary,
      surfaceContainerHighest: AppPalette.dark.surfaceVariant,
      outline: AppPalette.dark.border,
      outlineVariant: AppPalette.dark.borderSubtle,
      shadow: AppColors.shadowDark,
    ),
    cardShadow: AppColors.shadowDark,
    snackBarBackground: AppColors.cardDark,
    snackBarForeground: AppPalette.dark.textPrimary,
    chipBackground: AppColors.primaryDark,
  );

  /// Status bar / navigation bar style matching [brightness] of the theme:
  /// dark icons on light themes, light icons on dark themes.
  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      // Android
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      // iOS (describes the status bar background, not the icons)
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  static ThemeData _build(
    AppPalette p, {
    required ColorScheme colorScheme,
    required Color cardShadow,
    required Color snackBarBackground,
    required Color snackBarForeground,
    required Color chipBackground,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: colorScheme,
      extensions: [p],

      // Scaffold
      scaffoldBackgroundColor: p.background,

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: overlayStyleFor(p.brightness),
        titleTextStyle: AppTypography.headlineMedium.copyWith(
          color: p.textPrimary,
        ),
        iconTheme: IconThemeData(color: p.textPrimary, size: AppSpacing.iconLg),
      ),

      // Card
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: AppSpacing.elevationSm,
        shadowColor: cardShadow,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.sm,
        ),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          elevation: AppSpacing.elevationMd,
          shadowColor: cardShadow,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(0, AppSpacing.buttonLg),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: AppTypography.labelMedium,
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(0, AppSpacing.buttonLg),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: AppSpacing.elevationMd,
        shape: const CircleBorder(),
      ),

      // Input Decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: AppSpacing.allLg,
        border: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: BorderSide(color: p.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppSpacing.borderRadiusMd,
          borderSide: const BorderSide(color: AppColors.error),
        ),
        labelStyle: AppTypography.bodyMedium.copyWith(color: p.textSecondary),
        hintStyle: AppTypography.bodyMedium.copyWith(color: p.textDisabled),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: chipBackground,
        selectedColor: p.primary,
        disabledColor: p.textDisabled,
        labelStyle: AppTypography.labelSmall,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
      ),

      // Divider
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),

      // Bottom Sheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        elevation: AppSpacing.elevationXl,
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusBottomSheet,
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: AppSpacing.elevationLg,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusXl),
        titleTextStyle: AppTypography.headlineMedium.copyWith(
          color: p.textPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: p.textSecondary,
        ),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: snackBarBackground,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: snackBarForeground,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        behavior: SnackBarBehavior.floating,
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.textSecondary,
        elevation: AppSpacing.elevationMd,
        type: BottomNavigationBarType.fixed,
      ),

      // Typography
      textTheme: AppTypography.textTheme.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
    );
  }
}
