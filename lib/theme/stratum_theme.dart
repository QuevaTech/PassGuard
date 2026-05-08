import 'package:flutter/material.dart';
import 'app_theme_extension.dart';

class StratumTheme {
  static const _gold  = Color(0xFFD4B038);
  static const _ember = Color(0xFFD87E37);

  static const _darkBg0 = Color(0xFF14172e);
  static const _darkBg1 = Color(0xFF1b1f3b);

  static const _darkSurface = Color(0xFF1E2240);
  static const _darkCard    = Color(0xFF232849);

  static const _lightBg0 = Color(0xFFfaf5e8);
  static const _lightBg1 = Color(0xFFefe6d2);

  static const _lightSurface = Color(0xFFF5EFE3);
  static const _lightCard    = Colors.white;

  static const _darkText1 = Color(0xFFf4ecdb);
  static const _darkText2 = Color(0xFFc9c4b8);
  static const _darkText3 = Color(0xFF8e8a7e);

  static const _lightText1 = Color(0xFF1b1f3b);
  static const _lightText2 = Color(0xFF4a4f6b);
  static const _lightText3 = Color(0xFF8a8fa6);

  static const _strengthColors = [
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF84CC16),
    Color(0xFF22C55E),
  ];

  static const _categoryColors = {
    'personal': _gold,
    'work': _ember,
    'banking': Color(0xFF16a34a),
    'social': Color(0xFF7c3aed),
    'shopping': Color(0xFF06b6d4),
    'other': Color(0xFF94a3b8),
  };

  /// [accent] is the user-selected accent color; defaults to gold.
  static ThemeData build(Brightness brightness, {Color accent = _gold}) {
    final isDark = brightness == Brightness.dark;
    final onAccent = accent.computeLuminance() > 0.35 ? _darkBg1 : Colors.white;

    final ext = isDark
        ? _darkExtension.copyWith(primaryAccent: accent)
        : _lightExtension.copyWith(primaryAccent: accent);

    return ThemeData(
      brightness: brightness,
      primaryColor: _darkBg1,
      scaffoldBackgroundColor: Colors.transparent,
      cardColor: isDark ? _darkCard : _lightCard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? _darkText1 : _lightText1,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: isDark ? _darkText1 : _lightText1),
        actionsIconTheme: IconThemeData(color: isDark ? _darkText1 : _lightText1),
        titleTextStyle: TextStyle(
          color: isDark ? _darkText1 : _lightText1,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.025 * 18,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: isDark ? _darkText1 : _lightText1,
          letterSpacing: -0.025 * 34,
          height: 0.95,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: isDark ? _darkText1 : _lightText1,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? _darkText1 : _lightText1,
          height: 1.25,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? _darkText1 : _lightText1,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? _darkText2 : _lightText2,
          height: 1.4,
          letterSpacing: 0.04,
        ),
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: onAccent,
        secondary: _ember,
        onSecondary: _darkBg1,
        surface: isDark ? _darkSurface : _lightSurface,
        onSurface: isDark ? _darkText1 : _lightText1,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surfaceContainerHighest: isDark ? _darkCard : _lightCard,
        surfaceContainerHigh: isDark ? _darkCard : _lightCard,
        surfaceContainer: isDark ? _darkSurface : _lightSurface,
      ),
      cardTheme: CardThemeData(
        color: isDark ? _darkCard : _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark
                ? _gold.withValues(alpha: 0.18)
                : _darkBg1.withValues(alpha: 0.10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkCard : _lightCard,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
              color: isDark ? _gold.withValues(alpha: 0.20) : _darkBg1.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
              color: isDark ? _gold.withValues(alpha: 0.16) : _darkBg1.withValues(alpha: 0.10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        labelStyle: TextStyle(color: isDark ? _darkText2 : _lightText2),
        hintStyle:  TextStyle(color: isDark ? _darkText3 : _lightText3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? _darkCard : accent,
          foregroundColor: isDark ? _darkText1 : onAccent,
          side: isDark ? BorderSide(color: accent) : BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        ),
      ),
      iconTheme: IconThemeData(color: isDark ? _darkText1 : _lightText1),
      extensions: [ext],
    );
  }

  static const _darkExtension = AppThemeExtension(
    backgroundGradientColors: [_darkBg0, _darkBg1],
    backgroundGradientStops: [0.0, 1.0],
    isRadialGradient: false,
    gradientCenter: Alignment.topCenter,
    hasAuroraRibbons: false,
    cardBackground: _darkCard,
    cardBorderColor: Color(0x29D4B038),
    cardBlur: 0.0,
    cardRadius: 14.0,
    primaryAccent: _gold,
    secondaryAccent: _ember,
    ctaGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1b1f3b), Color(0xFF2a2f54)],
    ),
    ctaGlowColors: [Color(0x40D4B038)],
    textPrimary: _darkText1,
    textSecondary: _darkText2,
    textTertiary: _darkText3,
    displayFontWeight: FontWeight.w800,
    displayLetterSpacing: -0.025,
    isFlat: true,
    isCipher: false,
    strengthColors: _strengthColors,
    categoryColors: _categoryColors,
  );

  static const _lightExtension = AppThemeExtension(
    backgroundGradientColors: [_lightBg0, _lightBg1],
    backgroundGradientStops: [0.0, 1.0],
    isRadialGradient: false,
    gradientCenter: Alignment.topCenter,
    hasAuroraRibbons: false,
    cardBackground: _lightCard,
    cardBorderColor: Color(0x1A1b1f3b),
    cardBlur: 0.0,
    cardRadius: 14.0,
    primaryAccent: _gold,
    secondaryAccent: _ember,
    ctaGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_gold, _ember],
    ),
    ctaGlowColors: [Color(0x40D4B038)],
    textPrimary: _lightText1,
    textSecondary: _lightText2,
    textTertiary: _lightText3,
    displayFontWeight: FontWeight.w800,
    displayLetterSpacing: -0.025,
    isFlat: true,
    isCipher: false,
    strengthColors: _strengthColors,
    categoryColors: _categoryColors,
  );
}
