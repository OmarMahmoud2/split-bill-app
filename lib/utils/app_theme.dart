import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/theme/app_colors.dart';
import 'package:split_bill_app/theme/app_spacing.dart';
import 'package:split_bill_app/theme/app_typography.dart';

/// Modern app theme using the new design system
class AppTheme {
  AppTheme._(); // Private constructor

  // ==================== LIGHT THEME ====================

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color Scheme
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
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
      surface: AppColors.surfaceLight,
      onSurface: AppColors.textPrimaryLight,
      surfaceContainerHighest: AppColors.backgroundLight,
      outline: AppColors.borderLight,
      shadow: AppColors.shadowLight,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.backgroundLight,

    // App Bar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: AppTypography.headlineMedium.copyWith(
        color: AppColors.textPrimaryLight,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryLight,
        size: AppSpacing.iconLg,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.cardLight,
      elevation: AppSpacing.elevationSm,
      shadowColor: AppColors.shadowLight,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: AppSpacing.elevationMd,
        shadowColor: AppColors.shadowLight,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        textStyle: AppTypography.labelLarge,
        minimumSize: const Size(0, AppSpacing.buttonLg),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
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
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        textStyle: AppTypography.labelLarge,
        minimumSize: const Size(0, AppSpacing.buttonLg),
      ),
    ),

    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: AppSpacing.elevationMd,
      shape: CircleBorder(),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: AppSpacing.allLg,
      border: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textSecondaryLight,
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textDisabledLight,
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryLight,
      selectedColor: AppColors.primary,
      disabledColor: AppColors.textDisabledLight,
      labelStyle: AppTypography.labelSmall,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerLight,
      thickness: 1,
      space: 1,
    ),

    // Bottom Sheet
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surfaceLight,
      elevation: AppSpacing.elevationXl,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusBottomSheet,
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceLight,
      elevation: AppSpacing.elevationLg,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusXl),
      titleTextStyle: AppTypography.headlineMedium.copyWith(
        color: AppColors.textPrimaryLight,
      ),
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textSecondaryLight,
      ),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimaryLight,
      contentTextStyle: AppTypography.bodyMedium.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      behavior: SnackBarBehavior.floating,
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondaryLight,
      elevation: AppSpacing.elevationMd,
      type: BottomNavigationBarType.fixed,
    ),

    // Typography
    textTheme: AppTypography.textTheme.apply(
      bodyColor: AppColors.textPrimaryLight,
      displayColor: AppColors.textPrimaryLight,
    ),
  );

  // ==================== DARK THEME ====================

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: ColorScheme.dark(
      primary: AppColors.primaryLight,
      onPrimary: AppColors.textPrimaryDark,
      primaryContainer: AppColors.primaryDark,
      onPrimaryContainer: AppColors.primaryLight,
      secondary: AppColors.secondaryLight,
      onSecondary: AppColors.textPrimaryDark,
      secondaryContainer: AppColors.secondaryDark,
      onSecondaryContainer: AppColors.secondaryLight,
      tertiary: AppColors.info,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorDark,
      onErrorContainer: AppColors.errorLight,
      surface: AppColors.surfaceDark,
      onSurface: AppColors.textPrimaryDark,
      surfaceContainerHighest: AppColors.backgroundDark,
      outline: AppColors.borderDark,
      shadow: AppColors.shadowDark,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.backgroundDark,

    // App Bar
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: AppTypography.headlineMedium.copyWith(
        color: AppColors.textPrimaryDark,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryDark,
        size: AppSpacing.iconLg,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.cardDark,
      elevation: AppSpacing.elevationSm,
      shadowColor: AppColors.shadowDark,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusLg),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.sm,
      ),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: AppSpacing.elevationMd,
        shadowColor: AppColors.shadowDark,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        textStyle: AppTypography.labelLarge,
        minimumSize: const Size(0, AppSpacing.buttonLg),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
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
        foregroundColor: AppColors.primaryLight,
        side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
        textStyle: AppTypography.labelLarge,
        minimumSize: const Size(0, AppSpacing.buttonLg),
      ),
    ),

    // Floating Action Button
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: AppColors.textPrimaryDark,
      elevation: AppSpacing.elevationMd,
      shape: CircleBorder(),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceDark,
      contentPadding: AppSpacing.allLg,
      border: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: const BorderSide(color: AppColors.borderDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusMd,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textSecondaryDark,
      ),
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textDisabledDark,
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.primaryDark,
      selectedColor: AppColors.primaryLight,
      disabledColor: AppColors.textDisabledDark,
      labelStyle: AppTypography.labelSmall,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusSm),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerDark,
      thickness: 1,
      space: 1,
    ),

    // Bottom Sheet
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surfaceDark,
      elevation: AppSpacing.elevationXl,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusBottomSheet,
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surfaceDark,
      elevation: AppSpacing.elevationLg,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusXl),
      titleTextStyle: AppTypography.headlineMedium.copyWith(
        color: AppColors.textPrimaryDark,
      ),
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textSecondaryDark,
      ),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.cardDark,
      contentTextStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textPrimaryDark,
      ),
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      behavior: SnackBarBehavior.floating,
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      selectedItemColor: AppColors.primaryLight,
      unselectedItemColor: AppColors.textSecondaryDark,
      elevation: AppSpacing.elevationMd,
      type: BottomNavigationBarType.fixed,
    ),

    // Typography
    textTheme: AppTypography.textTheme.apply(
      bodyColor: AppColors.textPrimaryDark,
      displayColor: AppColors.textPrimaryDark,
    ),
  );
}
