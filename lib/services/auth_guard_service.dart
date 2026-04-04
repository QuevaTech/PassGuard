import 'package:flutter/foundation.dart';
import '../utils/secure_storage_factory.dart';

/// Brute-force protection service with exponential backoff.
///
/// Failed attempt count and lockout timestamp are persisted to the platform
/// keychain so closing and reopening the app does NOT reset the lockout counter.
class AuthGuardService {
  static const int _maxAttempts = 5;
  static const Duration _initialLockout = Duration(seconds: 30);
  static const Duration _maxLockout = Duration(minutes: 15);

  static const _keyFailedAttempts = 'pg_auth_failed_attempts';
  static const _keyLockedUntil = 'pg_auth_locked_until';

  static final _secureStorage = SecureStorageFactory.create();

  static int _failedAttempts = 0;
  static DateTime? _lockedUntil;

  /// Load persisted lockout state. Call once at app startup.
  static Future<void> initialize() async {
    try {
      final attemptsStr = await _secureStorage.read(key: _keyFailedAttempts);
      final lockedUntilStr = await _secureStorage.read(key: _keyLockedUntil);

      if (attemptsStr != null) {
        _failedAttempts = int.tryParse(attemptsStr) ?? 0;
      }
      if (lockedUntilStr != null) {
        _lockedUntil = DateTime.tryParse(lockedUntilStr);
      }
    } catch (e) {
      debugPrint('AuthGuardService: Failed to load persisted state: $e');
    }
  }

  /// Persist current state to keychain (fire-and-forget, non-blocking).
  static void _persistAsync() {
    _secureStorage
        .write(key: _keyFailedAttempts, value: _failedAttempts.toString())
        .catchError((e) {
      debugPrint('AuthGuardService: persist failed_attempts error: $e');
    });

    if (_lockedUntil != null) {
      _secureStorage
          .write(
            key: _keyLockedUntil,
            value: _lockedUntil!.toIso8601String(),
          )
          .catchError((e) {
        debugPrint('AuthGuardService: persist locked_until error: $e');
      });
    } else {
      _secureStorage.delete(key: _keyLockedUntil).catchError((e) {
        debugPrint('AuthGuardService: delete locked_until error: $e');
      });
    }
  }

  /// Check if login is currently locked out.
  static bool isLockedOut() {
    if (_lockedUntil == null) return false;
    if (DateTime.now().isAfter(_lockedUntil!)) {
      _lockedUntil = null;
      return false;
    }
    return true;
  }

  /// Get remaining lockout duration.
  static Duration remainingLockout() {
    if (_lockedUntil == null) return Duration.zero;
    final remaining = _lockedUntil!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Record a failed login attempt. Returns true if now locked out.
  static bool recordFailedAttempt() {
    _failedAttempts++;

    if (_failedAttempts >= _maxAttempts) {
      // Exponential backoff: 30s, 60s, 120s, ... up to 15 min
      final multiplier = (_failedAttempts - _maxAttempts + 1);
      var lockoutDuration = _initialLockout * multiplier;
      if (lockoutDuration > _maxLockout) {
        lockoutDuration = _maxLockout;
      }
      _lockedUntil = DateTime.now().add(lockoutDuration);
      _persistAsync();
      return true;
    }
    _persistAsync();
    return false;
  }

  /// Reset on successful login.
  static void recordSuccess() {
    _failedAttempts = 0;
    _lockedUntil = null;
    _persistAsync();
  }

  /// Get number of remaining attempts before lockout.
  static int remainingAttempts() {
    final remaining = _maxAttempts - _failedAttempts;
    return remaining < 0 ? 0 : remaining;
  }
}
