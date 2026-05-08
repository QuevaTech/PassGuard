import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_style.dart';

const _kThemeKey      = 'pg_theme_mode';
const _kAccentKey     = 'pg_accent_color';
const _kThemeStyleKey = 'pg_theme_style';

// ---------------------------------------------------------------------------
// ThemeMode provider (dark / light / system)
// ---------------------------------------------------------------------------

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = _fromString(prefs.getString(_kThemeKey));
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, _toString(mode));
  }

  static ThemeMode _fromString(String? v) {
    switch (v) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      default:      return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:  return 'light';
      case ThemeMode.dark:   return 'dark';
      case ThemeMode.system: return 'system';
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final n = ThemeNotifier()..load();
  return n;
});

// ---------------------------------------------------------------------------
// AppThemeStyle provider (vault / stratum / cipher)
// ---------------------------------------------------------------------------

class AppThemeStyleNotifier extends StateNotifier<AppThemeStyle> {
  AppThemeStyleNotifier() : super(AppThemeStyle.vault);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppThemeStyleX.fromKey(prefs.getString(_kThemeStyleKey));
  }

  Future<void> setStyle(AppThemeStyle style) async {
    state = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeStyleKey, style.persistKey);
  }
}

final appThemeStyleProvider =
    StateNotifierProvider<AppThemeStyleNotifier, AppThemeStyle>((ref) {
  final n = AppThemeStyleNotifier()..load();
  return n;
});

// ---------------------------------------------------------------------------
// Accent colour provider (5 preset swatches — user's favourite feature)
// ---------------------------------------------------------------------------

/// Preset accent colours shown in Settings.
/// Cipher theme ignores this; Vault & Stratum use it.
const accentColors = [
  Color(0xFFEAB308), // Gold   (default)
  Color(0xFF6366F1), // Indigo
  Color(0xFF10B981), // Emerald
  Color(0xFFF43F5E), // Rose
  Color(0xFF0EA5E9), // Sky
];

class AccentColorNotifier extends StateNotifier<Color> {
  AccentColorNotifier() : super(accentColors[0]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kAccentKey);
    if (v != null) state = Color(v);
  }

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentKey, color.toARGB32());
  }
}

final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, Color>((ref) {
  final n = AccentColorNotifier()..load();
  return n;
});
