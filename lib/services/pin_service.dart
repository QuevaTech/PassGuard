import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinService {
  static const _keyPinHash = 'pin_hash';
  static const _keyPinEnabled = 'pin_enabled';

  static Future<bool> isPinEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(_keyPinEnabled) ?? false) &&
        prefs.containsKey(_keyPinHash);
  }

  static String _hash(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  static Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPinHash, _hash(pin));
    await prefs.setBool(_keyPinEnabled, true);
  }

  static Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPinHash);
    if (stored == null) return false;
    return stored == _hash(pin);
  }

  static Future<void> disablePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPinHash);
    await prefs.setBool(_keyPinEnabled, false);
  }
}
