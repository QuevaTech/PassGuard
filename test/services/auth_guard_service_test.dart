import 'dart:math' show pow;
import 'package:flutter_test/flutter_test.dart';
import 'package:passguard_vault/services/auth_guard_service.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // § 1 — Attempt Counting
  // ─────────────────────────────────────────────────────────────────────────
  group('Attempt Counting', () {
    setUp(() => AuthGuardService.recordSuccess());

    test('starts with 5 remaining attempts', () {
      expect(AuthGuardService.remainingAttempts(), equals(5));
    });

    test('each failed attempt decrements remaining count', () {
      AuthGuardService.recordFailedAttempt();
      expect(AuthGuardService.remainingAttempts(), equals(4));
      AuthGuardService.recordFailedAttempt();
      expect(AuthGuardService.remainingAttempts(), equals(3));
      AuthGuardService.recordFailedAttempt();
      expect(AuthGuardService.remainingAttempts(), equals(2));
    });

    test('remainingAttempts never goes below 0', () {
      for (var i = 0; i < 10; i++) {
        AuthGuardService.recordFailedAttempt();
      }
      expect(AuthGuardService.remainingAttempts(), equals(0));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // § 2 — Lockout Trigger
  // ─────────────────────────────────────────────────────────────────────────
  group('Lockout Trigger', () {
    setUp(() => AuthGuardService.recordSuccess());

    test('first 4 attempts do NOT trigger lockout', () {
      for (var i = 0; i < 4; i++) {
        final locked = AuthGuardService.recordFailedAttempt();
        expect(locked, isFalse, reason: 'Attempt ${i + 1}/5 should not lock');
        expect(AuthGuardService.isLockedOut(), isFalse);
      }
    });

    test('5th attempt triggers lockout', () {
      for (var i = 0; i < 4; i++) {
        AuthGuardService.recordFailedAttempt();
      }
      final locked = AuthGuardService.recordFailedAttempt();
      expect(locked, isTrue);
      expect(AuthGuardService.isLockedOut(), isTrue);
    });

    test('lockout has a positive remaining duration', () {
      for (var i = 0; i < 5; i++) {
        AuthGuardService.recordFailedAttempt();
      }
      final remaining = AuthGuardService.remainingLockout();
      expect(remaining.inSeconds, greaterThan(0));
      expect(remaining.inSeconds, lessThanOrEqualTo(30),
          reason: 'First lockout should be ≤ 30s');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // § 3 — Exponential Backoff Progression
  // ─────────────────────────────────────────────────────────────────────────
  group('Exponential Backoff', () {
    setUp(() => AuthGuardService.recordSuccess());

    test('lockout multiplier follows 2^n pattern', () {
      // The backoff formula: 30s * 2^(failedAttempts - maxAttempts)
      // After 5 fails: 30 * 2^0 = 30s
      // After 6 fails: 30 * 2^1 = 60s
      // After 7 fails: 30 * 2^2 = 120s
      // After 8 fails: 30 * 2^3 = 240s
      // After 9 fails: 30 * 2^4 = 480s
      // After 10 fails: 30 * 2^5 = 900s = 15m (max)
      // After 11+ fails: capped at 900s = 15m
      for (var i = 0; i < 5; i++) {
        AuthGuardService.recordFailedAttempt();
      }
      // 5th fail → first lockout, remaining ≤ 30s
      expect(AuthGuardService.remainingLockout().inSeconds, lessThanOrEqualTo(30));
    });

    test('lockout duration never exceeds 15 minutes', () {
      // Push well past the cap
      for (var i = 0; i < 20; i++) {
        AuthGuardService.recordFailedAttempt();
      }
      expect(
        AuthGuardService.remainingLockout().inMinutes,
        lessThanOrEqualTo(15),
        reason: 'Max lockout is 15 minutes',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // § 4 — Success Reset
  // ─────────────────────────────────────────────────────────────────────────
  group('Success Reset', () {
    setUp(() => AuthGuardService.recordSuccess());

    test('recordSuccess clears failed attempts', () {
      for (var i = 0; i < 3; i++) {
        AuthGuardService.recordFailedAttempt();
      }
      expect(AuthGuardService.remainingAttempts(), equals(2));

      AuthGuardService.recordSuccess();
      expect(AuthGuardService.remainingAttempts(), equals(5));
    });

    test('recordSuccess clears lockout', () {
      for (var i = 0; i < 5; i++) {
        AuthGuardService.recordFailedAttempt();
      }
      expect(AuthGuardService.isLockedOut(), isTrue);

      AuthGuardService.recordSuccess();
      expect(AuthGuardService.isLockedOut(), isFalse);
      expect(AuthGuardService.remainingLockout(), equals(Duration.zero));
    });

    test('after reset, full attempt budget is restored', () {
      for (var i = 0; i < 5; i++) {
        AuthGuardService.recordFailedAttempt();
      }
      AuthGuardService.recordSuccess();

      // Should be able to fail 4 more times without lockout
      for (var i = 0; i < 4; i++) {
        final locked = AuthGuardService.recordFailedAttempt();
        expect(locked, isFalse);
      }
      // 5th triggers lockout again
      expect(AuthGuardService.recordFailedAttempt(), isTrue);
    });
  });
}
