import 'dart:math';
import 'package:flutter/material.dart';

class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  // Background
  final List<Color> backgroundGradientColors;
  final List<double> backgroundGradientStops;
  final bool isRadialGradient;
  final Alignment gradientCenter;
  final bool hasAuroraRibbons;

  // Card surface
  final Color cardBackground;
  final Color cardBorderColor;
  final double cardBlur;
  final double cardRadius;

  // Brand accents
  final Color primaryAccent;
  final Color secondaryAccent;
  final LinearGradient ctaGradient;
  final List<Color> ctaGlowColors;

  // Text colours
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Typography personality
  final FontWeight displayFontWeight;
  final double displayLetterSpacing;

  // Behaviour flags
  final bool isFlat;
  final bool isCipher;

  // Semantic palettes
  final List<Color> strengthColors;
  final Map<String, Color> categoryColors;

  const AppThemeExtension({
    required this.backgroundGradientColors,
    required this.backgroundGradientStops,
    required this.isRadialGradient,
    required this.gradientCenter,
    required this.hasAuroraRibbons,
    required this.cardBackground,
    required this.cardBorderColor,
    required this.cardBlur,
    required this.cardRadius,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.ctaGradient,
    required this.ctaGlowColors,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.displayFontWeight,
    required this.displayLetterSpacing,
    required this.isFlat,
    required this.isCipher,
    required this.strengthColors,
    required this.categoryColors,
  });

  @override
  AppThemeExtension copyWith({
    List<Color>? backgroundGradientColors,
    List<double>? backgroundGradientStops,
    bool? isRadialGradient,
    Alignment? gradientCenter,
    bool? hasAuroraRibbons,
    Color? cardBackground,
    Color? cardBorderColor,
    double? cardBlur,
    double? cardRadius,
    Color? primaryAccent,
    Color? secondaryAccent,
    LinearGradient? ctaGradient,
    List<Color>? ctaGlowColors,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    FontWeight? displayFontWeight,
    double? displayLetterSpacing,
    bool? isFlat,
    bool? isCipher,
    List<Color>? strengthColors,
    Map<String, Color>? categoryColors,
  }) {
    return AppThemeExtension(
      backgroundGradientColors:
          backgroundGradientColors ?? this.backgroundGradientColors,
      backgroundGradientStops:
          backgroundGradientStops ?? this.backgroundGradientStops,
      isRadialGradient: isRadialGradient ?? this.isRadialGradient,
      gradientCenter: gradientCenter ?? this.gradientCenter,
      hasAuroraRibbons: hasAuroraRibbons ?? this.hasAuroraRibbons,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorderColor: cardBorderColor ?? this.cardBorderColor,
      cardBlur: cardBlur ?? this.cardBlur,
      cardRadius: cardRadius ?? this.cardRadius,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      ctaGradient: ctaGradient ?? this.ctaGradient,
      ctaGlowColors: ctaGlowColors ?? this.ctaGlowColors,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      displayFontWeight: displayFontWeight ?? this.displayFontWeight,
      displayLetterSpacing: displayLetterSpacing ?? this.displayLetterSpacing,
      isFlat: isFlat ?? this.isFlat,
      isCipher: isCipher ?? this.isCipher,
      strengthColors: strengthColors ?? this.strengthColors,
      categoryColors: categoryColors ?? this.categoryColors,
    );
  }

  @override
  AppThemeExtension lerp(ThemeExtension<AppThemeExtension>? other, double t) {
    if (other is! AppThemeExtension) return this;
    return AppThemeExtension(
      backgroundGradientColors: _lerpColorList(
          backgroundGradientColors, other.backgroundGradientColors, t),
      backgroundGradientStops: _lerpDoubleList(
          backgroundGradientStops, other.backgroundGradientStops, t),
      isRadialGradient: t < 0.5 ? isRadialGradient : other.isRadialGradient,
      gradientCenter:
          Alignment.lerp(gradientCenter, other.gradientCenter, t) ??
              gradientCenter,
      hasAuroraRibbons:
          t < 0.5 ? hasAuroraRibbons : other.hasAuroraRibbons,
      cardBackground:
          Color.lerp(cardBackground, other.cardBackground, t) ?? cardBackground,
      cardBorderColor:
          Color.lerp(cardBorderColor, other.cardBorderColor, t) ??
              cardBorderColor,
      cardBlur: _lerpDouble(cardBlur, other.cardBlur, t),
      cardRadius: _lerpDouble(cardRadius, other.cardRadius, t),
      primaryAccent:
          Color.lerp(primaryAccent, other.primaryAccent, t) ?? primaryAccent,
      secondaryAccent:
          Color.lerp(secondaryAccent, other.secondaryAccent, t) ??
              secondaryAccent,
      ctaGradient: t < 0.5 ? ctaGradient : other.ctaGradient,
      ctaGlowColors:
          _lerpColorList(ctaGlowColors, other.ctaGlowColors, t),
      textPrimary:
          Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary:
          Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      displayFontWeight:
          t < 0.5 ? displayFontWeight : other.displayFontWeight,
      displayLetterSpacing:
          _lerpDouble(displayLetterSpacing, other.displayLetterSpacing, t),
      isFlat: t < 0.5 ? isFlat : other.isFlat,
      isCipher: t < 0.5 ? isCipher : other.isCipher,
      strengthColors:
          _lerpColorList(strengthColors, other.strengthColors, t),
      categoryColors: t < 0.5 ? categoryColors : other.categoryColors,
    );
  }

  static List<Color> _lerpColorList(
      List<Color> a, List<Color> b, double t) {
    final len = min(a.length, b.length);
    return List.generate(len, (i) => Color.lerp(a[i], b[i], t)!);
  }

  static List<double> _lerpDoubleList(
      List<double> a, List<double> b, double t) {
    final len = min(a.length, b.length);
    return List.generate(len, (i) => _lerpDouble(a[i], b[i], t));
  }

  static double _lerpDouble(double a, double b, double t) =>
      a + (b - a) * t;
}
