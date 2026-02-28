import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

enum AccessibilityThemeType {
  standardDark,
  standardLight,
  highContrast,
  protanopia, // Red-blind
  deuteranopia, // Green-blind
  tritanopia, // Blue-blind
}

class AccessibilityTheme {
  /// Resolves the ThemeData based on the selected AccessibilityThemeType.
  static ThemeData getTheme(AccessibilityThemeType type) {
    switch (type) {
      case AccessibilityThemeType.standardLight:
        return AppTheme.lightTheme;
      case AccessibilityThemeType.highContrast:
        return _buildHighContrastTheme();
      case AccessibilityThemeType.protanopia:
        return _buildProtanopiaTheme();
      case AccessibilityThemeType.deuteranopia:
        return _buildDeuteranopiaTheme();
      case AccessibilityThemeType.tritanopia:
        return _buildTritanopiaTheme();
      case AccessibilityThemeType.standardDark:
      default:
        return AppTheme.darkTheme;
    }
  }

  // --- Theme Builders for Accessibility Modes --- //

  static ThemeData _buildHighContrastTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      primaryColor: const Color(0xFFFFFF00), // Highly visible yellow
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFFF00),
        secondary: Color(0xFF00FFFF), // Cyan for contrast
        surface: Colors.black,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        bodyMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      cardColor: const Color(0xFF1A1A1A),
      dividerColor: Colors.white.withOpacity(0.5),
    );
  }

  static ThemeData _buildProtanopiaTheme() {
    // Protanopia (Red-Blind): Use Blue and Yellow combos instead of Red/Green
    return AppTheme.darkTheme.copyWith(
      primaryColor: const Color(0xFF0055FF),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF0055FF),
        secondary: Color(0xFFFFD700), // Gold/Yellow
        error: Color(0xFF8B008B), // Dark magenta instead of red
        surface: Color(0xFF0B0E14),
      ),
    );
  }

  static ThemeData _buildDeuteranopiaTheme() {
    // Deuteranopia (Green-Blind): Similar to Protanopia, avoid relying on green.
    return AppTheme.darkTheme.copyWith(
      primaryColor: const Color(0xFF0066FF),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF0066FF),
        secondary: Color(0xFFFFCC00),
        error: Color(0xFF990099),
        surface: Color(0xFF0B0E14),
      ),
    );
  }

  static ThemeData _buildTritanopiaTheme() {
    // Tritanopia (Blue-Blind): Use Red and Cyan/Teal combos. Avoid Blue/Yellow.
    return AppTheme.darkTheme.copyWith(
      primaryColor: const Color(0xFFFF0055), // Red/Pink primary
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFF0055),
        secondary: Color(0xFF00FFFF), // Cyan
        error: Color(0xFFFF0000), // Red is still visible
        surface: Color(0xFF0B0E14),
      ),
    );
  }

  /// Provides a ColorFilter Matrix to apply globally across the ENTIRE APP (including images & hardcoded colors).
  /// These matrices provide a Daltonization effect (shifting indistinguishable colors so they can be seen).
  static ColorFilter? getColorFilter(AccessibilityThemeType type) {
    switch (type) {
      case AccessibilityThemeType.protanopia:
        // Protanopia daltonization-like shift (Boosts blues/greens for reds)
        return const ColorFilter.matrix([
          0.625, 0.375, 0.0,   0.0, 0.0,
          0.700, 0.300, 0.0,   0.0, 0.0,
          0.0,   0.300, 0.700, 0.0, 0.0,
          0.0,   0.0,   0.0,   1.0, 0.0,
        ]);
      case AccessibilityThemeType.deuteranopia:
        // Deuteranopia shift
        return const ColorFilter.matrix([
          0.80,  0.20,  0.0,   0.0, 0.0,
          0.258, 0.742, 0.0,   0.0, 0.0,
          0.0,   0.142, 0.858, 0.0, 0.0,
          0.0,   0.0,   0.0,   1.0, 0.0,
        ]);
      case AccessibilityThemeType.tritanopia:
        // Tritanopia shift (Boosts reds)
        return const ColorFilter.matrix([
          0.95,  0.05,  0.0,   0.0, 0.0,
          0.0,   0.433, 0.567, 0.0, 0.0,
          0.0,   0.475, 0.525, 0.0, 0.0,
          0.0,   0.0,   0.0,   1.0, 0.0,
        ]);
      case AccessibilityThemeType.standardDark:
      case AccessibilityThemeType.standardLight:
      case AccessibilityThemeType.highContrast:
      default:
        // No filter needed for non-colorblind modes
        return null;
    }
  }
}
