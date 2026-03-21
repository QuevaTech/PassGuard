import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:passguard_vault_v0/services/vault_service.dart';
import 'package:passguard_vault_v0/services/biometric_service.dart';
import 'package:passguard_vault_v0/services/session_service.dart';
import 'package:passguard_vault_v0/services/clipboard_service.dart';
import 'package:passguard_vault_v0/services/password_generator_service.dart';
import '../../utils/app_localizations.dart';
import '../../utils/app_theme.dart';

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
  String _themeMode = 'system';
  String _language = 'tr';
  bool _autoLockEnabled = true;
  int _autoLockMinutes = 5;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _biometricAvailable = await _biometricService.isBiometricAvailable();
      _biometricEnrolled = await _biometricService.isBiometricEnrolled();
      _biometricEnabled = _biometricAvailable && _biometricEnrolled;
    } catch (e) {
      // Handle error
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

  Future<void> _exportVault() async {
    final rawKey = _getSessionKey();
    if (rawKey == null) return;

    try {
      setState(() => _isExporting = true);

      final backupPath = await VaultService.createBackup(rawKey);

      setState(() => _isExporting = false);

      // Share the backup file
      await Share.shareXFiles(
        [XFile(backupPath)],
        subject: 'PassGuard Vault Backup',
      );

      if (mounted) {
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
    }
  }

  Future<void> _importVault() async {
    final rawKey = _getSessionKey();
    if (rawKey == null) return;

    // 1. Pick .pgvault file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

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
    try {
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
    }
  }

  Future<ImportMode?> _showImportModeDialog(Map<String, dynamic> manifest) async {
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
            child: Text(localizations.replace, style: const TextStyle(color: Colors.white)),
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
                      icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
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
                      icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
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
                      icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
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
                  setDialogState(() => errorText = localizations.enterMasterPassword);
                  return;
                }
                if (newController.text.length < 8) {
                  setDialogState(() => errorText = localizations.passwordTooShort);
                  return;
                }
                if (newController.text != confirmController.text) {
                  setDialogState(() => errorText = localizations.passwordMismatch);
                  return;
                }
                if (newController.text == currentController.text) {
                  setDialogState(() => errorText = localizations.newPasswordSameAsOld);
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
                _buildStatRow('Total Entries', stats['total_entries'].toString()),
                _buildStatRow('Passwords', stats['password_count'].toString()),
                _buildStatRow('Notes', stats['note_count'].toString()),
                _buildStatRow('Categories', stats['categories'].toString()),
                const SizedBox(height: 16),
                Text(
                  'Categories:',
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
                  onChanged: (value) {
                    setState(() {
                      _biometricEnabled = value;
                      if (value) {
                        SessionService.extendSession();
                      } else {
                        SessionService.shortenSession();
                      }
                    });
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
                      SessionService.initialize(timeout: Duration(minutes: _autoLockMinutes));
                    } else {
                      SessionService.initialize(timeout: Duration(hours: 1));
                    }
                  });
                },
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
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
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
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.restore),
              title: Text(localizations.importVault),
              subtitle: Text(localizations.importVaultDesc),
              onTap: _isImporting ? null : _importVault,
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
              title: Text('${localizations.version}: 1.0.0'),
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
