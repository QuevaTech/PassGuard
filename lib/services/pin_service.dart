import 'package:flutter/foundation.dart';
import 'encryption_service.dart';
import '../utils/secure_storage_factory.dart';


/// PIN storage using flutter_secure_storage + Argon2id key derivation.
/// Replaces the previous SHA-256 + SharedPreferences approach.
///
/// PIN uses lighter Argon2id parameters than the master password because:
///   1. Stored in the platform keychain (protected at rest)
///   2. Protected by AuthGuardService (5 attempts → lockout with backoff)
///   3. Only 10,000 possible 4-digit combinations
///
/// Migration note: legacy SharedPreferences PIN data (if any) is ignored.
/// Users with an existing PIN will need to set it up again — the PIN screen
/// falls back gracefully when isPinEnabled() returns false.
class PinService {
  static const _keyPinHash = 'pg_pin_hash_v2';
  static const _keyPinSalt = 'pg_pin_salt_v2';
  static const _keyPinEnabled = 'pg_pin_enabled_v2';

  // Lighter Argon2id params dedicated to PIN hashing.
  static const int _kdfIterations = 2;
  static const int _kdfMemory = 32768; // 32 MB
  static const int _kdfParallelism = 2;

  static final _secureStorage = SecureStorageFactory.create();

  static Future<bool> isPinEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _keyPinEnabled);
      final hash = await _secureStorage.read(key: _keyPinHash);
      return enabled == 'true' && hash != null;
    } catch (e) {
      debugPrint('PinService: isPinEnabled failed: $e');
      return false;
    }
  }

  /// Hash the PIN with Argon2id + random salt and store in the platform keychain.
  static Future<void> setPin(String pin) async {
    final result = EncryptionService.hashPasswordWithSalt(
      pin,
      iterations: _kdfIterations,
      memory: _kdfMemory,
      parallelism: _kdfParallelism,
    );
    await _secureStorage.write(key: _keyPinHash, value: result['hash']);
    await _secureStorage.write(key: _keyPinSalt, value: result['salt']);
    await _secureStorage.write(key: _keyPinEnabled, value: 'true');
  }

  /// Verify the PIN using constant-time Argon2id comparison.
  static Future<bool> verifyPin(String pin) async {
    try {
      final storedHash = await _secureStorage.read(key: _keyPinHash);
      final storedSalt = await _secureStorage.read(key: _keyPinSalt);
      if (storedHash == null || storedSalt == null) return false;
      return EncryptionService.verifyPassword(
        pin, storedHash, storedSalt,
        iterations: _kdfIterations,
        memory: _kdfMemory,
        parallelism: _kdfParallelism,
      );
    } catch (e) {
      debugPrint('PinService: verifyPin failed: $e');
      return false;
    }
  }

  static Future<void> disablePin() async {
    await _secureStorage.delete(key: _keyPinHash);
    await _secureStorage.delete(key: _keyPinSalt);
    await _secureStorage.write(key: _keyPinEnabled, value: 'false');
  }
}
