/// Brute-force protection service with exponential backoff
class AuthGuardService {
  static const int _maxAttempts = 5;
  static const Duration _initialLockout = Duration(seconds: 30);
  static const Duration _maxLockout = Duration(minutes: 15);

  static int _failedAttempts = 0;
  static DateTime? _lockedUntil;

  /// Check if login is currently locked out
  static bool isLockedOut() {
    if (_lockedUntil == null) return false;
    if (DateTime.now().isAfter(_lockedUntil!)) {
      // Lockout expired, but keep failed attempt count for escalation
      _lockedUntil = null;
      return false;
    }
    return true;
  }

  /// Get remaining lockout duration
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
      return true;
    }
    return false;
  }

  /// Reset on successful login
  static void recordSuccess() {
    _failedAttempts = 0;
    _lockedUntil = null;
  }

  /// Get number of remaining attempts before lockout
  static int remainingAttempts() {
    final remaining = _maxAttempts - _failedAttempts;
    return remaining < 0 ? 0 : remaining;
  }
}
