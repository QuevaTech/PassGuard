import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class EncryptionService {
  // Argon2id parameters
  static const int argon2Iterations = 3;
  static const int argon2Memory = 65536; // 64 MB
  static const int argon2Parallelism = 4;
  static const int _keyLength = 32; // 256 bit
  static const int _saltLength = 32; // 256 bit
  static const int _ivLength = 12; // 96 bit (GCM recommended)
  static const int _formatVersion = 3;

  // --- Key Derivation ---

  // Derive AES-256 key from master password using Argon2id.
  // Optional param overrides allow vaults created with different settings to
  // be reopened correctly (read stored values from vault header).
  static Uint8List deriveKey(
    String password,
    Uint8List salt, {
    int? iterations,
    int? memory,
    int? parallelism,
  }) {
    final generator = Argon2BytesGenerator();
    final params = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      salt,
      desiredKeyLength: _keyLength,
      iterations: iterations ?? argon2Iterations,
      memory: memory ?? argon2Memory,
      lanes: parallelism ?? argon2Parallelism,
    );
    generator.init(params);
    return generator.process(Uint8List.fromList(utf8.encode(password)));
  }

  // --- Random Generation ---

  static Uint8List generateSecureRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  static Uint8List generateSalt() => generateSecureRandomBytes(_saltLength);
  static Uint8List generateIV() => generateSecureRandomBytes(_ivLength);

  // --- Vault-Level Encryption (password string → key derivation included) ---

  static Map<String, String> encryptContent(String content, String masterPassword) {
    try {
      final salt = generateSalt();
      final ivBytes = generateIV();
      final key = encrypt.Key(deriveKey(masterPassword, salt));
      final iv = encrypt.IV(ivBytes);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );

      final encrypted = encrypter.encrypt(content, iv: iv);

      final cipherBytes = encrypted.bytes;
      final tagStart = cipherBytes.length - 16;
      final cipherOnly = cipherBytes.sublist(0, tagStart);
      final authTag = cipherBytes.sublist(tagStart);

      return {
        'encrypted': base64Encode(cipherOnly),
        'iv': iv.base64,
        'salt': base64Encode(salt),
        'tag': base64Encode(authTag),
      };
    } catch (e) {
      throw Exception('Encryption failed');
    }
  }

  static String decryptContent({
    required String encryptedContent,
    required String ivBase64,
    required String saltBase64,
    required String masterPassword,
    String? tagBase64,
  }) {
    try {
      final salt = base64Decode(saltBase64);
      final key = encrypt.Key(deriveKey(masterPassword, salt));
      final iv = encrypt.IV.fromBase64(ivBase64);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );

      final cipherBytes = base64Decode(encryptedContent);
      Uint8List fullCipher;
      if (tagBase64 != null && tagBase64 != encryptedContent) {
        final tagBytes = base64Decode(tagBase64);
        fullCipher = Uint8List(cipherBytes.length + tagBytes.length);
        fullCipher.setAll(0, cipherBytes);
        fullCipher.setAll(cipherBytes.length, tagBytes);
      } else {
        fullCipher = Uint8List.fromList(cipherBytes);
      }

      final encrypted = encrypt.Encrypted(fullCipher);
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Decryption failed');
    }
  }

  // --- Entry-Level Encryption (pre-derived key → no key derivation) ---

  /// Encrypt a single entry's sensitive fields with a unique IV.
  /// Uses the already-derived key to avoid repeated Argon2id computation.
  static Map<String, String> encryptWithKey(String plaintext, Uint8List rawKey) {
    final ivBytes = generateIV();
    final key = encrypt.Key(rawKey);
    final iv = encrypt.IV(ivBytes);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    final cipherBytes = encrypted.bytes;
    final tagStart = cipherBytes.length - 16;
    final cipherOnly = cipherBytes.sublist(0, tagStart);
    final authTag = cipherBytes.sublist(tagStart);

    return {
      'encrypted': base64Encode(cipherOnly),
      'iv': base64Encode(ivBytes),
      'tag': base64Encode(authTag),
    };
  }

  /// Decrypt a single entry's sensitive fields with the pre-derived key.
  static String decryptWithKey({
    required String encryptedContent,
    required String ivBase64,
    required String tagBase64,
    required Uint8List rawKey,
  }) {
    final key = encrypt.Key(rawKey);
    final iv = encrypt.IV.fromBase64(ivBase64);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.gcm),
    );

    final cipherBytes = base64Decode(encryptedContent);
    final tagBytes = base64Decode(tagBase64);
    final fullCipher = Uint8List(cipherBytes.length + tagBytes.length);
    fullCipher.setAll(0, cipherBytes);
    fullCipher.setAll(cipherBytes.length, tagBytes);

    final encrypted = encrypt.Encrypted(fullCipher);
    return encrypter.decrypt(encrypted, iv: iv);
  }

  // --- Password Hashing ---

  static Map<String, String> hashPasswordWithSalt(String password) {
    final salt = generateSalt();
    final derived = deriveKey(password, salt);
    final hash = sha256.convert(derived).toString();
    return {
      'hash': hash,
      'salt': base64Encode(salt),
    };
  }

  static bool verifyPassword(String password, String storedHash, String saltBase64) {
    final salt = base64Decode(saltBase64);
    final derived = deriveKey(password, salt);
    final hash = sha256.convert(derived).toString();
    return _constantTimeEquals(utf8.encode(hash), utf8.encode(storedHash));
  }

  // Constant-time byte comparison — prevents timing attacks.
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  // Zero out a sensitive byte buffer (best-effort — GC may retain copies).
  static void clearKey(Uint8List key) {
    key.fillRange(0, key.length, 0);
  }

  // --- Vault Header ---

  static Map<String, dynamic> createVaultHeader(String masterPassword) {
    final salt = generateSalt();
    final key = deriveKey(masterPassword, salt);
    final keyHash = sha256.convert(key).toString();
    clearKey(key);

    return {
      'format': 'pgvault',
      'version': _formatVersion,
      'kdf': 'argon2id',
      // Store KDF params so future versions can re-derive the key correctly
      // even if the default constants change.
      'kdf_iterations': argon2Iterations,
      'kdf_memory': argon2Memory,
      'kdf_parallelism': argon2Parallelism,
      'salt': base64Encode(salt),
      'created_at': DateTime.now().toIso8601String(),
      'key_hash': keyHash,
    };
  }
}
