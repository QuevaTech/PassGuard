import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionService {
  static const Duration _defaultTimeout = Duration(minutes: 5);
  static const Duration _biometricTimeout = Duration(minutes: 10);
  static const Duration _absoluteTimeout = Duration(hours: 4);

  // Keychain key — stores base64-encoded derived key bytes (NOT the password)
  static const _keyCredKey = 'pg_vault_session_key_v2';

  // kReleaseMode uses the Data Protection Keychain (requires App Sandbox + signing).
  // Debug/Profile builds fall back to the legacy keychain to avoid -34018.
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: kReleaseMode),
  );

  static Timer? _sessionTimer;
  static DateTime? _lastActivity;
  static DateTime? _sessionStartedAt;
  static bool _isLocked = false;
  static bool _biometricEnabled = false;
  static Duration _sessionTimeout = _defaultTimeout;

  // Derived key bytes — never the master password string
  static Uint8List? _sessionKey;

  static final List<VoidCallback> _listeners = [];

  /// Store the derived session key in memory and Keychain.
  /// The master password is NOT stored — only the Argon2id-derived key bytes.
  static Future<void> setSessionKey(Uint8List key) async {
    _sessionKey = Uint8List.fromList(key);
    try {
      await _secureStorage.write(
        key: _keyCredKey,
        value: base64Encode(key),
      );
    } catch (e) {
      debugPrint('SessionService: Keychain write failed: $e');
    }
  }

  /// Returns the current session key, or null if locked.
  static Uint8List? getSessionKey() => _sessionKey;

  /// Load session key from Keychain (for biometric re-auth).
  static Future<Uint8List?> loadSessionKey() async {
    try {
      final encoded = await _secureStorage.read(key: _keyCredKey);
      if (encoded != null) {
        _sessionKey = base64Decode(encoded);
        return _sessionKey;
      }
    } catch (e) {
      debugPrint('SessionService: Keychain read failed: $e');
    }
    return null;
  }

  /// Zero out and remove session key from memory and Keychain.
  static Future<void> clearSessionKey() async {
    _zeroAndClear();
    try {
      await _secureStorage.delete(key: _keyCredKey);
    } catch (e) {
      debugPrint('SessionService: Keychain delete failed: $e');
    }
  }

  static void initialize({
    Duration? timeout,
    bool biometricEnabled = false,
  }) {
    _sessionTimeout = timeout ?? _defaultTimeout;
    _biometricEnabled = biometricEnabled;
    _lastActivity = DateTime.now();
    _sessionStartedAt = DateTime.now();
    _isLocked = false;
    _startSessionTimer();
  }

  static void _startSessionTimer() {
    _stopSessionTimer();
    if (_isAbsoluteTimeoutReached()) {
      _lockSession();
      return;
    }
    _sessionTimer = Timer(_sessionTimeout, _lockSession);
  }

  static bool _isAbsoluteTimeoutReached() {
    if (_sessionStartedAt == null) return false;
    return DateTime.now().difference(_sessionStartedAt!) >= _absoluteTimeout;
  }

  static void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }

  static void resetTimer() {
    if (_isLocked) return;
    if (_isAbsoluteTimeoutReached()) {
      _lockSession();
      return;
    }
    _lastActivity = DateTime.now();
    _startSessionTimer();
  }

  static void _lockSession() {
    if (_isLocked) return;
    _isLocked = true;
    _stopSessionTimer();
    _notifyListeners();
  }

  /// Zero out key bytes before nulling — unlike Dart Strings, Uint8List is mutable.
  static void _zeroAndClear() {
    if (_sessionKey != null) {
      _sessionKey!.fillRange(0, _sessionKey!.length, 0);
      _sessionKey = null;
    }
  }

  static void unlockSession() {
    if (!_isLocked) return;
    _isLocked = false;
    _lastActivity = DateTime.now();
    _sessionStartedAt = DateTime.now();
    _startSessionTimer();
    _notifyListeners();
  }

  static bool isLocked() => _isLocked;

  static Duration? timeUntilLock() {
    if (_isLocked || _lastActivity == null || _sessionTimer == null) {
      return Duration.zero;
    }
    final elapsed = DateTime.now().difference(_lastActivity!);
    final remaining = _sessionTimeout - elapsed;

    if (_sessionStartedAt != null) {
      final absoluteRemaining =
          _absoluteTimeout - DateTime.now().difference(_sessionStartedAt!);
      if (absoluteRemaining < remaining) {
        return absoluteRemaining.isNegative ? Duration.zero : absoluteRemaining;
      }
    }
    return remaining.isNegative ? Duration.zero : remaining;
  }

  static DateTime? lastActivity() => _lastActivity;

  static void addListener(VoidCallback listener) => _listeners.add(listener);
  static void removeListener(VoidCallback listener) =>
      _listeners.remove(listener);

  static void _notifyListeners() {
    for (final listener in _listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('SessionService: listener error: $e');
      }
    }
  }

  static void dispose() {
    _stopSessionTimer();
    _listeners.clear();
    _zeroAndClear();
  }

  static void extendSession() {
    if (_biometricEnabled) _sessionTimeout = _biometricTimeout;
    resetTimer();
  }

  static void shortenSession() {
    _sessionTimeout = const Duration(minutes: 2);
    resetTimer();
  }

  static bool needsBiometricReauth() {
    if (!_biometricEnabled || !_isLocked) return false;
    final timeSinceLock =
        DateTime.now().difference(_lastActivity ?? DateTime.now());
    return timeSinceLock > _biometricTimeout;
  }

  static void forceLock() => _lockSession();

  static Map<String, dynamic> getSessionStatus() {
    return {
      'is_locked': _isLocked,
      'last_activity': _lastActivity,
      'time_until_lock': timeUntilLock(),
      'timeout_duration': _sessionTimeout,
      'biometric_enabled': _biometricEnabled,
      'session_started_at': _sessionStartedAt,
    };
  }
}
