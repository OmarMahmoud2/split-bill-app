import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_bill_app/theme/app_colors.dart';
import 'package:split_bill_app/theme/app_palette.dart';
import 'package:split_bill_app/theme/app_spacing.dart';
import 'package:split_bill_app/theme/app_typography.dart';

/// Builds the app's [ThemeData] for light and dark mode from [AppPalette]
/// (v3 "Quiet ledger").
///
/// Every color here comes from the palette; change [AppPalette.light] /
/// [AppPalette.dark], not this file, to recolor the app. Shapes come from
/// [AppRadii]: pill buttons, 12-radius inputs with visible labels, hairline
/// cards, 28-radius sheets. Only sheets, dialogs and menus cast a shadow, and
/// only in light mode.
class AppTheme {
  AppTheme._(); // Private constructor

  static ThemeData get lightTheme => _build(AppPalette.light);

  static ThemeData get darkTheme => _build(AppPalette.dark);

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

  static ColorScheme _scheme(AppPalette p) => ColorScheme(
    brightness: p.brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.accentSoft,
    onPrimaryContainer: p.onAccentSoft,
    secondary: p.accent,
    onSecondary: p.onAccent,
    secondaryContainer: p.accentSoft,
    onSecondaryContainer: p.onAccentSoft,
    tertiary: p.owe,
    onTertiary: p.isDark ? p.background : Colors.white,
    tertiaryContainer: p.oweSoft,
    onTertiaryContainer: p.oweInk,
    error: p.error,
    onError: p.onError,
    errorContainer: p.errorSoft,
    onErrorContainer: p.isDark ? AppColors.errorStrongDark : p.dangerStrong,
    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceDim: p.background,
    surfaceBright: p.surface,
    surfaceContainerLowest: p.surface,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceVariant,
    surfaceContainerHighest: p.surfaceVariant,
    outline: p.borderStrong,
    outlineVariant: p.border,
    shadow: p.shadow,
    scrim: p.scrim,
    inverseSurface: p.inverseSurface,
    onInverseSurface: p.onInverseSurface,
    inversePrimary: p.isDark ? AppColors.tealLight : AppColors.tealDark,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(AppPalette p) {
    final scheme = _scheme(p);
    final hairline = BorderSide(color: p.border, width: AppRadii.hairline);
    // One soft shadow for floating layers, light mode only.
    final floatingElevation = p.isDark ? 0.0 : AppSpacing.elevationXl;
    final floatingShadow = p.shadow.withValues(alpha: 0.35);
    // In dark mode floating layers are lifted by a lighter tone instead.
    final floatingSurface = p.isDark ? p.surfaceVariant : p.surface;
    const pillPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xxl,
      vertical: AppSpacing.md,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadii.rowRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    final filledStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? p.surfaceVariant
            : p.inverseSurface,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled)
            ? p.textDisabled
            : p.onInverseSurface,
      ),
      overlayColor: WidgetStatePropertyAll(
        p.onInverseSurface.withValues(alpha: 0.08),
      ),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: const WidgetStatePropertyAll(AppRadii.pill),
      padding: const WidgetStatePropertyAll(pillPadding),
      minimumSize: const WidgetStatePropertyAll(Size(64, AppSpacing.buttonLg)),
      textStyle: WidgetStatePropertyAll(AppTypography.labelLarge),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      extensions: [p],
      fontFamily: AppTypography.bodyFamily,

      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.borderSubtle,
      shadowColor: p.shadow,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        systemOverlayStyle: overlayStyleFor(p.brightness),
        titleTextStyle: AppTypography.titleLarge.copyWith(color: p.textPrimary),
        iconTheme: IconThemeData(color: p.textPrimary, size: AppSpacing.iconLg),
        actionsIconTheme: IconThemeData(
          color: p.textPrimary,
          size: AppSpacing.iconLg,
        ),
      ),

      // Level 1: tonal surface + hairline, no shadow.
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: AppRadii.cardShape(p.border),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(style: filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: filledStyle),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          backgroundColor: p.surface,
          disabledForegroundColor: p.textDisabled,
          side: BorderSide(color: p.borderStrong),
          shape: AppRadii.pill,
          padding: pillPadding,
          minimumSize: const Size(64, AppSpacing.buttonLg),
          textStyle: AppTypography.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          disabledForegroundColor: p.textDisabled,
          shape: AppRadii.pill,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          minimumSize: const Size(44, 44),
          textStyle: AppTypography.labelMedium,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(44, 44),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.inverseSurface,
        foregroundColor: p.onInverseSurface,
        elevation: p.isDark ? 0 : AppSpacing.elevationSm,
        focusElevation: p.isDark ? 0 : AppSpacing.elevationSm,
        hoverElevation: p.isDark ? 0 : AppSpacing.elevationMd,
        highlightElevation: p.isDark ? 0 : AppSpacing.elevationMd,
        shape: const StadiumBorder(),
        extendedTextStyle: AppTypography.labelLarge,
      ),

      // 12-radius inputs with labels that stay visible above the field.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        border: inputBorder(p.border),
        enabledBorder: inputBorder(p.border),
        disabledBorder: inputBorder(p.borderSubtle),
        focusedBorder: inputBorder(p.primary, 2),
        errorBorder: inputBorder(p.error),
        focusedErrorBorder: inputBorder(p.error, 2),
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: p.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: AppTypography.bodyMedium.copyWith(
          color: p.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: AppTypography.bodyLarge.copyWith(color: p.textTertiary),
        helperStyle: AppTypography.bodySmall.copyWith(color: p.textSecondary),
        errorStyle: AppTypography.bodySmall.copyWith(color: p.error),
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.surface,
        selectedColor: p.accentSoft,
        disabledColor: p.surfaceVariant,
        checkmarkColor: p.onAccentSoft,
        side: BorderSide(color: p.borderStrong),
        labelStyle: AppTypography.titleSmall.copyWith(color: p.textPrimary),
        secondaryLabelStyle: AppTypography.titleSmall.copyWith(
          color: p.onAccentSoft,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.chipRadius),
      ),

      dividerTheme: DividerThemeData(
        color: p.borderSubtle,
        thickness: 1,
        space: 1,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        titleTextStyle: AppTypography.titleMedium.copyWith(
          color: p.textPrimary,
        ),
        subtitleTextStyle: AppTypography.bodySmall.copyWith(
          color: p.textSecondary,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rowRadius),
        minVerticalPadding: AppSpacing.md,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: floatingSurface,
        modalBackgroundColor: floatingSurface,
        surfaceTintColor: Colors.transparent,
        elevation: floatingElevation,
        modalElevation: floatingElevation,
        shadowColor: floatingShadow,
        modalBarrierColor: p.scrim,
        dragHandleColor: p.borderStrong,
        dragHandleSize: const Size(36, 5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetRadius),
        clipBehavior: Clip.antiAlias,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: floatingSurface,
        surfaceTintColor: Colors.transparent,
        elevation: floatingElevation,
        shadowColor: floatingShadow,
        barrierColor: p.scrim,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        titleTextStyle: AppTypography.headlineMedium.copyWith(
          color: p.textPrimary,
        ),
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: p.textSecondary,
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: floatingSurface,
        surfaceTintColor: Colors.transparent,
        elevation: floatingElevation,
        shadowColor: floatingShadow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.rowRadius,
          side: hairline,
        ),
        textStyle: AppTypography.bodyLarge.copyWith(color: p.textPrimary),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.inverseSurface,
        contentTextStyle: AppTypography.bodyMedium.copyWith(
          color: p.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: p.isDark ? AppColors.tealLight : AppColors.tealDark,
        closeIconColor: p.onInverseSurface,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rowRadius),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorColor: p.accentSoft,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: AppSpacing.iconLg,
            color: s.contains(WidgetState.selected)
                ? p.onAccentSoft
                : p.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppTypography.labelSmall.copyWith(
            color: s.contains(WidgetState.selected)
                ? p.textPrimary
                : p.textSecondary,
          ),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.textPrimary,
        unselectedItemColor: p.textSecondary,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textSecondary,
        indicatorColor: p.primary,
        dividerColor: p.borderSubtle,
        labelStyle: AppTypography.labelMedium,
        unselectedLabelStyle: AppTypography.labelMedium,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? (p.isDark ? p.background : Colors.white)
              : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? p.primary : p.surfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.transparent
              : p.borderStrong,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : null,
        ),
        checkColor: WidgetStatePropertyAll(p.onPrimary),
        side: BorderSide(color: p.borderStrong, width: 2),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.chipRadius),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? p.textPrimary : p.borderStrong,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.borderSubtle,
        circularTrackColor: Colors.transparent,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.inverseSurface,
          borderRadius: AppRadii.chipRadius,
        ),
        textStyle: AppTypography.bodySmall.copyWith(color: p.onInverseSurface),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.primary,
        selectionColor: p.primary.withValues(alpha: 0.25),
        selectionHandleColor: p.primary,
      ),

      textTheme: AppTypography.textTheme.apply(
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
    );
  }
}
