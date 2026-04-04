# Changelog

All notable changes to PassGuard Vault are documented here.

## [1.0.0] - 2026-04-04

### Security
- **Argon2id KDF** — upgraded parameters to 4 iterations / 128 MB memory for master password derivation
- **KDF migration** — existing vault files are automatically re-encrypted with updated parameters on next login
- **Brute-force protection** — 5-attempt limit with exponential backoff lockout (30 s → 15 min), persisted across app restarts
- **PIN hardening** — PIN hash now stored via Argon2id (2 iter / 32 MB) in the platform keychain instead of SHA-256 in SharedPreferences
- **Platform keychain integration** — flutter_secure_storage configured with platform-specific options: Android Keystore (EncryptedSharedPreferences), macOS Data Protection Keychain (release mode), Windows DPAPI, Linux libsecret
- **Clipboard auto-clear** — sensitive values are cleared from the clipboard when the app is backgrounded or paused
- **Biometric session timeout** — reduced from 15 to 10 minutes
- **Field size limits** — notes and custom fields capped at 10 MB; title at 512 chars; category at 256 chars

### Features
- **Dynamic version display** — Settings screen reads version from pubspec.yaml at runtime via package_info_plus
- **Package renamed** — `passguard_vault_v0` → `passguard_vault`; bundle IDs updated for Android and macOS

### Internal
- Centralized `SecureStorageFactory` with consistent platform options across all services
- `AuthGuardService.initialize()` called from SplashScreen after Flutter engine is ready (fixes macOS `-34018` in main)
- Non-fatal KDF migration: login succeeds even if migration fails, with debug logging
