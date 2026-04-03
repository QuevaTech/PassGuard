import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault_v0/services/vault_service.dart';
import 'package:passguard_vault_v0/services/clipboard_service.dart';
import 'package:passguard_vault_v0/services/password_generator_service.dart';
import 'package:passguard_vault_v0/models/vault_entry.dart';
import '../../utils/app_localizations.dart';
import '../../utils/app_theme.dart';

class AddEntryScreen extends ConsumerStatefulWidget {
  final Uint8List rawKey;
  // Pass an existing entry to edit it; null = new entry
  final VaultEntry? existingEntry;

  const AddEntryScreen({super.key, required this.rawKey, this.existingEntry});

  @override
  ConsumerState<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends ConsumerState<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _websiteController = TextEditingController();
  final _contentController = TextEditingController();
  final _notesController = TextEditingController();

  VaultEntryType _entryType = VaultEntryType.password;
  String _selectedCategory = 'Personal';
  bool _isFavorite = false;
  int? _selectedColorValue;
  bool _obscurePassword = true;
  bool _isSaving = false;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;
  int _passwordStrength = 0;

  static const List<String> _categoryKeys = [
    'Personal', 'Work', 'Banking', 'Social',
    'Shopping', 'Entertainment', 'Security', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
    // Prefill fields when editing an existing entry
    final e = widget.existingEntry;
    if (e != null) {
      _entryType = e.type;
      _selectedCategory = e.category;
      _isFavorite = e.isFavorite;
      _selectedColorValue = e.colorValue;
      _titleController.text = e.title;
      _usernameController.text = e.username ?? '';
      _passwordController.text = e.password ?? '';
      _websiteController.text = e.website ?? '';
      _contentController.text = e.content ?? '';
      _notesController.text = e.notes ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _contentController.dispose();
    _notesController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    if (password.isNotEmpty) {
      _passwordStrength = PasswordGeneratorService.calculateStrength(password);
      _passwordStrengthText = PasswordGeneratorService.getStrengthLevel(_passwordStrength);
      _passwordStrengthColor = PasswordGeneratorService.getStrengthColor(_passwordStrength);
    } else {
      _passwordStrength = 0;
      _passwordStrengthText = '';
      _passwordStrengthColor = Colors.grey;
    }
    setState(() {});
  }

  Future<void> _generatePassword() async {
    final generatedPassword = PasswordGeneratorService.generatePassword(
      length: 16,
      includeUppercase: true,
      includeLowercase: true,
      includeNumbers: true,
      includeSymbols: true,
    );
    _passwordController.text = generatedPassword;
    HapticFeedback.lightImpact();
    await ClipboardService.copyPassword(generatedPassword);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppLocalizations.of(context).passwordCopied} · 30s'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final existing = widget.existingEntry;
      final notesText = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();
      final entry = VaultEntry(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: _entryType,
        title: _titleController.text,
        category: _selectedCategory,
        isFavorite: _isFavorite,
        colorValue: _selectedColorValue,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        username: _entryType == VaultEntryType.password ? _usernameController.text : null,
        password: _entryType == VaultEntryType.password ? _passwordController.text : null,
        website: _entryType == VaultEntryType.password
            ? (_websiteController.text.isEmpty ? null : _websiteController.text)
            : null,
        content: _entryType == VaultEntryType.note ? _contentController.text : null,
        notes: notesText,
      );

      if (existing != null) {
        await VaultService.updateEntry(entry, widget.rawKey);
      } else {
        await VaultService.addEntry(entry, widget.rawKey);
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_entryType == VaultEntryType.password
              ? AppLocalizations.of(context).passwordSaved
              : AppLocalizations.of(context).noteSaved),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).somethingWentWrong),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _wrapSelection(String open, String close) {
    final controller = _contentController;
    final selection = controller.selection;
    if (!selection.isValid) {
      // No selection — just insert markers at cursor or end
      final text = controller.text;
      final offset = selection.isCollapsed && selection.start >= 0
          ? selection.start
          : text.length;
      final newText = text.substring(0, offset) + '$open$close' + text.substring(offset);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + open.length),
      );
      return;
    }
    final text = controller.text;
    final selected = selection.textInside(text);
    final newText = text.replaceRange(selection.start, selection.end, '$open$selected$close');
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + open.length + selected.length + close.length,
      ),
    );
  }

  Widget _buildColorPicker() {
    return Row(
      children: [
        // "No color" option
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _selectedColorValue = null);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _selectedColorValue == null ? 36 : 30,
            height: _selectedColorValue == null ? 36 : 30,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: _selectedColorValue == null
                    ? Theme.of(context).colorScheme.primary
                    : AppTheme.borderColor,
                width: _selectedColorValue == null ? 2.5 : 1.5,
              ),
            ),
            child: Icon(
              Icons.block,
              size: _selectedColorValue == null ? 18 : 14,
              color: _selectedColorValue == null
                  ? Theme.of(context).colorScheme.primary
                  : AppTheme.textSecondaryColor,
            ),
          ),
        ),
        ...AppTheme.entryTagColors.map((color) {
          final val = color.toARGB32();
          final isSelected = _selectedColorValue == val;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedColorValue = val);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: isSelected ? 36 : 28,
              height: isSelected ? 36 : 28,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: isSelected
                    ? Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black26,
                        width: 2.5,
                      )
                    : null,
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 8, spreadRadius: 1)]
                    : [],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final isEdit = widget.existingEntry != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? localizations.editEntry
            : _entryType == VaultEntryType.password
                ? localizations.addPassword
                : localizations.addNote),
        actions: [
          IconButton(
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber : null,
            ),
          ),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(onPressed: _saveEntry, icon: const Icon(Icons.save)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Entry Type Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations.category,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Password Type
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _entryType = VaultEntryType.password),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _entryType == VaultEntryType.password 
                                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.lock,
                                      color: _entryType == VaultEntryType.password
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      localizations.passwords,
                                      style: TextStyle(
                                        color: _entryType == VaultEntryType.password
                                            ? Theme.of(context).colorScheme.primary
                                            : null,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Note Type
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _entryType = VaultEntryType.note),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _entryType == VaultEntryType.note 
                                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.note,
                                      color: _entryType == VaultEntryType.note
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      localizations.notes,
                                      style: TextStyle(
                                        color: _entryType == VaultEntryType.note
                                            ? Theme.of(context).colorScheme.primary
                                            : null,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: localizations.title,
                  hintText: localizations.title,
                  prefixIcon: const Icon(Icons.title),
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return localizations.title;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Color Picker
              _buildColorPicker(),
              const SizedBox(height: 16),

              // Category Field
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: localizations.category,
                  prefixIcon: const Icon(Icons.category),
                  border: const OutlineInputBorder(),
                ),
                items: _categoryKeys.map((key) {
                  return DropdownMenuItem(
                    value: key,
                    child: Text(localizations.categoryList[_categoryKeys.indexOf(key)]),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Password Fields (only for password type)
              if (_entryType == VaultEntryType.password) ...[
                // Username Field
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: localizations.username,
                    hintText: localizations.username,
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: localizations.password,
                    hintText: localizations.password,
                    prefixIcon: const Icon(Icons.password),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.password),
                          onPressed: _generatePassword,
                          tooltip: localizations.generatePassword,
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localizations.password;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Password Strength Indicator
                if (_passwordStrength > 0)
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _passwordStrength / 100,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(_passwordStrengthColor),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _passwordStrengthText.toUpperCase(),
                        style: TextStyle(
                          color: _passwordStrengthColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($_passwordStrength/100)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // Website Field
                TextFormField(
                  controller: _websiteController,
                  decoration: InputDecoration(
                    labelText: localizations.website,
                    hintText: 'https://example.com',
                    prefixIcon: const Icon(Icons.language),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Notes Field (password type)
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: localizations.notes,
                    hintText: localizations.notes,
                    prefixIcon: const Icon(Icons.notes),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Note toolbar + content field (only for note type)
              if (_entryType == VaultEntryType.note) ...[
                // Toolbar
                Row(
                  children: [
                    _ToolbarButton(
                      icon: Icons.code,
                      label: 'Code',
                      onPressed: () => _wrapSelection('[code]', '[/code]'),
                    ),
                    const SizedBox(width: 8),
                    _ToolbarButton(
                      icon: Icons.visibility_off,
                      label: 'Spoiler',
                      onPressed: () => _wrapSelection('[spoiler]', '[/spoiler]'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contentController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: localizations.content,
                    hintText: localizations.content,
                    prefixIcon: const Icon(Icons.text_fields),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localizations.content;
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ToolbarButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}