import 'package:flutter/material.dart';

class AppTheme {
  // Dark Lavender Colors (matching web app)
  static const Color primaryBg = Color(0xFF171717); // Main background
  static const Color darkBg = Color(0xFF0f0a1a); // Darker variant
  static const Color sidebarBg = Color(0xFF1a0f2e); // Sidebar background
  static const Color headerBg = Color(0xFF1a0f2e); // Header background

  // Lavender Accents
  static const Color lavender600 = Color(0xFF9333ea); // Primary button
  static const Color lavender700 = Color(0xFF7e22ce); // Hover state
  static const Color lavender500 = Color(0xFFa78bfa); // Light highlights
  static const Color lavender300 = Color(0xFFddd6fe); // Text accents

  // Borders & Dividers
  static const Color borderDark = Color(0xFF3d2e5c); // Lavender-tinted border
  static const Color borderLight = Color(0xFF2d2d2d); // Light border

  // Text Colors
  static const Color textPrimary = Color(0xFFffffff); // White
  static const Color textSecondary = Color(0xFFe5e7eb); // Light gray
  static const Color textTertiary = Color(0xFF9ca3af); // Medium gray
  static const Color textHint = Color(0xFF6b7280); // Dark gray

  // Status Colors
  static const Color statusSuccess = Color(0xFF10b981); // Green
  static const Color statusWarning = Color(0xFFf59e0b); // Amber
  static const Color statusError = Color(0xFFef4444); // Red
  static const Color statusInfo = Color(0xFF3b82f6); // Blue

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: lavender600,
      scaffoldBackgroundColor: primaryBg,

      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: headerBg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: primaryBg,
        surfaceTintColor: borderDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderDark, width: 1),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primaryBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lavender600, width: 2),
        ),
        hintStyle: const TextStyle(color: textHint),
        labelStyle: const TextStyle(color: textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // Button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lavender600,
          foregroundColor: textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lavender600,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text themes
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textTertiary,
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),

      // List tile theme
      listTileTheme: ListTileThemeData(
        textColor: textPrimary,
        iconColor: lavender500,
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: const TextStyle(
          color: textTertiary,
          fontSize: 12,
        ),
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: borderDark,
        thickness: 1,
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: primaryBg,
        selectedColor: lavender600,
        disabledColor: textHint,
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: textPrimary),
        brightness: Brightness.dark,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderDark),
        ),
      ),
    );
  }
}
