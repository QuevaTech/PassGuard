import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'pg_theme_mode';
const _kAccentKey = 'pg_accent_color';

/// Preset accent colors shown as round swatches in Settings.
const accentColors = [
  Color(0xFFEAB308), // Gold   (default)
  Color(0xFF6366F1), // Indigo
  Color(0xFF10B981), // Emerald
  Color(0xFFF43F5E), // Rose
  Color(0xFF0EA5E9), // Sky
];

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kThemeKey);
    state = _fromString(saved);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, _toString(mode));
  }

  static ThemeMode _fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final notifier = ThemeNotifier();
  notifier.load();
  return notifier;
});

class AccentColorNotifier extends StateNotifier<Color> {
  AccentColorNotifier() : super(accentColors[0]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getInt(_kAccentKey);
    if (value != null) {
      state = Color(value);
    }
  }

  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAccentKey, color.toARGB32());
  }
}

final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, Color>((ref) {
  final notifier = AccentColorNotifier();
  notifier.load();
  return notifier;
});
