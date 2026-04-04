import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralised factory for [FlutterSecureStorage] with platform-appropriate
/// options. All services that need secure storage should call [create()] so
/// that security settings are applied consistently.
///
/// Platform security tiers:
///
///   iOS           — Keychain with hardware Secure Enclave (modern devices)
///   macOS release — Data Protection Keychain (requires App Sandbox or signing)
///   macOS debug   — Legacy Keychain via ad-hoc signing; write may fail with
///                   -34018 — the app degrades gracefully to in-memory storage
///   Android       — EncryptedSharedPreferences → Android Keystore
///                   (hardware-backed StrongBox on API 28+, TEE on API 23+)
///   Windows       — DPAPI; TPM-backed automatically when available on the host
///   Linux         — libsecret → GNOME Keyring or KWallet
///                   Requires: libsecret-1-0 package + secret-service daemon
class SecureStorageFactory {
  SecureStorageFactory._();

  static FlutterSecureStorage create() => FlutterSecureStorage(
        // Android: use EncryptedSharedPreferences (backed by Android Keystore)
        // instead of the legacy AES/RSA approach.
        aOptions: const AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        // iOS: default IOSOptions — Keychain with kSecAttrAccessibleWhenUnlocked
        // macOS: Data Protection Keychain in release; legacy Keychain in debug.
        mOptions: MacOsOptions(usesDataProtectionKeychain: kReleaseMode),
        // Windows: DPAPI with background-isolate writes (default, keeps UI smooth).
        wOptions: const WindowsOptions(),
        // Linux: libsecret (GNOME Keyring / KWallet). v10 has no extra options.
        lOptions: const LinuxOptions(),
      );

  /// Writes and deletes a probe key to verify that secure storage is
  /// operational on this device/environment.
  ///
  /// Returns `false` when:
  /// - Linux: no secret-service daemon (GNOME Keyring / KWallet) is running
  /// - macOS debug: code-signing entitlements insufficient for keychain access
  /// - Any other platform-specific keychain lockout condition
  static Future<bool> isAvailable() async {
    try {
      final storage = create();
      await storage.write(key: '_pg_storage_probe_', value: '1');
      await storage.delete(key: '_pg_storage_probe_');
      return true;
    } catch (_) {
      return false;
    }
  }
}
