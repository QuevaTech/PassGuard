import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault_v0/services/vault_service.dart';
import 'package:passguard_vault_v0/services/clipboard_service.dart';
import 'package:passguard_vault_v0/services/password_generator_service.dart';
import 'package:passguard_vault_v0/models/vault_entry.dart';
import '../../utils/app_localizations.dart';
import '../../utils/app_theme.dart';

class AddEntryScreen extends ConsumerStatefulWidget {
  final Uint8List rawKey;

  const AddEntryScreen({super.key, required this.rawKey});

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
  
  VaultEntryType _entryType = VaultEntryType.password;
  String _selectedCategory = 'Personal';
  bool _obscurePassword = true;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;
  int _passwordStrength = 0;

  final List<String> _categories = [
    'Personal',
    'Work',
    'Banking',
    'Social',
    'Shopping',
    'Entertainment',
    'Security',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _contentController.dispose();
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
    await ClipboardService.copyPassword(generatedPassword);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).passwordCopied),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final entry = VaultEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _entryType,
        title: _titleController.text,
        category: _selectedCategory,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        username: _entryType == VaultEntryType.password ? _usernameController.text : null,
        password: _entryType == VaultEntryType.password ? _passwordController.text : null,
        website: _entryType == VaultEntryType.password ? _websiteController.text : null,
        content: _entryType == VaultEntryType.note ? _contentController.text : null,
      );

      await VaultService.addEntry(entry, widget.rawKey);

      if (!mounted) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).somethingWentWrong),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_entryType == VaultEntryType.password 
            ? localizations.addPassword 
            : localizations.addNote),
        actions: [
          IconButton(
            onPressed: _saveEntry,
            icon: const Icon(Icons.save),
          ),
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
              const SizedBox(height: 20),

              // Category Field
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: localizations.category,
                  prefixIcon: const Icon(Icons.category),
                  border: const OutlineInputBorder(),
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
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
                          backgroundColor: Colors.grey[300],
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
              ],

              // Content Field (only for note type)
              if (_entryType == VaultEntryType.note)
                TextFormField(
                  controller: _contentController,
                  maxLines: 6,
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
          ),
        ),
      ),
    );
  }
}