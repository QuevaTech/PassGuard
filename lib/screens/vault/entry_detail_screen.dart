import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault/services/vault_service.dart';
import 'package:passguard_vault/services/clipboard_service.dart';
import 'package:passguard_vault/services/password_generator_service.dart';
import 'package:passguard_vault/models/vault_entry.dart';
import 'add_entry_screen.dart';
import '../../utils/app_localizations.dart';
import '../../utils/app_theme.dart';
import '../../widgets/note_content_renderer.dart';
import '../../widgets/glass_card.dart';

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
        content: Text('${localizations.delete} "${_currentEntry.displayTitle}"?'),
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
              content: Text(_currentEntry.type == VaultEntryType.password
                  ? localizations.passwordDeleted
                  : localizations.noteDeleted),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
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
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? const [Color(0xFF0F172A), Color(0xFF1A2744), Color(0xFF0F172A)]
                      : const [Color(0xFFEFF6FF), Color(0xFFE0EFFE), Color(0xFFEFF6FF)],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Padding(
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
                    isPassword ? Icons.lock : Icons.note,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isPassword ? localizations.password : localizations.note,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text(
                      _currentEntry.displayCategory,
                      overflow: TextOverflow.ellipsis,
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
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
            ] else ...[
              // Content
              _buildContentCard(),
              const SizedBox(height: 16),
            ],

            // Notes (if present)
            if (_currentEntry.notes != null && _currentEntry.notes!.isNotEmpty) ...[
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
            if (!isPassword)
              _buildActionButtons(),
          ],
        ),
          ),
        ],
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
              color: AppTheme.textSecondaryColor,
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
                    content: Text('${AppLocalizations.of(context).websiteCopied} · 30s'),
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
                    color: AppTheme.textSecondaryColor,
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
                        content: Text('${AppLocalizations.of(context).passwordCopied} · 30s'),
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
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                color: AppTheme.textSecondaryColor,
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
                        content: Text('${AppLocalizations.of(context).contentCopied} · 30s'),
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
                ClipboardService.copyContent(stripNoteTags(_currentEntry.content ?? ''));
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