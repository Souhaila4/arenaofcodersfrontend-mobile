import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF00C2FF);
  static const Color primaryDark = Color(0xFF009ACD);

  // Backgrounds
  static const Color backgroundDark = Color(0xFF0B0E14);
  static const Color surfaceDark = Color(0xFF151B26);
  static const Color backgroundLight = Color(0xFFF3F4F6);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Accents
  static const Color accentOrange = Color(0xFFFF6B00);
  static const Color accentCyan = Color(0xFF00F0FF);

  // Brand splash
  static const Color brandDark = Color(0xFF0B1121);
  static const Color brandBlue = Color(0xFF1E40AF);

  // Card
  static const Color cardDark = Color(0xFF1E293B);

  // Text
  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFF94A3B8);
  static const Color textLightPrimary = Color(0xFF0F172A);
  static const Color textLightSecondary = Color(0xFF64748B);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accentOrange,
        surface: AppColors.surfaceDark,
        onPrimary: Colors.white,
        onSurface: AppColors.textDarkPrimary,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.primary,
        ),
        iconTheme: IconThemeData(color: AppColors.textDarkSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withAlpha(13)),
        ),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w900,
          fontSize: 28,
          color: Colors.white,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: Colors.white,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.white,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textDarkPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: AppColors.textDarkSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: AppColors.textDarkSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.textDarkSecondary,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accentOrange,
        surface: AppColors.surfaceLight,
        onPrimary: Colors.white,
        onSurface: AppColors.textLightPrimary,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: AppColors.primary,
        ),
        iconTheme: IconThemeData(color: AppColors.textLightSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        elevation: 0,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w900,
          fontSize: 28,
          color: AppColors.textLightPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: AppColors.textLightPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppColors.textLightPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: AppColors.textLightPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: AppColors.textLightPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: AppColors.textLightSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: AppColors.textLightSecondary,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.textLightSecondary,
        ),
      ),
    );
  }
}
