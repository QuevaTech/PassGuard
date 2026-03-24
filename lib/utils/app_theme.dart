import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color secondaryColor = Color(0xFF1E293B);
  static const Color accentColor = Color(0xFFEAB308);
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color textColor = Color(0xFFFFFFFF);
  static const Color textSecondaryColor = Color(0xFF94A3B8);
  static const Color surfaceColor = Color(0xFF111827);
  static const Color borderColor = Color(0xFF374151);

  /// Predefined tag colors for entry color tagging.
  static const List<Color> entryTagColors = [
    Color(0xFFFF7B7B), // Coral Red
    Color(0xFF7BB8FF), // Sky Blue
    Color(0xFF8EC98E), // Sage Green
    Color(0xFFFFD97B), // Warm Yellow
    Color(0xFFB47BFF), // Soft Purple
    Color(0xFF5EC4C4), // Ocean Teal
  ];

  // Dynamic theme builders — accept accent color at runtime.
  // Used by main.dart so the whole app re-themes when the user picks a color.
  static ThemeData buildLightTheme(Color accent) => _lightTheme(accent);
  static ThemeData buildDarkTheme(Color accent) => _darkTheme(accent);

  // Returns black or white depending on which has better contrast against [accent].
  static Color _onAccent(Color accent) =>
      accent.computeLuminance() > 0.35 ? primaryColor : Colors.white;

  // Light Theme
  static final ThemeData lightTheme = _lightTheme(accentColor);
  static ThemeData _lightTheme(Color accent) => ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: primaryColor,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: primaryColor,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        color: Colors.black87,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        color: textSecondaryColor,
        height: 1.4,
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: accent,
      secondary: secondaryColor,
      surface: Colors.white,
      onPrimary: _onAccent(accent),
      onSecondary: Colors.white,
      onSurface: primaryColor,
      error: errorColor,
      onError: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondaryColor),
      hintStyle: const TextStyle(color: textSecondaryColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    iconTheme: const IconThemeData(
      color: primaryColor,
    ),
  );

  // Dark Theme
  static final ThemeData darkTheme = _darkTheme(accentColor);
  static ThemeData _darkTheme(Color accent) => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: primaryColor,
    cardColor: surfaceColor,
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: textColor,
        height: 1.2,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: textColor,
        height: 1.25,
        letterSpacing: -0.2,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        color: textColor,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        color: textSecondaryColor,
        height: 1.4,
      ),
    ),
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: secondaryColor,
      surface: surfaceColor,
      onPrimary: _onAccent(accent),
      onSecondary: Colors.white,
      onSurface: textColor,
      error: errorColor,
      onError: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondaryColor),
      hintStyle: const TextStyle(color: textSecondaryColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: accent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
    iconTheme: const IconThemeData(
      color: textColor,
    ),
  );
}