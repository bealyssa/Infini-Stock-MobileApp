import 'package:flutter/material.dart';

class AppTheme {
  // Dark Lavender Palette
  static const Color bgDark = Color(0xFF171717);
  static const Color bgDarker = Color(0xFF0F0A1A);
  static const Color bgLavender = Color(0xFF1A0F2E);
  
  static const Color lavender600 = Color(0xFF9333EA);
  static const Color lavender500 = Color(0xFFA78BFA);
  static const Color lavender400 = Color(0xFFC4B5FD);
  static const Color lavender300 = Color(0xFFDDD6FE);
  static const Color lavender950 = Color(0xFF581C87);
  
  static const Color borderLavender = Color(0xFF3D2E5C);
  static const Color borderDarker = Color(0xFF2D1F4A);
  
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textGray = Color(0xFFE5E7EB);
  static const Color textGraySecondary = Color(0xFF9CA3AF);
  static const Color textGrayTertiary = Color(0xFF6B7280);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: lavender600,
      appBarTheme: const AppBarTheme(
        backgroundColor: bgLavender,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: lavender600,
        secondary: lavender500,
        surface: bgDark,
        surfaceContainer: bgDarker,
        error: Colors.red,
        onPrimary: textWhite,
        onSecondary: textWhite,
        onSurface: textWhite,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textWhite,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textWhite,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textWhite,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        titleMedium: TextStyle(
          color: textWhite,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textGray,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textGraySecondary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textGrayTertiary,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: textGraySecondary,
          fontSize: 12,
        ),
      ),
      cardTheme: CardThemeData(
        color: bgDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLavender, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderLavender),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderLavender),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lavender600, width: 2),
        ),
        hintStyle: const TextStyle(color: textGrayTertiary),
        labelStyle: const TextStyle(color: textGraySecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lavender600,
          foregroundColor: textWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: borderLavender),
          foregroundColor: lavender400,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lavender400,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: borderDarker,
        deleteIconColor: textGraySecondary,
        disabledColor: borderLavender,
        selectedColor: lavender600,
        labelStyle: const TextStyle(color: textWhite),
        side: const BorderSide(color: lavender600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
