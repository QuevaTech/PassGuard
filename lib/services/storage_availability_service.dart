import '../utils/secure_storage_factory.dart';

/// Checks and caches whether the platform's secure storage backend is
/// operational. Call [initialize()] once at app startup (after the Flutter
/// engine is ready). All services read [isAvailable] before deciding whether
/// to attempt keychain operations.
///
/// When unavailable the app continues to function — sensitive material is kept
/// in process memory only and is lost when the app terminates. A warning
/// banner is shown in VaultScreen so the user knows their session keys are not
/// persisted.
class StorageAvailabilityService {
  StorageAvailabilityService._();

  static bool _checked = false;
  static bool _available = true;

  /// Whether secure storage is operational on this device.
  /// Always `true` until [initialize()] has been called.
  static bool get isAvailable => _available;

  /// Whether [initialize()] has completed.
  static bool get isChecked => _checked;

  /// Probe secure storage and cache the result. Safe to call multiple times —
  /// only the first call performs I/O; subsequent calls are no-ops.
  static Future<void> initialize() async {
    if (_checked) return;
    _available = await SecureStorageFactory.isAvailable();
    _checked = true;
  }
}
