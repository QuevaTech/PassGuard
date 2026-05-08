import 'package:flutter/material.dart';
import '../theme/app_theme_style.dart';
import '../theme/vault_theme.dart';
import '../theme/stratum_theme.dart';
import '../theme/cipher_theme.dart';

class AppTheme {
  // ---------------------------------------------------------------------------
  // New API — dispatch by style + brightness + optional accent colour
  // ---------------------------------------------------------------------------

  static ThemeData buildTheme(
    AppThemeStyle style,
    Brightness brightness, {
    Color accent = const Color(0xFFEAB308),
  }) {
    switch (style) {
      case AppThemeStyle.vault:
        return VaultTheme.build(brightness, accent: accent);
      case AppThemeStyle.stratum:
        return StratumTheme.build(brightness, accent: accent);
      case AppThemeStyle.cipher:
        // Cipher has its own fixed palette — accent is ignored
        return CipherTheme.build(brightness);
    }
  }

  // ---------------------------------------------------------------------------
  // Legacy constants — kept so screens that still reference them compile.
  // ---------------------------------------------------------------------------

  static const Color primaryColor      = Color(0xFF0F172A);
  static const Color secondaryColor    = Color(0xFF1E293B);
  static const Color accentColor       = Color(0xFFEAB308);
  static const Color successColor      = Color(0xFF10B981);
  static const Color warningColor      = Color(0xFFF59E0B);
  static const Color errorColor        = Color(0xFFEF4444);
  static const Color textColor         = Color(0xFFFFFFFF);
  static const Color textSecondaryColor = Color(0xFF94A3B8);
  static const Color surfaceColor      = Color(0xFF111827);
  static const Color borderColor       = Color(0xFF374151);

  static const List<Color> entryTagColors = [
    Color(0xFFFF7B7B),
    Color(0xFF7BB8FF),
    Color(0xFF8EC98E),
    Color(0xFFFFD97B),
    Color(0xFFB47BFF),
    Color(0xFF5EC4C4),
  ];

  // Legacy — kept for backward compat; new code uses buildTheme(style, brightness).
  static ThemeData buildLightTheme(Color accent) =>
      VaultTheme.build(Brightness.light, accent: accent);
  static ThemeData buildDarkTheme(Color accent) =>
      VaultTheme.build(Brightness.dark, accent: accent);
}
