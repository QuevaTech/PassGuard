import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../utils/secure_storage_factory.dart';

class SessionService {
  static const Duration _defaultTimeout = Duration(minutes: 5);
  static const Duration _biometricTimeout = Duration(minutes: 10);
  static const Duration _absoluteTimeout = Duration(hours: 4);

  // Keychain key — stores base64-encoded derived key bytes (NOT the password)
  static const _keyCredKey = 'pg_vault_session_key_v2';

  static final _secureStorage = SecureStorageFactory.create();

  static Timer? _sessionTimer;
  static DateTime? _lastActivity;
  static DateTime? _sessionStartedAt;
  static bool _isLocked = false;
  static bool _biometricEnabled = false;
  static bool _quickUnlockEnabled = false;
  static Duration _sessionTimeout = _defaultTimeout;

  // Derived key bytes — never the master password string
  static Uint8List? _sessionKey;

  static final List<VoidCallback> _listeners = [];

  /// Store the derived session key in memory, and optionally in the platform
  /// secure store for an explicitly enabled PIN or biometric quick-unlock.
  ///
  /// The master password is never stored. When [persistForQuickUnlock] is
  /// false, any previously cached key is removed so a normal master-password
  /// session cannot later be reopened through a stale keychain entry.
  static Future<void> setSessionKey(
    Uint8List key, {
    bool? persistForQuickUnlock,
  }) async {
    if (persistForQuickUnlock != null) {
      _quickUnlockEnabled = persistForQuickUnlock;
    }
    _zeroAndClear();
    _sessionKey = Uint8List.fromList(key);

    if (_quickUnlockEnabled) {
      await _persistCurrentSessionKey();
    } else {
      await _deletePersistedSessionKey();
    }
  }

  /// Enables or disables persistence of the current derived key for a PIN or
  /// biometric quick-unlock. Disabling this setting immediately removes the
  /// cached key from the platform secure store.
  static Future<void> setQuickUnlockEnabled(bool enabled) async {
    _quickUnlockEnabled = enabled;
    if (enabled && _sessionKey != null) {
      await _persistCurrentSessionKey();
    } else if (!enabled) {
      await _deletePersistedSessionKey();
    }
  }

  static bool isQuickUnlockEnabled() => _quickUnlockEnabled;

  static Future<void> _persistCurrentSessionKey() async {
    final key = _sessionKey;
    if (key == null) return;
    try {
      await _secureStorage.write(
        key: _keyCredKey,
        value: base64Encode(key),
      );
    } catch (_) {
      // Keychain write failures are handled by the calling UI's availability
      // checks; the in-memory session remains usable until it locks.
    }
  }

  static Future<void> _deletePersistedSessionKey() async {
    try {
      await _secureStorage.delete(key: _keyCredKey);
    } catch (_) {
      // Best effort: a failed delete must not prevent an in-memory lock.
    }
  }

  /// Returns the current session key, or null if locked.
  static Uint8List? getSessionKey() => _isLocked ? null : _sessionKey;

  /// Load a cached key only after PIN or biometric quick-unlock was enabled.
  static Future<Uint8List?> loadSessionKey() async {
    if (!_quickUnlockEnabled) return null;
    try {
      final encoded = await _secureStorage.read(key: _keyCredKey);
      if (encoded != null) {
        _sessionKey = base64Decode(encoded);
        return _sessionKey;
      }
    } catch (e) {
      // Ignored: Keychain read failed
    }
    return null;
  }

  /// Zero out and remove session key from memory and Keychain.
  static Future<void> clearSessionKey() async {
    _zeroAndClear();
    _quickUnlockEnabled = false;
    await _deletePersistedSessionKey();
  }

  static void initialize({
    Duration? timeout,
    bool? biometricEnabled,
  }) {
    _sessionTimeout = timeout ?? _defaultTimeout;
    _biometricEnabled = biometricEnabled ?? _biometricEnabled;
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
    _zeroAndClear();
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
    if (!_isLocked || _sessionKey == null) return;
    _isLocked = false;
    _lastActivity = DateTime.now();
    _sessionStartedAt = DateTime.now();
    _startSessionTimer();
    _notifyListeners();
  }

  static bool isLocked() => _isLocked;

  static bool isBiometricEnabled() => _biometricEnabled;

  /// Updates the active session's re-authentication policy immediately.
  /// The caller is responsible for persisting the user preference separately.
  static void setBiometricEnabled(bool enabled) {
    _biometricEnabled = enabled;
    resetTimer();
  }

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
        // Ignored: listener error
      }
    }
  }

  static void dispose() {
    _stopSessionTimer();
    _listeners.clear();
    _zeroAndClear();
    _quickUnlockEnabled = false;
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
      'quick_unlock_enabled': _quickUnlockEnabled,
      'session_started_at': _sessionStartedAt,
    };
  }
}
