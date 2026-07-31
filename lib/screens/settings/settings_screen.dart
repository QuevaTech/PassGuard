import 'dart:io';
import 'dart:typed_data';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:passguard_vault/services/vault_service.dart';
import 'package:passguard_vault/services/biometric_service.dart';
import 'package:passguard_vault/services/session_service.dart';
import 'package:passguard_vault/services/clipboard_service.dart';
import 'package:passguard_vault/services/password_generator_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/app_localizations.dart';
import '../../utils/vault_exceptions.dart';
import '../../providers/theme_provider.dart'
    show
        themeProvider,
        appThemeStyleProvider,
        accentColorProvider,
        accentColors;
import '../../theme/app_theme_style.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/glass_card.dart';
import '../../services/pin_service.dart';
import '../auth/pin_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _biometricEnrolled = false;
  bool _pinEnabled = false;
  bool _autoLockEnabled = true;
  int _autoLockMinutes = 5;
  bool _isExporting = false;
  bool _isImporting = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final available = await _biometricService.isBiometricAvailable();
      final enrolled = await _biometricService.isBiometricEnrolled();
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool('biometric_enabled') ?? false;
      final pinEnabled = await PinService.isPinEnabled();
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _biometricAvailable = available;
          _biometricEnrolled = enrolled;
          _biometricEnabled = available && enrolled && saved;
          _pinEnabled = pinEnabled;
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      // Biometric not available on this device — keep defaults (false)
    }
  }

  Uint8List? _getSessionKey() {
    final key = SessionService.getSessionKey();
    if (key == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).sessionTimeout),
          backgroundColor: Colors.red,
        ),
      );
    }
    return key;
  }

  /// Returns false (and shows a snackbar) if we're on Linux and neither
  /// zenity nor kdialog is installed — file_picker requires one of them.
  Future<bool> _ensureLinuxFilePicker() async {
    if (!Platform.isLinux) return true;
    final zenity = await Process.run('which', ['zenity']);
    if (zenity.exitCode == 0) return true;
    final kdialog = await Process.run('which', ['kdialog']);
    if (kdialog.exitCode == 0) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).filePickerUnavailable),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
    return false;
  }

  Future<String> _fallbackExportPath(String fileName) async {
    final normalizedName = fileName.toLowerCase().endsWith('.pgvault')
        ? fileName
        : '$fileName.pgvault';

    Directory? targetDir;
    try {
      targetDir = await getDownloadsDirectory();
    } catch (_) {
      targetDir = null;
    }

    targetDir ??= await getApplicationDocumentsDirectory();
    return '${targetDir.path}${Platform.pathSeparator}$normalizedName';
  }

  Future<void> _exportVault() async {
    final rawKey = _getSessionKey();
    if (rawKey == null) return;
    if (!await _ensureLinuxFilePicker()) return;

    String? backupPath;
    try {
      setState(() => _isExporting = true);

      backupPath = await VaultService.createBackup(rawKey);

      setState(() => _isExporting = false);

      // Desktop: Save As dialog; Mobile: share sheet
      final isDesktop =
          Platform.isMacOS || Platform.isWindows || Platform.isLinux;
      bool exported = false;
      final fileName = backupPath.split(Platform.pathSeparator).last;
      if (isDesktop) {
        String? savePath;
        try {
          savePath = await FilePicker.platform.saveFile(
            dialogTitle: AppLocalizations.of(context).backupVault,
            fileName: fileName,
            allowedExtensions: ['pgvault'],
            type: FileType.custom,
          );
        } catch (_) {
          // On some Windows setups Save As can fail; we'll fall back below.
        }

        if (savePath == null || savePath.trim().isEmpty) {
          savePath = await _fallbackExportPath(fileName);
        }

        if (savePath != null && savePath.trim().isNotEmpty) {
          final normalizedPath = savePath.toLowerCase().endsWith('.pgvault')
              ? savePath
              : '$savePath.pgvault';
          await File(backupPath).copy(normalizedPath);
          exported = true;
        }
        // User cancelled the Save As dialog — no snackbar
      } else {
        try {
          final size = MediaQuery.of(context).size;
          await Share.shareXFiles(
            [XFile(backupPath)],
            subject: AppLocalizations.of(context).backupVault,
            sharePositionOrigin: Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2),
              width: 1,
              height: 1,
            ),
          );
          exported = true;
        } catch (_) {
          final fallbackPath = await _fallbackExportPath(fileName);
          await File(backupPath).copy(fallbackPath);
          exported = true;
        }
      }

      if (exported && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).exportSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).exportFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Remove the intermediate backup file from the vault directory.
      // The user's chosen copy (or share) is the real export — this temp file
      // would otherwise accumulate in AppData/.passguard on every export.
      if (backupPath != null) {
        try {
          await File(backupPath).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _importVault() async {
    final rawKey = _getSessionKey();
    if (rawKey == null) return;
    if (!await _ensureLinuxFilePicker()) return;

    // 1. Pick .pgvault file
    // withData: true on Android so bytes are available when path is null
    // (content:// URIs from Drive/Downloads do not expose a real file path)
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pgvault'],
      allowMultiple: false,
      withData: Platform.isAndroid,
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    String? filePath = pickedFile.path;
    File? tempFile;

    // On Android, path is null for content:// URIs (e.g. Google Drive, Downloads).
    // Write bytes to a temp file so the rest of the flow stays path-based.
    if (filePath == null) {
      final bytes = pickedFile.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).importFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final tmpDir = await getTemporaryDirectory();
      tempFile = File(
        '${tmpDir.path}/pg_import_${DateTime.now().millisecondsSinceEpoch}.pgvault',
      );
      await tempFile.writeAsBytes(bytes);
      filePath = tempFile.path;
    }

    try {
      // 2. Validate - read manifest
      final manifest = await VaultService.readBackupManifest(filePath);
      if (manifest == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).importFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 3. Show import mode dialog
      if (!mounted) return;
      final mode = await _showImportModeDialog(manifest);
      if (mode == null) return;

      // 4. Import
      setState(() => _isImporting = true);

      final importResult = await VaultService.importBackup(
        filePath: filePath,
        rawKey: rawKey,
        mode: mode,
      );

      setState(() => _isImporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).importSuccess} '
              '(${importResult.imported} ${AppLocalizations.of(context).imported}, '
              '${importResult.skipped} ${AppLocalizations.of(context).skipped})',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).importFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Clean up temp file if one was created for the Android content:// case
      try {
        await tempFile?.delete();
      } catch (_) {}
    }
  }

  Future<void> _importCsv() async {
    final rawKey = _getSessionKey();
    if (rawKey == null) return;
    if (!await _ensureLinuxFilePicker()) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
      withData: Platform.isAndroid,
    );
    if (result == null || result.files.isEmpty) return;

    final pickedFile = result.files.single;
    String? filePath = pickedFile.path;
    File? tempFile;

    if (filePath == null) {
      final bytes = pickedFile.bytes;
      if (bytes == null) return;
      final tmpDir = await getTemporaryDirectory();
      tempFile = File(
          '${tmpDir.path}/pg_csv_${DateTime.now().millisecondsSinceEpoch}.csv');
      await tempFile.writeAsBytes(bytes);
      filePath = tempFile.path;
    }

    try {
      setState(() => _isImporting = true);
      final importResult =
          await VaultService.importCsv(csvPath: filePath, rawKey: rawKey);
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).importSuccess} '
              '(${importResult.imported} ${AppLocalizations.of(context).imported}, '
              '${importResult.skipped} ${AppLocalizations.of(context).skipped})',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is CsvFormatUnsupportedException
                ? AppLocalizations.of(context).csvFormatUnsupported
                : AppLocalizations.of(context).importFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      try {
        await tempFile?.delete();
      } catch (_) {}
    }
  }

  Future<ImportMode?> _showImportModeDialog(
      Map<String, dynamic> manifest) async {
    final localizations = AppLocalizations.of(context);
    final entryCount = manifest['entry_count'] ?? '?';
    final createdAt = manifest['created_at'] ?? '?';
    final version = manifest['version'] ?? '?';

    return showDialog<ImportMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.importVault),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${localizations.entries}: $entryCount'),
            const SizedBox(height: 4),
            Text('${localizations.createdAt}: ${_formatDate(createdAt)}'),
            const SizedBox(height: 4),
            Text('Format v$version'),
            const SizedBox(height: 16),
            Text(localizations.importModeQuestion),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, ImportMode.merge),
            child: Text(localizations.merge),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ImportMode.replace),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(localizations.replace,
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoDate;
    }
  }

  Future<void> _changeMasterPassword() async {
    // changeMasterPassword derives keys internally from the provided passwords
    if (_getSessionKey() == null) return;

    final localizations = AppLocalizations.of(context);
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    try {
      bool obscureCurrent = true;
      bool obscureNew = true;
      bool obscureConfirm = true;
      String? errorText;

      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(localizations.changeMasterPassword),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentController,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: localizations.masterPassword,
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(obscureCurrent
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setDialogState(
                            () => obscureCurrent = !obscureCurrent),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: localizations.newMasterPassword,
                      prefixIcon: const Icon(Icons.vpn_key),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () =>
                            setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: localizations.confirmMasterPassword,
                      prefixIcon: const Icon(Icons.vpn_key),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () => setDialogState(
                            () => obscureConfirm = !obscureConfirm),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(localizations.cancel),
              ),
              ElevatedButton(
                onPressed: () {
                  if (currentController.text.isEmpty ||
                      newController.text.isEmpty ||
                      confirmController.text.isEmpty) {
                    setDialogState(
                        () => errorText = localizations.enterMasterPassword);
                    return;
                  }
                  if (newController.text.length < 8) {
                    setDialogState(
                        () => errorText = localizations.passwordTooShort);
                    return;
                  }
                  if (newController.text != confirmController.text) {
                    setDialogState(
                        () => errorText = localizations.passwordMismatch);
                    return;
                  }
                  if (newController.text == currentController.text) {
                    setDialogState(
                        () => errorText = localizations.newPasswordSameAsOld);
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: Text(localizations.save),
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) return;

      try {
        setState(() => _isExporting = true); // reuse loading state

        await VaultService.changeMasterPassword(
          currentPassword: currentController.text,
          newPassword: newController.text,
        );

        if (mounted) {
          setState(() => _isExporting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.passwordChanged),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isExporting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.somethingWentWrong),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
    }
  }

  Future<void> _clearClipboard() async {
    try {
      await ClipboardService.clearClipboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).copied),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).somethingWentWrong),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateTestPassword() async {
    try {
      final password = PasswordGeneratorService.generatePassword(
        length: 16,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: true,
        includeSymbols: true,
      );
      await ClipboardService.copyPassword(password);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).passwordCopied),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).somethingWentWrong),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showVaultStats() async {
    final rawKey = _getSessionKey();
    if (rawKey == null) return;

    try {
      final stats = await VaultService.getVaultStats(rawKey);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppLocalizations.of(context).vaultHealth),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatRow(AppLocalizations.of(context).entries,
                    stats['total_entries'].toString()),
                _buildStatRow(AppLocalizations.of(context).passwords,
                    stats['password_count'].toString()),
                _buildStatRow(AppLocalizations.of(context).notes,
                    stats['note_count'].toString()),
                _buildStatRow(AppLocalizations.of(context).categories,
                    stats['categories'].toString()),
                const SizedBox(height: 16),
                Text(
                  '${AppLocalizations.of(context).categories}:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...List.generate(
                  stats['categories_list'].length,
                  (index) => Text('• ${stats['categories_list'][index]}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).ok),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).somethingWentWrong),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return AppScaffold(
      appBar: AppBar(
        title: Text(localizations.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Security Section
          _buildSectionHeader(localizations.security_features),
          const SizedBox(height: 8),

          // Biometric Authentication
          if (_biometricAvailable && _biometricEnrolled)
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.fingerprint,
                  color: _biometricEnabled ? Colors.green : Colors.grey,
                ),
                title: Text(localizations.biometricAuth),
                subtitle: Text(
                  _biometricEnabled
                      ? localizations.biometricEnabled
                      : localizations.biometricDisabled,
                ),
                trailing: Switch(
                  value: _biometricEnabled,
                  onChanged: (value) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('biometric_enabled', value);
                    SessionService.setBiometricEnabled(value);
                    if (mounted) {
                      setState(() {
                        _biometricEnabled = value;
                        if (value) {
                          SessionService.extendSession();
                        } else {
                          SessionService.shortenSession();
                        }
                      });
                    }
                  },
                ),
              ),
            ),
          const SizedBox(height: 8),

          // PIN Lock
          Card(
            child: ListTile(
              leading: Icon(
                Icons.pin_outlined,
                color: _pinEnabled ? Colors.blue : Colors.grey,
              ),
              title: const Text('PIN Lock'),
              subtitle: Text(_pinEnabled
                  ? 'PIN is enabled'
                  : 'Quick unlock with a 4-digit PIN'),
              trailing: _pinEnabled
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Remove PIN',
                      onPressed: () async {
                        await PinService.disablePin();
                        if (mounted) setState(() => _pinEnabled = false);
                      },
                    )
                  : TextButton(
                      child: const Text('Set PIN'),
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const PinScreen(mode: PinScreenMode.setup),
                          ),
                        );
                        if (result == true && mounted) {
                          setState(() => _pinEnabled = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN set successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),

          // Auto Lock
          Card(
            child: ListTile(
              leading: Icon(
                _autoLockEnabled ? Icons.lock : Icons.lock_open,
                color: _autoLockEnabled ? Colors.red : Colors.green,
              ),
              title: Text(localizations.autoLock),
              subtitle: Text('$_autoLockMinutes ${localizations.minutes}'),
              trailing: Switch(
                value: _autoLockEnabled,
                onChanged: (value) {
                  setState(() {
                    _autoLockEnabled = value;
                    if (value) {
                      SessionService.initialize(
                          timeout: Duration(minutes: _autoLockMinutes));
                    } else {
                      SessionService.initialize(
                          timeout: const Duration(hours: 1));
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Theme
          _buildSectionHeader(localizations.theme),
          const SizedBox(height: 8),
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.palette_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        localizations.theme,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ThemeModePicker(
                    selected: ref.watch(themeProvider),
                    onSelected: (mode) =>
                        ref.read(themeProvider.notifier).setMode(mode),
                  ),
                  const SizedBox(height: 18),
                  Divider(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.10),
                  ),
                  const SizedBox(height: 12),
                  Text(localizations.accentColor,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  _AccentColorPicker(
                    selected: ref.watch(accentColorProvider),
                    onSelected: (c) =>
                        ref.read(accentColorProvider.notifier).setColor(c),
                  ),
                  const SizedBox(height: 18),
                  Divider(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.10),
                  ),
                  const SizedBox(height: 12),
                  Text('${localizations.theme} Style',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  _ThemeStylePicker(
                    selected: ref.watch(appThemeStyleProvider),
                    onSelected: (s) =>
                        ref.read(appThemeStyleProvider.notifier).setStyle(s),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Vault Backup
          _buildSectionHeader(localizations.vault_backup),
          const SizedBox(height: 8),

          // Export Backup (.pgvault)
          Card(
            child: ListTile(
              leading: _isExporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.backup),
              title: Text(localizations.exportVault),
              subtitle: Text(localizations.exportVaultDesc),
              onTap: _isExporting ? null : _exportVault,
            ),
          ),
          const SizedBox(height: 8),

          // Import Backup (.pgvault)
          Card(
            child: ListTile(
              leading: _isImporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.restore),
              title: Text(localizations.importVault),
              subtitle: Text(localizations.importVaultDesc),
              onTap: _isImporting ? null : _importVault,
            ),
          ),
          const SizedBox(height: 8),

          // CSV Import (Bitwarden / Chrome / 1Password)
          Card(
            child: ListTile(
              leading: _isImporting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.table_chart_outlined),
              title: Text(localizations.importCsv),
              subtitle: Text(localizations.importCsvDesc),
              onTap: _isImporting ? null : _importCsv,
            ),
          ),
          const SizedBox(height: 16),

          // Tools Section
          _buildSectionHeader(localizations.quick_tools),
          const SizedBox(height: 8),

          // Generate Test Password
          Card(
            child: ListTile(
              leading: const Icon(Icons.password),
              title: Text(localizations.generatePassword),
              onTap: _generateTestPassword,
            ),
          ),
          const SizedBox(height: 8),

          // Clear Clipboard
          Card(
            child: ListTile(
              leading: const Icon(Icons.clear_all),
              title: Text(localizations.clear),
              onTap: _clearClipboard,
            ),
          ),
          const SizedBox(height: 8),

          // Vault Statistics
          Card(
            child: ListTile(
              leading: const Icon(Icons.analytics),
              title: Text(localizations.vault_health),
              onTap: _showVaultStats,
            ),
          ),
          const SizedBox(height: 16),

          // Account Section
          _buildSectionHeader(localizations.about),
          const SizedBox(height: 8),

          // Change Master Password
          Card(
            child: ListTile(
              leading: const Icon(Icons.vpn_key),
              title: Text(localizations.change_master_password),
              onTap: _changeMasterPassword,
            ),
          ),
          const SizedBox(height: 8),

          // App Version
          Card(
            child: ListTile(
              leading: const Icon(Icons.info),
              title: Text('${localizations.version}: $_appVersion'),
              subtitle: Text(localizations.app_name),
            ),
          ),
          const SizedBox(height: 8),

          // Developer Info
          Card(
            child: ListTile(
              leading: const Icon(Icons.code),
              title: const Text('quevatech | queva.tech'),
              subtitle: Text(localizations.developer),
            ),
          ),
          const SizedBox(height: 8),

          // Report Bug
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: Text(localizations.reportBug),
              subtitle: Text(localizations.reportBugDesc),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () async {
                final uri = Uri.parse(
                    'https://github.com/QuevaTech/PassGuard/issues/new');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker({
    required this.selected,
    required this.onSelected,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Row(
      children: [
        _ThemeModeOption(
          mode: ThemeMode.light,
          icon: Icons.light_mode_rounded,
          label: localizations.lightTheme,
          selected: selected == ThemeMode.light,
          onTap: onSelected,
        ),
        const SizedBox(width: 8),
        _ThemeModeOption(
          mode: ThemeMode.system,
          icon: Icons.brightness_auto_rounded,
          label: localizations.systemTheme,
          selected: selected == ThemeMode.system,
          onTap: onSelected,
        ),
        const SizedBox(width: 8),
        _ThemeModeOption(
          mode: ThemeMode.dark,
          icon: Icons.dark_mode_rounded,
          label: localizations.darkTheme,
          selected: selected == ThemeMode.dark,
          onTap: onSelected,
        ),
      ],
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.mode,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<ThemeMode> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.62);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => onTap(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? accent.withValues(alpha: 0.55)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 21, color: selected ? accent : muted),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected ? accent : muted,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accent colour picker — round swatches (Vault & Stratum only; Cipher ignores)
// ---------------------------------------------------------------------------

class _AccentColorPicker extends StatelessWidget {
  const _AccentColorPicker({
    required this.selected,
    required this.onSelected,
  });

  final Color selected;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: accentColors.map((color) {
        final isSelected = selected.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => onSelected(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            margin: const EdgeInsets.only(right: 14),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: color, width: 2.5) : null,
            ),
            padding: EdgeInsets.all(isSelected ? 3.5 : 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]
                    : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme Style Picker — 3 visual cards (Vault, Stratum, Cipher)
// ---------------------------------------------------------------------------

class _ThemeStylePicker extends StatelessWidget {
  const _ThemeStylePicker({
    required this.selected,
    required this.onSelected,
  });

  final AppThemeStyle selected;
  final ValueChanged<AppThemeStyle> onSelected;

  static const _styles = AppThemeStyle.values;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _styles.map((style) {
        final isLast = style == _styles.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 10),
            child: _ThemeStyleCard(
              style: style,
              isSelected: selected == style,
              onTap: () => onSelected(style),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ThemeStyleCard extends StatelessWidget {
  final AppThemeStyle style;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeStyleCard({
    required this.style,
    required this.isSelected,
    required this.onTap,
  });

  // Static preview gradients — theme-independent, always shown in dark palette
  Gradient get _previewGradient {
    switch (style) {
      case AppThemeStyle.vault:
        return const RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [Color(0xFF2a2f54), Color(0xFF1b1f3b), Color(0xFF11142b)],
          stops: [0.0, 0.38, 1.0],
        );
      case AppThemeStyle.stratum:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14172e), Color(0xFF1b1f3b)],
        );
      case AppThemeStyle.cipher:
        return const RadialGradient(
          center: Alignment(-0.4, -1.0),
          radius: 1.2,
          colors: [Color(0xFF1a1f4a), Color(0xFF0a0e27), Color(0xFF050714)],
          stops: [0.0, 0.50, 1.0],
        );
    }
  }

  Color get _previewCardColor {
    switch (style) {
      case AppThemeStyle.vault:
        return const Color(0x8C23284B);
      case AppThemeStyle.stratum:
        return const Color(0xFF1e2240);
      case AppThemeStyle.cipher:
        return const Color(0x1A8B9BBF);
    }
  }

  Color get _previewAccent {
    switch (style) {
      case AppThemeStyle.vault:
        return const Color(0xFFD4B038);
      case AppThemeStyle.stratum:
        return const Color(0xFFD4B038);
      case AppThemeStyle.cipher:
        return const Color(0xFF00E5FF);
    }
  }

  String get _label {
    switch (style) {
      case AppThemeStyle.vault:
        return 'VAULT';
      case AppThemeStyle.stratum:
        return 'STRATUM';
      case AppThemeStyle.cipher:
        return 'CIPHER';
    }
  }

  String get _subtitle {
    switch (style) {
      case AppThemeStyle.vault:
        return 'Glass';
      case AppThemeStyle.stratum:
        return 'Editorial';
      case AppThemeStyle.cipher:
        return 'Cyberpunk';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _previewAccent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 0,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AspectRatio(
            aspectRatio: 0.72,
            child: Stack(
              children: [
                // Background preview
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(gradient: _previewGradient),
                  ),
                ),
                // Mini card bar
                Positioned(
                  top: 22,
                  left: 8,
                  right: 8,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: _previewCardColor,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.35), width: 0.5),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  left: 8,
                  right: 20,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: _previewCardColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Positioned(
                  top: 66,
                  left: 8,
                  right: 30,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: _previewCardColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                // Label footer
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xCC000000),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _label,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle, size: 11, color: accent),
                          ],
                        ),
                        Text(
                          _subtitle,
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
