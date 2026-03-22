import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/vault_entry.dart';
import 'encryption_service.dart';
import 'session_service.dart';

enum ImportMode { replace, merge }

class ImportResult {
  final int imported;
  final int skipped;
  final int total;
  ImportResult({required this.imported, required this.skipped, required this.total});
}

class VaultService {
  static const _vaultDirName = '.passguard';
  static const _vaultFileName = 'vault.pgvault';
  static const int _formatVersionV4 = 4;
  static const int _maxImportFileSize = 50 * 1024 * 1024;

  static Future<Directory> _getVaultDirectory() async {
    final Directory baseDir;
    if (Platform.isAndroid || Platform.isIOS) {
      baseDir = await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows) {
      baseDir = await getApplicationSupportDirectory();
    } else {
      final home = Platform.environment['HOME'];
      if (home == null || home.isEmpty) {
        throw Exception('Could not determine home directory');
      }
      baseDir = Directory(home);
    }

    final dir = Directory('${baseDir.path}${Platform.pathSeparator}$_vaultDirName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      if (Platform.isLinux || Platform.isMacOS) {
        await Process.run('chmod', ['700', dir.path]);
      }
    }
    return dir;
  }

  static Future<String> _getVaultFilePath() async {
    final dir = await _getVaultDirectory();
    return '${dir.path}/$_vaultFileName';
  }

  static Future<void> _lockFilePermissions(String filePath) async {
    if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', ['600', filePath]);
    }
  }

  // --- Per-Entry Encryption ---

  static VaultEntry _encryptEntry(VaultEntry entry, Uint8List derivedKey) {
    final sensitiveFields = entry.getSensitiveFields();
    if (sensitiveFields.isEmpty) return entry;

    final plaintext = jsonEncode(sensitiveFields);
    final encrypted = EncryptionService.encryptWithKey(plaintext, derivedKey);

    return VaultEntry(
      id: entry.id,
      type: entry.type,
      title: entry.title,
      category: entry.category,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      encryptedData: encrypted['encrypted'],
      entryIv: encrypted['iv'],
      entryTag: encrypted['tag'],
    );
  }

  static VaultEntry _decryptEntry(VaultEntry entry, Uint8List derivedKey) {
    if (!entry.isEntryEncrypted) return entry;

    final decryptedJson = EncryptionService.decryptWithKey(
      encryptedContent: entry.encryptedData!,
      ivBase64: entry.entryIv!,
      tagBase64: entry.entryTag!,
      rawKey: derivedKey,
    );

    final fields = jsonDecode(decryptedJson) as Map<String, dynamic>;

    return VaultEntry(
      id: entry.id,
      type: entry.type,
      title: entry.title,
      category: entry.category,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      username: fields['username'] as String?,
      password: fields['password'] as String?,
      website: fields['website'] as String?,
      content: fields['content'] as String?,
    );
  }

  // --- Key Derivation ---

  /// Derive the session key from master password + vault header salt.
  /// Call this once at login, then store the result in SessionService.
  static Uint8List deriveSessionKey(String masterPassword, Map<String, dynamic> vault) {
    final header = vault['header'] as Map<String, dynamic>;
    final salt = base64Decode(header['salt'] as String);
    return EncryptionService.deriveKey(masterPassword, Uint8List.fromList(salt));
  }

  // --- ZIP helpers (v4 format: key-based, no outer salt) ---

  static bool _isZipFile(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  static const _allowedZipEntries = {'manifest.json', 'encryption.json', 'vault.enc'};

  static bool _isZipEntrySafe(String name) {
    if (name.contains('..') || name.startsWith('/') || name.contains('\\')) {
      return false;
    }
    return _allowedZipEntries.contains(name);
  }

  /// Build ZIP archive using pre-derived session key (v4 format).
  /// The kdf_salt from the vault header is stored in the manifest so
  /// the key can be re-derived from password at next login.
  static Uint8List _buildZipArchiveWithKey(Map<String, dynamic> vault, Uint8List rawKey) {
    final vaultJson = jsonEncode(vault);
    final encrypted = EncryptionService.encryptWithKey(vaultJson, rawKey);

    final header = vault['header'] as Map<String, dynamic>;
    final kdfSalt = header['salt'] as String;

    final manifest = {
      'format': 'pgvault',
      'version': _formatVersionV4,
      'kdf_salt': kdfSalt,
      'created_at': DateTime.now().toIso8601String(),
      'entry_count': (vault['entries'] as List?)?.length ?? 0,
      'app': 'PassGuard Vault',
    };

    final encryptionParams = {
      'iv': encrypted['iv'],
      'tag': encrypted['tag'],
      'algorithm': 'AES-256-GCM',
    };

    final archive = Archive();
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
    final encParamsBytes = utf8.encode(jsonEncode(encryptionParams));
    archive.addFile(ArchiveFile('encryption.json', encParamsBytes.length, encParamsBytes));
    final encDataBytes = utf8.encode(encrypted['encrypted']!);
    archive.addFile(ArchiveFile('vault.enc', encDataBytes.length, encDataBytes));

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Decrypt a v4 ZIP archive using pre-derived session key.
  static Map<String, dynamic> _readZipArchiveWithKey(Uint8List bytes, Uint8List rawKey) {
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      if (!_isZipEntrySafe(file.name)) {
        throw Exception('Invalid .pgvault file: unexpected entry');
      }
    }

    final encryptionFile = archive.findFile('encryption.json');
    final vaultEncFile = archive.findFile('vault.enc');

    if (encryptionFile == null || vaultEncFile == null) {
      throw Exception('Invalid .pgvault file: missing required components');
    }

    final encParams = jsonDecode(utf8.decode(encryptionFile.content as List<int>));
    final encryptedContent = utf8.decode(vaultEncFile.content as List<int>);

    final decrypted = EncryptionService.decryptWithKey(
      encryptedContent: encryptedContent,
      ivBase64: encParams['iv'],
      tagBase64: encParams['tag'],
      rawKey: rawKey,
    );

    return jsonDecode(decrypted);
  }

  /// Decrypt a v3 ZIP archive using master password (one-time at login for old vaults).
  static Map<String, dynamic> _readZipArchiveV3(Uint8List bytes, String masterPassword) {
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      if (!_isZipEntrySafe(file.name)) {
        throw Exception('Invalid .pgvault file: unexpected entry');
      }
    }

    final manifestFile = archive.findFile('manifest.json');
    final encryptionFile = archive.findFile('encryption.json');
    final vaultEncFile = archive.findFile('vault.enc');

    if (manifestFile == null || encryptionFile == null || vaultEncFile == null) {
      throw Exception('Invalid .pgvault file: missing required components');
    }

    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    if (manifest['format'] != 'pgvault') {
      throw Exception('Invalid .pgvault file: unknown format');
    }

    final encParams = jsonDecode(utf8.decode(encryptionFile.content as List<int>));
    final encryptedContent = utf8.decode(vaultEncFile.content as List<int>);

    final decrypted = EncryptionService.decryptContent(
      encryptedContent: encryptedContent,
      ivBase64: encParams['iv'],
      saltBase64: encParams['salt'],
      masterPassword: masterPassword,
      tagBase64: encParams['tag'],
    );

    return jsonDecode(decrypted);
  }

  // --- Core Vault Operations ---

  /// Create a new vault. Call deriveSessionKey() afterwards to get the session key.
  static Map<String, dynamic> createNewVault(String masterPassword) {
    final header = EncryptionService.createVaultHeader(masterPassword);
    return {
      'header': header,
      'entries': <Map<String, dynamic>>[],
    };
  }

  /// Save vault using the pre-derived session key (v4 format).
  static Future<void> saveVault(Map<String, dynamic> vault, Uint8List rawKey) async {
    try {
      final zipBytes = _buildZipArchiveWithKey(vault, rawKey);
      final filePath = await _getVaultFilePath();
      await File(filePath).writeAsBytes(zipBytes);
      await _lockFilePermissions(filePath);
    } catch (e) {
      throw Exception('Failed to save vault');
    }
  }

  /// Load vault using master password. Handles both v3 and v4 formats.
  /// After calling this, call deriveSessionKey() and store in SessionService.
  static Future<Map<String, dynamic>> loadVault(String masterPassword) async {
    try {
      final filePath = await _getVaultFilePath();
      final file = File(filePath);
      if (!await file.exists()) throw Exception('Vault file not found');

      final bytes = await file.readAsBytes();

      if (_isZipFile(bytes)) {
        // Peek at manifest to determine format version
        final archive = ZipDecoder().decodeBytes(bytes);
        final manifestFile = archive.findFile('manifest.json');
        if (manifestFile != null) {
          final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
          final version = manifest['version'] as int? ?? 3;

          if (version >= _formatVersionV4) {
            // v4: derive key from kdf_salt in manifest
            final kdfSalt = base64Decode(manifest['kdf_salt'] as String);
            final key = EncryptionService.deriveKey(masterPassword, Uint8List.fromList(kdfSalt));
            return _readZipArchiveWithKey(bytes, key);
          }
        }
        // v3 fallback
        return _readZipArchiveV3(bytes, masterPassword);
      }

      // Legacy plain JSON format
      final encryptedJson = utf8.decode(bytes);
      final encryptedData = jsonDecode(encryptedJson);
      final decrypted = EncryptionService.decryptContent(
        encryptedContent: encryptedData['encrypted'],
        ivBase64: encryptedData['iv'],
        saltBase64: encryptedData['salt'],
        masterPassword: masterPassword,
        tagBase64: encryptedData['tag'],
      );
      return jsonDecode(decrypted);
    } catch (e) {
      throw Exception('Failed to load vault');
    }
  }

  /// Load vault using the pre-derived session key (v4 format only).
  static Future<Map<String, dynamic>> _loadVaultWithKey(Uint8List rawKey) async {
    try {
      final filePath = await _getVaultFilePath();
      final bytes = await File(filePath).readAsBytes();
      if (!_isZipFile(bytes)) throw Exception('Not a valid vault file');
      return _readZipArchiveWithKey(bytes, rawKey);
    } catch (e) {
      throw Exception('Failed to load vault');
    }
  }

  static Future<bool> vaultExists() async {
    try {
      final filePath = await _getVaultFilePath();
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  static Future<void> deleteVault() async {
    try {
      final filePath = await _getVaultFilePath();
      final file = File(filePath);
      if (await file.exists()) await file.delete();
    } catch (e) {
      throw Exception('Failed to delete vault');
    }
  }

  // --- Entry CRUD (all take pre-derived rawKey) ---

  static Future<void> addEntry(VaultEntry entry, Uint8List rawKey) async {
    try {
      final vault = await _loadVaultWithKey(rawKey);
      final entries = List<Map<String, dynamic>>.from(vault['entries']);
      final encryptedEntry = _encryptEntry(entry, rawKey);
      entries.add(encryptedEntry.toEncryptedJson());
      vault['entries'] = entries;
      await saveVault(vault, rawKey);
    } catch (e) {
      throw Exception('Failed to add entry');
    }
  }

  static Future<void> updateEntry(VaultEntry entry, Uint8List rawKey) async {
    try {
      final vault = await _loadVaultWithKey(rawKey);
      final entries = List<Map<String, dynamic>>.from(vault['entries']);
      final index = entries.indexWhere((e) => e['id'] == entry.id);
      if (index != -1) {
        final encryptedEntry = _encryptEntry(entry, rawKey);
        entries[index] = encryptedEntry.toEncryptedJson();
        vault['entries'] = entries;
        await saveVault(vault, rawKey);
      } else {
        throw Exception('Entry not found');
      }
    } catch (e) {
      throw Exception('Failed to update entry');
    }
  }

  static Future<void> deleteEntry(String entryId, Uint8List rawKey) async {
    try {
      final vault = await _loadVaultWithKey(rawKey);
      final entries = List<Map<String, dynamic>>.from(vault['entries']);
      final index = entries.indexWhere((e) => e['id'] == entryId);
      if (index != -1) {
        entries.removeAt(index);
        vault['entries'] = entries;
        await saveVault(vault, rawKey);
      } else {
        throw Exception('Entry not found');
      }
    } catch (e) {
      throw Exception('Failed to delete entry');
    }
  }

  static Future<List<VaultEntry>> getAllEntries(Uint8List rawKey) async {
    try {
      final vault = await _loadVaultWithKey(rawKey);
      final entriesJson = vault['entries'] as List<dynamic>;
      return entriesJson.map((json) {
        final entry = VaultEntry.fromJson(json);
        return _decryptEntry(entry, rawKey);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get entries');
    }
  }

  static Future<List<VaultEntry>> searchEntries(String query, Uint8List rawKey) async {
    try {
      final allEntries = await getAllEntries(rawKey);
      final queryLower = query.toLowerCase();
      return allEntries.where((entry) {
        return entry.title.toLowerCase().contains(queryLower) ||
            entry.category.toLowerCase().contains(queryLower) ||
            (entry.username?.toLowerCase().contains(queryLower) ?? false) ||
            (entry.website?.toLowerCase().contains(queryLower) ?? false) ||
            (entry.content?.toLowerCase().contains(queryLower) ?? false);
      }).toList();
    } catch (e) {
      throw Exception('Failed to search entries');
    }
  }

  static Future<List<VaultEntry>> filterByCategory(String category, Uint8List rawKey) async {
    try {
      final allEntries = await getAllEntries(rawKey);
      return allEntries
          .where((entry) => entry.category.toLowerCase() == category.toLowerCase())
          .toList();
    } catch (e) {
      throw Exception('Failed to filter entries');
    }
  }

  static Future<Map<String, dynamic>> getVaultStats(Uint8List rawKey) async {
    try {
      final entries = await getAllEntries(rawKey);
      final passwordCount = entries.where((e) => e.type == VaultEntryType.password).length;
      final noteCount = entries.where((e) => e.type == VaultEntryType.note).length;
      final categories = entries.map((e) => e.category).toSet();
      return {
        'total_entries': entries.length,
        'password_count': passwordCount,
        'note_count': noteCount,
        'categories': categories.length,
        'categories_list': categories.toList(),
      };
    } catch (e) {
      throw Exception('Failed to get vault stats');
    }
  }

  // --- Master Password Change ---

  static Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Load with current password (handles v3 and v4)
    final vault = await loadVault(currentPassword);
    final oldKey = deriveSessionKey(currentPassword, vault);

    // Decrypt all entries with old key
    final entriesJson = vault['entries'] as List<dynamic>;
    final decryptedEntries = entriesJson.map((json) {
      final entry = VaultEntry.fromJson(json);
      return _decryptEntry(entry, oldKey);
    }).toList();

    // New vault header with new password
    final newHeader = EncryptionService.createVaultHeader(newPassword);
    final newSalt = base64Decode(newHeader['salt'] as String);
    final newKey = EncryptionService.deriveKey(newPassword, Uint8List.fromList(newSalt));

    // Re-encrypt all entries
    final reEncryptedEntries = decryptedEntries.map((entry) {
      return _encryptEntry(entry, newKey).toEncryptedJson();
    }).toList();

    final newVault = {'header': newHeader, 'entries': reEncryptedEntries};
    await saveVault(newVault, newKey);

    // Update session with new key
    await SessionService.setSessionKey(newKey);
  }

  // --- Backup & Import ---

  static Future<String> createBackup(Uint8List rawKey) async {
    final vault = await _loadVaultWithKey(rawKey);
    final zipBytes = _buildZipArchiveWithKey(vault, rawKey);

    final dir = await _getVaultDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final backupPath = '${dir.path}/passguard_backup_$timestamp.pgvault';
    await File(backupPath).writeAsBytes(zipBytes);
    await _lockFilePermissions(backupPath);
    return backupPath;
  }

  static Future<Map<String, dynamic>?> readBackupManifest(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      if (!_isZipFile(bytes)) return null;
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) return null;
      return jsonDecode(utf8.decode(manifestFile.content as List<int>));
    } catch (e) {
      return null;
    }
  }

  static Future<ImportResult> importBackup({
    required String filePath,
    required Uint8List rawKey,
    required ImportMode mode,
  }) async {
    final fileSize = await File(filePath).length();
    if (fileSize > _maxImportFileSize) throw Exception('Import file too large');

    final bytes = await File(filePath).readAsBytes();
    if (!_isZipFile(bytes)) throw Exception('Not a valid .pgvault file');

    // Try v4 format first, fall back to v3
    Map<String, dynamic> importedVault;
    try {
      importedVault = _readZipArchiveWithKey(bytes, rawKey);
    } catch (_) {
      throw Exception('Cannot import: incompatible vault format or wrong key');
    }

    if (mode == ImportMode.replace) {
      await saveVault(importedVault, rawKey);
      final entries = importedVault['entries'] as List;
      return ImportResult(imported: entries.length, skipped: 0, total: entries.length);
    }

    // Merge mode
    final currentVault = await _loadVaultWithKey(rawKey);
    final currentEntries = List<Map<String, dynamic>>.from(currentVault['entries']);
    final importEntries = List<Map<String, dynamic>>.from(importedVault['entries']);
    final existingIds = currentEntries.map((e) => e['id']).toSet();

    int imported = 0;
    int skipped = 0;
    for (final entry in importEntries) {
      if (existingIds.contains(entry['id'])) {
        skipped++;
      } else {
        currentEntries.add(entry);
        imported++;
      }
    }
    currentVault['entries'] = currentEntries;
    await saveVault(currentVault, rawKey);
    return ImportResult(imported: imported, skipped: skipped, total: importEntries.length);
  }
}
