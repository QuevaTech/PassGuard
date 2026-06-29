import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:passguard_vault/services/encryption_service.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // § 1 — Argon2id KDF Parameter Hardening
  // ─────────────────────────────────────────────────────────────────────────
  group('KDF Parameters', () {
    test('iterations meets OWASP minimum (≥ 10)', () {
      expect(
        EncryptionService.argon2Iterations,
        greaterThanOrEqualTo(10),
        reason: 'OWASP 2023 recommends t ≥ 10 for Argon2id',
      );
    });

    test('memory cost meets OWASP minimum (≥ 256 MB)', () {
      expect(
        EncryptionService.argon2Memory,
        greaterThanOrEqualTo(262144),
        reason: 'OWASP 2023 recommends m ≥ 256 MB for Argon2id',
      );
    });

    test('parallelism is at least 4 lanes', () {
      expect(
        EncryptionService.argon2Parallelism,
        greaterThanOrEqualTo(4),
        reason: 'Argon2id should use ≥ 4 lanes for modern multi-core CPUs',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // § 2 — Key Derivation
  // ─────────────────────────────────────────────────────────────────────────
  group('Key Derivation', () {
    test('produces a 256-bit (32-byte) key', () {
      final salt = EncryptionService.generateSalt();
      final key = EncryptionService.deriveKey('test_password', salt);
      expect(key.length, equals(32));
    });

    test('is deterministic for the same password + salt pair', () {
      final salt = EncryptionService.generateSalt();
      final a = EncryptionService.deriveKey('deterministic', salt);
      final b = EncryptionService.deriveKey('deterministic', salt);
      expect(a, equals(b));
    });

    test('produces distinct keys for different passwords', () {
      final salt = EncryptionService.generateSalt();
      final a = EncryptionService.deriveKey('alpha', salt);
      final b = EncryptionService.deriveKey('bravo', salt);
      expect(a, isNot(equals(b)));
    });

    test('produces distinct keys for different salts', () {
      final s1 = EncryptionService.generateSalt();
      final s2 = EncryptionService.generateSalt();
      final a = EncryptionService.deriveKey('same', s1);
      final b = EncryptionService.deriveKey('same', s2);
      expect(a, isNot(equals(b)));
    });

    test('respects optional parameter overrides', () {
      final salt = EncryptionService.generateSalt();
      final defaultKey = EncryptionService.deriveKey('pw', salt);
      final customKey = EncryptionService.deriveKey(
        'pw', salt,
        iterations: 3,
        memory: 65536,
        parallelism: 2,
      );
      expect(defaultKey, isNot(equals(customKey)),
          reason: 'Different KDF params must produce different keys');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // § 3 — CSPRNG (Secure Random Generation)
  // ─────────────────────────────────────────────────────────────────────────
  group('Secure Random Generation', () {
    test('generateSecureRandomBytes returns Uint8List of exact length', () {
      for (final len in [1, 12, 16, 32, 64, 128]) {
        final bytes = EncryptionService.generateSecureRandomBytes(len);
        expect(bytes, isA<Uint8List>());
        expect(bytes.length, equals(len));
      }
    });

    test('generateSalt returns 32-byte salt', () {
      expect(EncryptionService.generateSalt().length, equals(32));
    });

    test('generateIV returns 12-byte IV (GCM recommended)', () {
      expect(EncryptionService.generateIV().length, equals(12));
    });

    test('output is not trivially all-zero', () {
      // Run 5 times to reduce fluke probability
      for (var i = 0; i < 5; i++) {
        final bytes = EncryptionService.generateSecureRandomBytes(32);
        expect(bytes.any((b) => b != 0), isTrue,
            reason: 'CSPRNG output should not be all zeros');
      }
    });

    test('successive calls produce different output', () {
      final a = EncryptionService.generateSecureRandomBytes(32);
      final b = EncryptionService.generateSecureRandomBytes(32);
      expect(a, isNot(equals(b)),
          reason: 'Two CSPRNG calls should not produce identical output');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // § 4 — AES-256-GCM Encrypt / Decrypt
  // ─────────────────────────────────────────────────────────────────────────
  group('AES-256-GCM', () {
    late Uint8List key;

    setUp(() {
      key = EncryptionService.generateSecureRandomBytes(32);
    });

    test('encrypt → decrypt roundtrip preserves plaintext', () {
      const plaintext = 'Hello, secure world!';
      final enc = EncryptionService.encryptWithKey(plaintext, key);

      expect(enc, containsPair('encrypted', isNotEmpty));
      expect(enc, containsPair('iv', isNotEmpty));
      expect(enc, containsPair('tag', isNotEmpty));

      final dec = EncryptionService.decryptWithKey(
        encryptedContent: enc['encrypted']!,
        ivBase64: enc['iv']!,
        tagBase64: enc['tag']!,
        rawKey: key,
      );
      expect(dec, equals(plaintext));
    });

    test('empty string roundtrip works', () {
      const plaintext = '';
      final enc = EncryptionService.encryptWithKey(plaintext, key);
      final dec = EncryptionService.decryptWithKey(
        encryptedContent: enc['encrypted']!,
        ivBase64: enc['iv']!,
        tagBase64: enc['tag']!,
        rawKey: key,
      );
      expect(dec, equals(plaintext));
    });

    test('long plaintext roundtrip works', () {
      final plaintext = 'A' * 100000; // 100 KB
      final enc = EncryptionService.encryptWithKey(plaintext, key);
      final dec = EncryptionService.decryptWithKey(
        encryptedContent: enc['encrypted']!,
        ivBase64: enc['iv']!,
        tagBase64: enc['tag']!,
        rawKey: key,
      );
      expect(dec, equals(plaintext));
    });

    test('each encryption uses a unique IV (nonce reuse prevention)', () {
      const pt = 'same plaintext';
      final e1 = EncryptionService.encryptWithKey(pt, key);
      final e2 = EncryptionService.encryptWithKey(pt, key);
      expect(e1['iv'], isNot(equals(e2['iv'])),
          reason: 'GCM nonces must never repeat for the same key');
    });

    test('unique IV produces different ciphertext', () {
      const pt = 'same plaintext';
      final e1 = EncryptionService.encryptWithKey(pt, key);
      final e2 = EncryptionService.encryptWithKey(pt, key);
      expect(e1['encrypted'], isNot(equals(e2['encrypted'])));
    });

    test('tampered ciphertext is rejected (authenticity)', () {
      final enc = EncryptionService.encryptWithKey('secret', key);
      final cipherBytes = base64Decode(enc['encrypted']!);
      cipherBytes[0] ^= 0xFF; // flip first byte

      expect(
        () => EncryptionService.decryptWithKey(
          encryptedContent: base64Encode(cipherBytes),
          ivBase64: enc['iv']!,
          tagBase64: enc['tag']!,
          rawKey: key,
        ),
        throwsException,
        reason: 'GCM must reject tampered ciphertext',
      );
    });

    test('tampered auth tag is rejected', () {
      final enc = EncryptionService.encryptWithKey('secret', key);
      final tagBytes = base64Decode(enc['tag']!);
      tagBytes[0] ^= 0xFF;

      expect(
        () => EncryptionService.decryptWithKey(
          encryptedContent: enc['encrypted']!,
          ivBase64: enc['iv']!,
          tagBase64: base64Encode(tagBytes),
          rawKey: key,
        ),
        throwsException,
        reason: 'GCM must reject tampered auth tag',
      );
    });

    test('wrong key is rejected', () {
      final wrongKey = EncryptionService.generateSecureRandomBytes(32);
      final enc = EncryptionService.encryptWithKey('secret', key);

      expect(
        () => EncryptionService.decryptWithKey(
          encryptedContent: enc['encrypted']!,
          ivBase64: enc['iv']!,
          tagBase64: enc['tag']!,
          rawKey: wrongKey,
        ),
        throwsException,
        reason: 'GCM must reject decryption with wrong key',
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // § 5 — Password Hash Verification (String-free comparison)
  // ─────────────────────────────────────────────────────────────────────────
  group('Password Hash Verification', () {
    test('hashPasswordWithSalt returns 64-char hex hash + base64 salt', () {
      final result = EncryptionService.hashPasswordWithSalt('my_password');
      expect(result['hash']!.length, equals(64),
          reason: 'SHA-256 hex digest is 64 characters');
      expect(result['salt'], isNotEmpty);
      // Verify salt is valid base64
      expect(() => base64Decode(result['salt']!), returnsNormally);
    });

    test('correct password verifies successfully', () {
      final result = EncryptionService.hashPasswordWithSalt('correct');
      expect(
        EncryptionService.verifyPassword(
            'correct', result['hash']!, result['salt']!),
        isTrue,
      );
    });

    test('wrong password is rejected', () {
      final result = EncryptionService.hashPasswordWithSalt('correct');
      expect(
        EncryptionService.verifyPassword(
            'wrong', result['hash']!, result['salt']!),
        isFalse,
      );
    });

    test('verification is case-sensitive', () {
      final result = EncryptionService.hashPasswordWithSalt('Password');
      expect(
        EncryptionService.verifyPassword(
            'password', result['hash']!, result['salt']!),
        isFalse,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // § 6 — Memory Zeroing
  // ─────────────────────────────────────────────────────────────────────────
  group('Memory Zeroing', () {
    test('clearKey fills buffer with zeros', () {
      final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
      expect(key.any((b) => b != 0), isTrue);
      EncryptionService.clearKey(key);
      expect(key.every((b) => b == 0), isTrue);
    });

    test('clearKey works on empty buffer', () {
      final key = Uint8List(0);
      expect(() => EncryptionService.clearKey(key), returnsNormally);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // § 7 — Vault Header
  // ─────────────────────────────────────────────────────────────────────────
  group('Vault Header', () {
    test('contains required fields with correct KDF parameters', () {
      final h = EncryptionService.createVaultHeader('master');
      expect(h['format'], equals('pgvault'));
      expect(h['kdf'], equals('argon2id'));
      expect(h['kdf_iterations'], equals(EncryptionService.argon2Iterations));
      expect(h['kdf_memory'], equals(EncryptionService.argon2Memory));
      expect(h['kdf_parallelism'], equals(EncryptionService.argon2Parallelism));
      expect(h['salt'], isA<String>());
      expect(h['key_hash'], isA<String>());
      expect(h['created_at'], isA<String>());
    });

    test('each header gets a unique salt', () {
      final h1 = EncryptionService.createVaultHeader('pw');
      final h2 = EncryptionService.createVaultHeader('pw');
      expect(h1['salt'], isNot(equals(h2['salt'])));
    });
  });
}
