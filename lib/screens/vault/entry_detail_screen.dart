import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault_v0/services/vault_service.dart';
import 'package:passguard_vault_v0/services/clipboard_service.dart';
import 'package:passguard_vault_v0/services/password_generator_service.dart';
import 'package:passguard_vault_v0/models/vault_entry.dart';
import 'add_entry_screen.dart';
import '../../utils/app_localizations.dart';
import '../../utils/app_theme.dart';

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
  bool _isEditing = false;
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
        builder: (_) => AddEntryScreen(rawKey: widget.rawKey),
      ),
    );
    
    if (result == true) {
      // Reload entry
      // In a real app, you would fetch the updated entry
      setState(() {
        _isEditing = false;
      });
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentEntry.displayTitle),
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
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
            Card(
              color: isPassword 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                    Flexible(
                      child: Chip(
                        label: Text(
                          _currentEntry.displayCategory,
                          overflow: TextOverflow.ellipsis,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
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
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    bool isLink = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 4),
            if (isLink)
              InkWell(
                onTap: () {
                  // Handle link tap
                  ClipboardService.copyWebsite(value);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).websiteCopied),
                      backgroundColor: Colors.green,
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
      ),
    );
  }

  Widget _buildPasswordCard() {
    final password = _currentEntry.password ?? '';
    final strength = PasswordGeneratorService.calculateStrength(password);
    final strengthText = PasswordGeneratorService.getStrengthLevel(strength);
    final strengthColor = PasswordGeneratorService.getStrengthColor(strength);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    AppLocalizations.of(context).password,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                  onPressed: () {
                    ClipboardService.copyPassword(password);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).passwordCopied),
                        backgroundColor: Colors.green,
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
      ),
    );
  }

  Widget _buildContentCard() {
    final content = _currentEntry.content ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).content,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    ClipboardService.copyContent(content);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).contentCopied),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final localizations = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 8,
          runSpacing: 8,
          children: [
            // Copy Content Button
            OutlinedButton.icon(
              onPressed: () {
                ClipboardService.copyContent(_currentEntry.content ?? '');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.contentCopied),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: const Icon(Icons.copy),
              label: Text(localizations.copy),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}