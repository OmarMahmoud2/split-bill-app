import 'package:flutter/material.dart';

/// Modern color palette for Split Bill app
/// Teal/Cyan primary for trust and clarity, Coral/Orange for warmth and action
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // ==================== PRIMARY COLORS ====================

  /// Main brand color - Teal/Cyan gradient
  static const Color primary = Color(0xFF00ACC1); // Cyan 600
  static const Color primaryDark = Color(0xFF00838F); // Cyan 800
  static const Color primaryLight = Color(0xFF4DD0E1); // Cyan 300

  /// Gradient for headers and featured sections
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ==================== SECONDARY COLORS ====================

  /// Accent color - Coral/Orange for CTAs and highlights
  static const Color secondary = Color(0xFFFF7043); // Deep Orange 400
  static const Color secondaryDark = Color(0xFFE64A19); // Deep Orange 700
  static const Color secondaryLight = Color(0xFFFFAB91); // Deep Orange 200

  // ==================== SEMANTIC COLORS ====================

  /// Success states - Emerald green
  static const Color success = Color(0xFF26A69A); // Teal 400
  static const Color successLight = Color(0xFF80CBC4); // Teal 200
  static const Color successDark = Color(0xFF00897B); // Teal 600

  /// Error states - Soft red
  static const Color error = Color(0xFFEF5350); // Red 400
  static const Color errorLight = Color(0xFFFFCDD2); // Red 100
  static const Color errorDark = Color(0xFFC62828); // Red 800

  /// Warning states - Amber
  static const Color warning = Color(0xFFFFCA28); // Amber 600
  static const Color warningLight = Color(0xFFFFE082); // Amber 200

  /// Info states - Blue
  static const Color info = Color(0xFF42A5F5); // Blue 400
  static const Color infoLight = Color(0xFF90CAF9); // Blue 200

  // ==================== NEUTRAL COLORS (LIGHT MODE) ====================

  static const Color backgroundLight = Color(
    0xFFF5F7FA,
  ); // Very light blue-gray
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure white
  static const Color cardLight = Color(0xFFFFFFFF); // White cards

  static const Color textPrimaryLight = Color(0xFF212121); // Almost black
  static const Color textSecondaryLight = Color(0xFF757575); // Gray 600
  static const Color textDisabledLight = Color(0xFFBDBDBD); // Gray 400

  static const Color dividerLight = Color(0xFFE0E0E0); // Gray 300
  static const Color borderLight = Color(0xFFE0E0E0); // Gray 300

  /// Overlay colors
  static const Color overlayLight = Color(0x14000000); // 8% black
  static const Color shadowLight = Color(0x1F000000); // 12% black

  // ==================== NEUTRAL COLORS (DARK MODE) ====================

  static const Color backgroundDark = Color(0xFF121212); // True dark
  static const Color surfaceDark = Color(0xFF1E1E1E); // Dark gray
  static const Color cardDark = Color(0xFF2C2C2C); // Lighter dark gray

  static const Color textPrimaryDark = Color(0xFFFFFFFF); // White
  static const Color textSecondaryDark = Color(0xFFB0B0B0); // Light gray
  static const Color textDisabledDark = Color(0xFF707070); // Medium gray

  static const Color dividerDark = Color(0xFF404040); // Dark gray
  static const Color borderDark = Color(0xFF404040); // Dark gray

  /// Overlay colors
  static const Color overlayDark = Color(0x14FFFFFF); // 8% white
  static const Color shadowDark = Color(0x3D000000); // 24% black

  // ==================== BILL STATUS COLORS ====================

  /// For "You Owe" indicators
  static const Color owingRed = Color(0xFFFF5252); // Red Accent

  /// For "Owed to You" indicators
  static const Color owedGreen = Color(0xFF69F0AE); // Green Accent

  /// For pending/review states
  static const Color pending = warning;

  /// For paid/settled states
  static const Color settled = success;

  // ==================== PARTICIPANT COLORS ====================

  /// Colorful palette for participant avatars/chips
  static const List<Color> participantColors = [
    Color(0xFF42A5F5), // Blue
    Color(0xFFAB47BC), // Purple
    Color(0xFF26A69A), // Teal
    Color(0xFFFF7043), // Deep Orange
    Color(0xFF66BB6A), // Green
    Color(0xFFEC407A), // Pink
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFFFCA28), // Amber
    Color(0xFF26C6DA), // Cyan
    Color(0xFF9CCC65), // Light Green
  ];
}
