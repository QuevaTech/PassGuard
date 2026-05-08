import 'package:flutter/material.dart';
import 'app_theme_extension.dart';

class AuroraRibbon {
  final Color color;
  final double topFraction;
  final double widthFraction;
  final double blurRadius;

  const AuroraRibbon({
    required this.color,
    required this.topFraction,
    required this.widthFraction,
    this.blurRadius = 80.0,
  });
}

class CipherTheme {
  static const _cyan    = Color(0xFF00E5FF);
  static const _magenta = Color(0xFFFF2EB4);
  static const _auroraGreen = Color(0xFF39FF96);

  static const _darkBg0 = Color(0xFF1a1f4a);
  static const _darkBg1 = Color(0xFF0a0e27);
  static const _darkBg2 = Color(0xFF050714);

  static const _darkSurface = Color(0xFF0D1336);
  static const _darkCard    = Color(0xFF111640);

  static const _lightBg0 = Color(0xFFf0f4ff);
  static const _lightBg1 = Color(0xFFfafbff);
  static const _lightBg2 = Color(0xFFf5f7fc);

  static const _lightSurface = Color(0xFFF0F4FF);
  static const _lightCard    = Colors.white;

  static const _darkText1 = Color(0xFFe8f4ff);
  static const _darkText2 = Color(0xFF8b9bbf);
  static const _darkText3 = Color(0xFF5b6488);

  static const _lightText1 = Color(0xFF0a0e27);
  static const _lightText2 = Color(0xFF3d4566);
  static const _lightText3 = Color(0xFF7c8299);

  static const _strengthColors = [
    Color(0xFFFF2E4D),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFF39FF96),
    Color(0xFF00E5FF),
  ];

  static const _categoryColors = {
    'personal': _cyan,
    'work': _magenta,
    'banking': _auroraGreen,
    'social': Color(0xFFF5D72B),
    'shopping': Color(0xFFA78BFA),
    'other': Color(0xFF8B9BBF),
  };

  static const auroraRibbons = [
    AuroraRibbon(color: Color(0x2E00E5FF), topFraction: 0.05, widthFraction: 0.75),
    AuroraRibbon(color: Color(0x23FF2EB4), topFraction: 0.22, widthFraction: 0.55),
    AuroraRibbon(color: Color(0x1A39FF96), topFraction: 0.42, widthFraction: 0.65),
  ];

  // Cipher accent is always fixed (cyan/magenta — not user-customisable).
  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final ext = isDark ? _darkExtension : _lightExtension;

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
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w600,
          color: isDark ? _darkText1 : _lightText1,
          letterSpacing: -0.5,
          height: 1.05,
        ),
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: isDark ? _darkText1 : _lightText1,
          height: 1.2,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? _darkText1 : _lightText1,
          height: 1.25,
          letterSpacing: -0.2,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          color: isDark ? _darkText1 : _lightText1,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDark ? _darkText2 : _lightText2,
          height: 1.4,
          letterSpacing: 0.16,
        ),
      ),
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: _cyan,
        onPrimary: _darkBg1,
        secondary: _magenta,
        onSecondary: _darkBg1,
        surface: isDark ? _darkSurface : _lightSurface,
        onSurface: isDark ? _darkText1 : _lightText1,
        error: const Color(0xFFFF2E4D),
        onError: Colors.white,
        surfaceContainerHighest: isDark ? _darkCard : _lightCard,
        surfaceContainerHigh: isDark ? _darkCard : _lightCard,
        surfaceContainer: isDark ? _darkSurface : _lightSurface,
      ),
      cardTheme: CardThemeData(
        color: isDark ? _darkCard : _lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? _cyan.withValues(alpha: 0.25)
                : _darkBg1.withValues(alpha: 0.08),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkCard : _lightCard,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
              color: isDark ? const Color(0x268B9BBF) : const Color(0x1A0a0e27)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(
              color: isDark ? const Color(0x268B9BBF) : const Color(0x1A0a0e27)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: _cyan, width: 2),
        ),
        labelStyle: TextStyle(color: isDark ? _darkText2 : _lightText2),
        hintStyle:  TextStyle(color: isDark ? _darkText3 : _lightText3),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _cyan,
          foregroundColor: _darkBg1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _cyan,
          side: const BorderSide(color: _cyan),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
        ),
      ),
      iconTheme: IconThemeData(color: isDark ? _darkText1 : _lightText1),
      extensions: [ext],
    );
  }

  static const _darkExtension = AppThemeExtension(
    backgroundGradientColors: [_darkBg0, _darkBg1, _darkBg2],
    backgroundGradientStops: [0.0, 0.50, 1.0],
    isRadialGradient: true,
    gradientCenter: Alignment(-0.4, -1.0),
    hasAuroraRibbons: true,
    cardBackground: Color(0x1A111640),
    cardBorderColor: Color(0x4000E5FF),
    cardBlur: 20.0,
    cardRadius: 12.0,
    primaryAccent: _cyan,
    secondaryAccent: _magenta,
    ctaGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_cyan, _magenta],
    ),
    ctaGlowColors: [Color(0x7300E5FF), Color(0x40FF2EB4)],
    textPrimary: _darkText1,
    textSecondary: _darkText2,
    textTertiary: _darkText3,
    displayFontWeight: FontWeight.w600,
    displayLetterSpacing: -0.015,
    isFlat: false,
    isCipher: true,
    strengthColors: _strengthColors,
    categoryColors: _categoryColors,
  );

  static const _lightExtension = AppThemeExtension(
    backgroundGradientColors: [_lightBg0, _lightBg1, _lightBg2],
    backgroundGradientStops: [0.0, 0.60, 1.0],
    isRadialGradient: true,
    gradientCenter: Alignment(-0.4, -1.0),
    hasAuroraRibbons: false,
    cardBackground: Color(0xCCFFFFFF),
    cardBorderColor: Color(0x1A0a0e27),
    cardBlur: 20.0,
    cardRadius: 12.0,
    primaryAccent: _cyan,
    secondaryAccent: _magenta,
    ctaGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_cyan, _magenta],
    ),
    ctaGlowColors: [Color(0x4000E5FF)],
    textPrimary: _lightText1,
    textSecondary: _lightText2,
    textTertiary: _lightText3,
    displayFontWeight: FontWeight.w600,
    displayLetterSpacing: -0.015,
    isFlat: false,
    isCipher: true,
    strengthColors: _strengthColors,
    categoryColors: _categoryColors,
  );
}
