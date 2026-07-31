import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault/services/vault_service.dart';
import 'package:passguard_vault/services/clipboard_service.dart';
import 'package:passguard_vault/services/password_generator_service.dart';
import 'package:passguard_vault/services/ssh_key_service.dart';
import 'package:passguard_vault/models/vault_entry.dart';
import '../../utils/app_localizations.dart';
import '../../utils/app_theme.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/app_scaffold.dart';

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
  final _privateKeyController = TextEditingController();
  final _publicKeyController = TextEditingController();
  final _certificateController = TextEditingController();
  final _notesController = TextEditingController();

  VaultEntryType _entryType = VaultEntryType.password;
  String _selectedCategory = 'Personal';
  bool _isFavorite = false;
  int? _selectedColorValue;
  bool _obscurePassword = true;
  bool _isSaving = false;
  bool _isGeneratingKey = false;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;
  int _passwordStrength = 0;
  String? _keyFingerprint;
  String? _attachmentBase64;
  String? _attachmentFileName;
  String? _attachmentMimeType;
  String _credentialKind = 'TLS / SSL';

  static const List<String> _categoryKeys = [
    'Personal',
    'Work',
    'Servers',
    'Certificates',
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
      _privateKeyController.text = e.privateKey ?? '';
      _publicKeyController.text = e.publicKey ?? '';
      _certificateController.text = e.certificateData ?? '';
      _notesController.text = e.notes ?? '';
      _keyFingerprint = e.keyFingerprint;
      _attachmentBase64 = e.attachmentBase64;
      _attachmentFileName = e.attachmentFileName;
      _attachmentMimeType = e.attachmentMimeType;
      _credentialKind = e.credentialKind ?? _credentialKind;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _contentController.dispose();
    _privateKeyController.dispose();
    _publicKeyController.dispose();
    _certificateController.dispose();
    _notesController.dispose();
    _passwordController.removeListener(_updatePasswordStrength);
    super.dispose();
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    if (password.isNotEmpty) {
      _passwordStrength = PasswordGeneratorService.calculateStrength(password);
      _passwordStrengthText =
          PasswordGeneratorService.getStrengthLevel(_passwordStrength);
      _passwordStrengthColor =
          PasswordGeneratorService.getStrengthColor(_passwordStrength);
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
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppLocalizations.of(context).passwordCopied} · 30s'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _generateSshKey() async {
    setState(() => _isGeneratingKey = true);
    try {
      final generated = await SshKeyService.generateRsaKeyPair(
        comment: _titleController.text.trim().isEmpty
            ? 'passguard'
            : _titleController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _privateKeyController.text = generated.privateKey;
        _publicKeyController.text = generated.publicKey;
        _keyFingerprint = generated.fingerprint;
      });
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RSA 3072 SSH key pair created inside your vault.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SSH key could not be generated.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingKey = false);
    }
  }

  Future<void> _importSshKey({required bool publicKey}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions:
          publicKey ? const ['pub', 'txt'] : const ['pem', 'key', 'ppk', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.size > VaultEntry.maxSensitiveFieldLength || file.bytes == null) {
      _showFileError('Choose a text key file smaller than 10 MB.');
      return;
    }
    try {
      final text = utf8.decode(file.bytes!, allowMalformed: false).trim();
      if (text.isEmpty) throw const FormatException();
      setState(() {
        if (publicKey) {
          _publicKeyController.text = text;
          _keyFingerprint =
              _sshFingerprintFromPublicKey(text) ?? _keyFingerprint;
        } else {
          _privateKeyController.text = text;
        }
      });
      HapticFeedback.lightImpact();
    } on FormatException {
      _showFileError('This does not look like a UTF-8 SSH key file.');
    }
  }

  Future<void> _importCertificateFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pem',
        'crt',
        'cer',
        'der',
        'p12',
        'pfx',
        'p7b',
        'p7c',
      ],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    // Binary files are base64 encoded before entry encryption. 5 MiB leaves
    // room below the entry's 10 MiB field limit after base64 expansion.
    const maxCertificateFileSize = 5 * 1024 * 1024;
    if (file.size > maxCertificateFileSize || file.bytes == null) {
      _showFileError('Choose a certificate file smaller than 5 MB.');
      return;
    }

    final bytes = file.bytes!;
    final text = _tryDecodeTextCertificate(bytes);
    setState(() {
      _attachmentFileName = file.name;
      _attachmentMimeType = _mimeTypeForFileName(file.name);
      if (text != null) {
        // PEM and other text encodings remain easy to inspect/copy. They do
        // not need a second duplicate attachment in the encrypted record.
        _certificateController.text = text;
        _attachmentBase64 = null;
      } else {
        _certificateController.clear();
        _attachmentBase64 = base64Encode(bytes);
      }
    });
    HapticFeedback.lightImpact();
  }

  String? _tryDecodeTextCertificate(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes, allowMalformed: false).trim();
      if (text.contains('-----BEGIN ') || text.startsWith('{')) return text;
    } on FormatException {
      // This is a binary certificate container; keep its original bytes.
    }
    return null;
  }

  String _mimeTypeForFileName(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pem':
      case 'crt':
      case 'cer':
        return 'application/x-pem-file';
      case 'p12':
      case 'pfx':
        return 'application/x-pkcs12';
      case 'der':
        return 'application/pkix-cert';
      default:
        return 'application/octet-stream';
    }
  }

  String? _sshFingerprintFromPublicKey(String publicKey) {
    final parts = publicKey.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || parts.first != 'ssh-rsa') return null;
    try {
      // The SHA-256 fingerprint is calculated on the decoded OpenSSH blob.
      // A display-only import has no security impact when parsing fails.
      final digest = base64Decode(parts[1]);
      return 'SHA256:${base64Encode(sha256.convert(digest).bytes).replaceAll('=', '')}';
    } catch (_) {
      return null;
    }
  }

  void _showFileError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final existing = widget.existingEntry;
      final notesText = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      final entry = VaultEntry(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: _entryType,
        title: _titleController.text,
        category: _selectedCategory,
        isFavorite: _isFavorite,
        colorValue: _selectedColorValue,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        username: _entryType == VaultEntryType.password
            ? _usernameController.text
            : null,
        password: _entryType == VaultEntryType.password
            ? _passwordController.text
            : null,
        website: _entryType == VaultEntryType.password
            ? (_websiteController.text.isEmpty ? null : _websiteController.text)
            : null,
        content:
            _entryType == VaultEntryType.note ? _contentController.text : null,
        privateKey: _entryType == VaultEntryType.sshKey
            ? (_privateKeyController.text.trim().isEmpty
                ? null
                : _privateKeyController.text.trim())
            : null,
        publicKey: _entryType == VaultEntryType.sshKey
            ? (_publicKeyController.text.trim().isEmpty
                ? null
                : _publicKeyController.text.trim())
            : null,
        keyFingerprint:
            _entryType == VaultEntryType.sshKey ? _keyFingerprint : null,
        certificateData: _entryType == VaultEntryType.certificate
            ? (_certificateController.text.trim().isEmpty
                ? null
                : _certificateController.text.trim())
            : null,
        attachmentBase64:
            _entryType == VaultEntryType.certificate ? _attachmentBase64 : null,
        attachmentFileName: _entryType == VaultEntryType.certificate
            ? _attachmentFileName
            : null,
        attachmentMimeType: _entryType == VaultEntryType.certificate
            ? _attachmentMimeType
            : null,
        credentialKind:
            _entryType == VaultEntryType.certificate ? _credentialKind : null,
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
              : _entryType == VaultEntryType.note
                  ? AppLocalizations.of(context).noteSaved
                  : _entryType == VaultEntryType.sshKey
                      ? 'SSH key saved'
                      : 'Certificate saved'),
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
      final newText =
          '${text.substring(0, offset)}$open$close${text.substring(offset)}';
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: offset + open.length),
      );
      return;
    }
    final text = controller.text;
    final selected = selection.textInside(text);
    final newText = text.replaceRange(
        selection.start, selection.end, '$open$selected$close');
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
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.25),
                width: _selectedColorValue == null ? 2.5 : 1.5,
              ),
            ),
            child: Icon(
              Icons.block,
              size: _selectedColorValue == null ? 18 : 14,
              color: _selectedColorValue == null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                          .extension<AppThemeExtension>()
                          ?.textSecondary ??
                      Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
            ),
          ),
        ),
        ...(_tagColors(context)).map((color) {
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
                    ? [
                        BoxShadow(
                            color: color.withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: 1)
                      ]
                    : [],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// Returns tag colours from the current theme's categoryColors,
  /// falling back to the legacy static list when the extension is absent.
  List<Color> _tagColors(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext != null) return ext.categoryColors.values.toList();
    return AppTheme.entryTagColors;
  }

  Widget _buildCredentialNotice({
    required IconData icon,
    required String text,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(String key, AppLocalizations localizations) {
    switch (key) {
      case 'Servers':
        return 'Servers';
      case 'Certificates':
        return 'Certificates';
      default:
        const legacyKeys = [
          'Personal',
          'Work',
          'Banking',
          'Social',
          'Shopping',
          'Entertainment',
          'Security',
          'Other',
        ];
        final index = legacyKeys.indexOf(key);
        return index == -1 ? key : localizations.categoryList[index];
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final isEdit = widget.existingEntry != null;
    return AppScaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? localizations.editEntry
            : _entryType == VaultEntryType.password
                ? localizations.addPassword
                : _entryType == VaultEntryType.note
                    ? localizations.addNote
                    : _entryType == VaultEntryType.sshKey
                        ? 'Add SSH key'
                        : 'Add certificate'),
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
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2)),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final itemWidth = (constraints.maxWidth - 8) / 2;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _EntryTypeChoice(
                                width: itemWidth,
                                label: localizations.passwords,
                                icon: Icons.lock_rounded,
                                selected: _entryType == VaultEntryType.password,
                                onTap: () => setState(
                                  () => _entryType = VaultEntryType.password,
                                ),
                              ),
                              _EntryTypeChoice(
                                width: itemWidth,
                                label: localizations.notes,
                                icon: Icons.sticky_note_2_rounded,
                                selected: _entryType == VaultEntryType.note,
                                onTap: () => setState(
                                  () => _entryType = VaultEntryType.note,
                                ),
                              ),
                              _EntryTypeChoice(
                                width: itemWidth,
                                label: 'SSH key',
                                icon: Icons.terminal_rounded,
                                selected: _entryType == VaultEntryType.sshKey,
                                onTap: () => setState(
                                  () => _entryType = VaultEntryType.sshKey,
                                ),
                              ),
                              _EntryTypeChoice(
                                width: itemWidth,
                                label: 'Certificate',
                                icon: Icons.verified_user_rounded,
                                selected:
                                    _entryType == VaultEntryType.certificate,
                                onTap: () => setState(
                                  () => _entryType = VaultEntryType.certificate,
                                ),
                              ),
                            ],
                          );
                        },
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
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: localizations.category,
                  prefixIcon: const Icon(Icons.category),
                  border: const OutlineInputBorder(),
                ),
                items: _categoryKeys.map((key) {
                  return DropdownMenuItem(
                    value: key,
                    child: Text(_categoryLabel(key, localizations)),
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
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
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
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          valueColor:
                              AlwaysStoppedAnimation(_passwordStrengthColor),
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
                      onPressed: () =>
                          _wrapSelection('[spoiler]', '[/spoiler]'),
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

              // SSH key fields
              if (_entryType == VaultEntryType.sshKey) ...[
                _buildCredentialNotice(
                  icon: Icons.shield_outlined,
                  text: 'Private keys are encrypted as part of this vault. '
                      'Use a separate passphrase before exporting a key for use outside PassGuard.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isGeneratingKey ? null : _generateSshKey,
                        icon: _isGeneratingKey
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: Text(
                          _isGeneratingKey
                              ? 'Generating…'
                              : 'Generate RSA 3072',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () => _importSshKey(publicKey: false),
                      tooltip: 'Import private key',
                      icon: const Icon(Icons.file_open_outlined),
                    ),
                    const SizedBox(width: 4),
                    IconButton.outlined(
                      onPressed: () => _importSshKey(publicKey: true),
                      tooltip: 'Import public key',
                      icon: const Icon(Icons.upload_file_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _privateKeyController,
                  minLines: 5,
                  maxLines: 9,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Private key',
                    hintText: '-----BEGIN … PRIVATE KEY-----',
                    prefixIcon: Icon(Icons.key_rounded),
                    suffixIcon: Tooltip(
                      message:
                          'Private key — visible only while this entry is open',
                      child: Icon(Icons.visibility_outlined),
                    ),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_entryType == VaultEntryType.sshKey &&
                        (value == null || value.trim().isEmpty)) {
                      return 'A private key is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _publicKeyController,
                  minLines: 3,
                  maxLines: 5,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Public key',
                    hintText: 'ssh-rsa AAAA…',
                    prefixIcon: Icon(Icons.key_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_entryType == VaultEntryType.sshKey &&
                        (value == null || value.trim().isEmpty)) {
                      return 'A public key is required.';
                    }
                    return null;
                  },
                ),
                if (_keyFingerprint != null) ...[
                  const SizedBox(height: 10),
                  SelectableText(
                    _keyFingerprint!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ],
              ],

              // Certificate fields
              if (_entryType == VaultEntryType.certificate) ...[
                _buildCredentialNotice(
                  icon: Icons.verified_user_outlined,
                  text:
                      'PEM text and binary certificate files are encrypted in your vault.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _credentialKind,
                  decoration: const InputDecoration(
                    labelText: 'Certificate type',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    'TLS / SSL',
                    'Client certificate',
                    'CA / Root certificate',
                    'Code signing',
                    'Other',
                  ]
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ))
                      .toList(),
                  onChanged: (value) => setState(
                    () => _credentialKind = value ?? _credentialKind,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _importCertificateFile,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Import certificate file'),
                ),
                if (_attachmentFileName != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_file_rounded, size: 17),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _attachmentBase64 != null
                              ? 'Encrypted binary file: $_attachmentFileName'
                              : 'Imported text file: $_attachmentFileName',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove imported file',
                        onPressed: () => setState(() {
                          _attachmentBase64 = null;
                          _attachmentFileName = null;
                          _attachmentMimeType = null;
                        }),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _certificateController,
                  minLines: 5,
                  maxLines: 9,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'Certificate PEM (optional for binary files)',
                    hintText: '-----BEGIN CERTIFICATE-----',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_entryType == VaultEntryType.certificate &&
                        (value == null || value.trim().isEmpty) &&
                        _attachmentBase64 == null) {
                      return 'Paste a certificate or import a certificate file.';
                    }
                    return null;
                  },
                ),
              ],

              // Notes are available for all secure material types. Password
              // entries already display this field in their own section.
              if (_entryType != VaultEntryType.password) ...[
                const SizedBox(height: 20),
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

  const _ToolbarButton(
      {required this.icon, required this.label, required this.onPressed});

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

class _EntryTypeChoice extends StatelessWidget {
  final double width;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _EntryTypeChoice({
    required this.width,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.28)
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
