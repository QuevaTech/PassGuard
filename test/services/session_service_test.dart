import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:passguard_vault/services/session_service.dart';

void main() {
  tearDown(() {
    SessionService.dispose();
  });

  test('locking clears the in-memory session key and blocks access', () async {
    final key = Uint8List.fromList(List<int>.generate(32, (index) => index));
    await SessionService.setSessionKey(key);
    SessionService.initialize(timeout: const Duration(hours: 1));

    final inMemoryKey = SessionService.getSessionKey();
    expect(inMemoryKey, isNotNull);

    SessionService.forceLock();

    expect(SessionService.isLocked(), isTrue);
    expect(SessionService.getSessionKey(), isNull);
    expect(inMemoryKey!.every((byte) => byte == 0), isTrue);
  });

  test('unlock does not succeed until a session key is restored', () {
    SessionService.initialize(timeout: const Duration(hours: 1));
    SessionService.forceLock();

    SessionService.unlockSession();

    expect(SessionService.isLocked(), isTrue);
  });

  test('changing the biometric preference updates the active session', () {
    SessionService.initialize(
      timeout: const Duration(hours: 1),
      biometricEnabled: true,
    );
    expect(SessionService.isBiometricEnabled(), isTrue);

    SessionService.setBiometricEnabled(false);

    expect(SessionService.isBiometricEnabled(), isFalse);
  });
}
