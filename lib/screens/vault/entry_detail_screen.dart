import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:passguard_vault/services/vault_service.dart';
import 'package:passguard_vault/services/clipboard_service.dart';
import 'package:passguard_vault/services/password_generator_service.dart';
import 'package:passguard_vault/models/vault_entry.dart';
import 'add_entry_screen.dart';
import '../../utils/app_localizations.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/note_content_renderer.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/category_badge.dart';

class EntryDetailScreen extends ConsumerStatefulWidget {
  final VaultEntry entry;
  final Uint8List rawKey;

  const EntryDetailScreen({
    super.key,
    required this.entry,
    required this.rawKey,
  });

  @override
  ConsumerState<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends ConsumerState<EntryDetailScreen> {
  bool _obscurePassword = true;
  late VaultEntry _currentEntry;
  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
  }

  Future<void> _editEntry() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEntryScreen(
          rawKey: widget.rawKey,
          existingEntry: _currentEntry,
        ),
      ),
    );
    if (result == true) {
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _deleteEntry() async {
    final localizations = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteConfirmation),
        content:
            Text('${localizations.delete} "${_currentEntry.displayTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(localizations.yes),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      try {
        await VaultService.deleteEntry(_currentEntry.id, widget.rawKey);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_deletedEntryMessage(localizations)),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
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
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isPassword = _currentEntry.type == VaultEntryType.password;
    final isNote = _currentEntry.type == VaultEntryType.note;
    final isSshKey = _currentEntry.type == VaultEntryType.sshKey;

    return AppScaffold(
      appBar: AppBar(
        title: Text(_currentEntry.displayTitle),
        actions: [
          IconButton(
            onPressed: () async {
              final updated = _currentEntry.copyWith(
                isFavorite: !_currentEntry.isFavorite,
                updatedAt: DateTime.now(),
              );
              await VaultService.updateEntry(updated, widget.rawKey);
              setState(() => _currentEntry = updated);
            },
            icon: Icon(
              _currentEntry.isFavorite ? Icons.star : Icons.star_border,
              color: _currentEntry.isFavorite ? Colors.amber : null,
            ),
          ),
          IconButton(
            onPressed: _editEntry,
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: _deleteEntry,
            icon: const Icon(Icons.delete),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            // Entry Type Badge
            GlassCard(
              padding: const EdgeInsets.all(16),
              leftAccentColor: _currentEntry.color,
              child: Row(
                children: [
                  Icon(
                    _entryIcon(_currentEntry),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _entryTypeLabel(_currentEntry),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  CategoryBadge(
                    category: _currentEntry.displayCategory,
                    compact: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Basic Information
            _buildInfoCard(
              title: localizations.title,
              value: _currentEntry.displayTitle,
            ),
            const SizedBox(height: 16),

            // Password/Content Details
            if (isPassword) ...[
              // Username
              _buildInfoCard(
                title: localizations.username,
                value: _currentEntry.username ?? '-',
              ),
              const SizedBox(height: 16),

              // Password
              _buildPasswordCard(),
              const SizedBox(height: 16),

              // Website
              if (_currentEntry.website != null)
                _buildInfoCard(
                  title: localizations.website,
                  value: _currentEntry.website!,
                  isLink: true,
                ),
              const SizedBox(height: 16),
            ] else if (isNote) ...[
              // Content
              _buildContentCard(),
              const SizedBox(height: 16),
            ] else if (isSshKey) ...[
              _buildSecretValueCard(
                title: 'Private key',
                value: _currentEntry.privateKey ?? '',
                fileExtension: '.pem',
              ),
              const SizedBox(height: 16),
              _buildCodeValueCard(
                title: 'Public key',
                value: _currentEntry.publicKey ?? '',
                fileExtension: '.pub',
              ),
              if (_currentEntry.keyFingerprint != null) ...[
                const SizedBox(height: 16),
                _buildCodeValueCard(
                  title: 'Fingerprint',
                  value: _currentEntry.keyFingerprint!,
                  copyLabel: 'Fingerprint copied',
                ),
              ],
              const SizedBox(height: 16),
            ] else ...[
              if (_currentEntry.credentialKind != null) ...[
                _buildInfoCard(
                  title: 'Certificate type',
                  value: _currentEntry.credentialKind!,
                ),
                const SizedBox(height: 16),
              ],
              if (_currentEntry.certificateData != null &&
                  _currentEntry.certificateData!.isNotEmpty) ...[
                _buildCodeValueCard(
                  title: 'Certificate',
                  value: _currentEntry.certificateData!,
                  copyLabel: 'Certificate copied',
                  fileExtension: '.pem',
                ),
                const SizedBox(height: 16),
              ],
              if (_currentEntry.attachmentFileName != null)
                _buildAttachmentCard(),
            ],

            // Notes (if present)
            if (_currentEntry.notes != null &&
                _currentEntry.notes!.isNotEmpty) ...[
              _buildInfoCard(
                title: localizations.notes,
                value: _currentEntry.notes!,
              ),
              const SizedBox(height: 16),
            ],

            // Metadata
            _buildInfoCard(
              title: localizations.createdAt,
              value: _formatDateTime(_currentEntry.createdAt),
            ),
            const SizedBox(height: 16),

            _buildInfoCard(
              title: localizations.updatedAt,
              value: _formatDateTime(_currentEntry.updatedAt),
            ),
            const SizedBox(height: 16),

            // Actions
            if (isNote) _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    bool isLink = false,
  }) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context)
                          .extension<AppThemeExtension>()
                          ?.textSecondary ??
                      Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 4),
          if (isLink)
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                ClipboardService.copyWebsite(value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${AppLocalizations.of(context).websiteCopied} · 30s'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
              child: Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            )
          else
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard() {
    final password = _currentEntry.password ?? '';
    final strength = PasswordGeneratorService.calculateStrength(password);
    final strengthText = PasswordGeneratorService.getStrengthLevel(strength);
    final strengthColor = PasswordGeneratorService.getStrengthColor(strength);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).password,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context)
                                .extension<AppThemeExtension>()
                                ?.textSecondary ??
                            Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ClipboardService.copyPassword(password);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${AppLocalizations.of(context).passwordCopied} · 30s'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 20),
              ),
              IconButton(
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _obscurePassword ? '*' * password.length : password,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: strength / 100,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(strengthColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: Text(
                  '${strengthText.toUpperCase()} ($strength)',
                  style: TextStyle(
                    color: strengthColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    final content = _currentEntry.content ?? '';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).content,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context)
                          .extension<AppThemeExtension>()
                          ?.textSecondary ??
                      Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 8),
          NoteContentRenderer(content: content),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ClipboardService.copyContent(stripNoteTags(content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${AppLocalizations.of(context).contentCopied} · 30s'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecretValueCard({
    required String title,
    required String value,
    required String fileExtension,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context)
                                .extension<AppThemeExtension>()
                                ?.textSecondary ??
                            Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Copy private key',
                onPressed: value.isEmpty
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        ClipboardService.copyContent(value);
                        _showCopied('Private key copied');
                      },
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
              IconButton(
                tooltip: 'Export private key',
                onPressed: value.isEmpty
                    ? null
                    : () => _exportTextFile(
                          value,
                          fileExtension: fileExtension,
                          sensitive: true,
                        ),
                icon: const Icon(Icons.save_alt_rounded, size: 20),
              ),
              IconButton(
                tooltip:
                    _obscurePassword ? 'Show private key' : 'Hide private key',
                onPressed: () => setState(
                  () => _obscurePassword = !_obscurePassword,
                ),
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            value.isEmpty ? 'No private key saved' : _obscureValue(value),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeValueCard({
    required String title,
    required String value,
    String? copyLabel,
    String? fileExtension,
  }) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context)
                                .extension<AppThemeExtension>()
                                ?.textSecondary ??
                            Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                      ),
                ),
              ),
              IconButton(
                tooltip: 'Copy $title',
                onPressed: value.isEmpty
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        ClipboardService.copyContent(value);
                        _showCopied(copyLabel ?? '$title copied');
                      },
                icon: const Icon(Icons.copy_rounded, size: 20),
              ),
              if (fileExtension != null)
                IconButton(
                  tooltip: 'Export $title',
                  onPressed: value.isEmpty
                      ? null
                      : () => _exportTextFile(
                            value,
                            fileExtension: fileExtension,
                          ),
                  icon: const Icon(Icons.save_alt_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            value.isEmpty ? 'No value saved' : value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentCard() {
    final fileName = _currentEntry.attachmentFileName!;
    final hasBinaryFile = _currentEntry.attachmentBase64 != null;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  hasBinaryFile
                      ? 'Encrypted binary certificate file'
                      : 'Imported PEM certificate text',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (hasBinaryFile)
            IconButton(
              tooltip: 'Save certificate file',
              onPressed: _exportAttachment,
              icon: const Icon(Icons.save_alt_rounded),
            ),
        ],
      ),
    );
  }

  Future<void> _exportAttachment() async {
    final base64Data = _currentEntry.attachmentBase64;
    if (base64Data == null || base64Data.isEmpty) return;
    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save certificate file',
        fileName: _currentEntry.attachmentFileName ?? 'certificate.bin',
      );
      if (savePath == null || savePath.isEmpty) return;
      await File(savePath).writeAsBytes(base64Decode(base64Data), flush: true);
      if (!mounted) return;
      _showCopied('Certificate file saved');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Certificate file could not be saved.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _exportTextFile(
    String contents, {
    required String fileExtension,
    bool sensitive = false,
  }) async {
    if (sensitive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export private key?'),
          content: const Text(
            'The exported file will be outside the encrypted vault. '
            'Protect it with a passphrase before using or sharing it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Export'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export file',
        fileName: '${_safeFileStem()}$fileExtension',
      );
      if (savePath == null || savePath.isEmpty) return;
      await File(savePath).writeAsString(contents, flush: true);
      if (!mounted) return;
      _showCopied('File exported');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('File could not be exported.'),
        backgroundColor: Colors.red,
      ));
    }
  }

  String _safeFileStem() {
    final stem = _currentEntry.displayTitle
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
    return stem.isEmpty
        ? 'passguard-export'
        : stem.substring(0, stem.length > 80 ? 80 : stem.length);
  }

  String _obscureValue(String value) {
    // Keep the length bounded so a pasted private key cannot create a giant
    // hidden-text widget, while still clearly communicating that it exists.
    return '•' * (value.length > 96 ? 96 : value.length);
  }

  void _showCopied(String label) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label · 15s'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  IconData _entryIcon(VaultEntry entry) {
    switch (entry.type) {
      case VaultEntryType.password:
        return Icons.lock_rounded;
      case VaultEntryType.note:
        return Icons.sticky_note_2_rounded;
      case VaultEntryType.sshKey:
        return Icons.terminal_rounded;
      case VaultEntryType.certificate:
        return Icons.verified_user_rounded;
    }
  }

  String _entryTypeLabel(VaultEntry entry) {
    switch (entry.type) {
      case VaultEntryType.password:
        return AppLocalizations.of(context).password;
      case VaultEntryType.note:
        return AppLocalizations.of(context).note;
      case VaultEntryType.sshKey:
        return 'SSH key';
      case VaultEntryType.certificate:
        return 'Certificate';
    }
  }

  String _deletedEntryMessage(AppLocalizations localizations) {
    switch (_currentEntry.type) {
      case VaultEntryType.password:
        return localizations.passwordDeleted;
      case VaultEntryType.note:
        return localizations.noteDeleted;
      case VaultEntryType.sshKey:
        return 'SSH key deleted';
      case VaultEntryType.certificate:
        return 'Certificate deleted';
    }
  }

  Widget _buildActionButtons() {
    final localizations = AppLocalizations.of(context);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        spacing: 8,
        runSpacing: 8,
        children: [
          // Copy Content Button
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              ClipboardService.copyContent(
                  stripNoteTags(_currentEntry.content ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${localizations.contentCopied} · 30s'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: Text(localizations.copy),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
