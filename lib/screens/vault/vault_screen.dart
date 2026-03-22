import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault_v0/services/vault_service.dart';
import 'package:passguard_vault_v0/services/clipboard_service.dart';
import 'package:passguard_vault_v0/services/password_generator_service.dart';
import 'package:passguard_vault_v0/services/session_service.dart';
import 'package:passguard_vault_v0/models/vault_entry.dart';
import 'add_entry_screen.dart';
import 'entry_detail_screen.dart';
import '../settings/settings_screen.dart';
import '../../utils/app_localizations.dart';
import '../../utils/app_theme.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  List<VaultEntry> _entries = [];
  List<VaultEntry> _filteredEntries = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;
  Uint8List? _sessionKey;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      _sessionKey = _getSessionKey();
      _entries = await VaultService.getAllEntries(_sessionKey!);
      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).somethingWentWrong),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Uint8List _getSessionKey() {
    final key = SessionService.getSessionKey();
    if (key == null) {
      throw Exception('Session expired. Please login again.');
    }
    return key;
  }

  void _applyFilters() {
    var filtered = _entries;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) {
        return entry.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               entry.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               (entry.username?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               (entry.website?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               (entry.content?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Category filter
    if (_selectedCategory != 'all') {
      filtered = filtered.where((entry) {
        return entry.category.toLowerCase() == _selectedCategory.toLowerCase();
      }).toList();
    }

    // Sort
    filtered.sort((a, b) {
      int result = 0;
      
      switch (_sortBy) {
        case 'name':
          result = a.title.compareTo(b.title);
          break;
        case 'date':
          result = a.createdAt.compareTo(b.createdAt);
          break;
        case 'category':
          result = a.category.compareTo(b.category);
          break;
        case 'strength':
          if (a.type == VaultEntryType.password && b.type == VaultEntryType.password) {
            final strengthA = PasswordGeneratorService.calculateStrength(a.password ?? '');
            final strengthB = PasswordGeneratorService.calculateStrength(b.password ?? '');
            result = strengthA.compareTo(strengthB);
          }
          break;
      }
      
      return _sortAscending ? result : -result;
    });

    setState(() {
      _filteredEntries = filtered;
    });
  }

  Future<void> _addEntry() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEntryScreen(rawKey: _sessionKey!),
      ),
    );
    
    if (result == true) {
      await _loadEntries();
    }
  }

  Future<void> _viewEntry(VaultEntry entry) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryDetailScreen(
          entry: entry,
          rawKey: _sessionKey!,
        ),
      ),
    );
    
    if (result == true) {
      await _loadEntries();
    }
  }

  Future<void> _deleteEntry(VaultEntry entry) async {
    final localizations = AppLocalizations.of(context);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteConfirmation),
        content: Text('${localizations.delete} "${entry.displayTitle}"?'),
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
        await VaultService.deleteEntry(entry.id, _sessionKey!);
        await _loadEntries();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.passwordDeleted),
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
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, size: 22),
            const SizedBox(width: 8),
            Text(localizations.passwords),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _addEntry,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: () {
              _showFilterDialog();
            },
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildVaultContent(),
    );
  }

  Widget _buildVaultContent() {
    final localizations = AppLocalizations.of(context);

    if (_filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _entries.isEmpty ? localizations.noPasswords : localizations.noData,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_entries.isEmpty)
              Text(
                localizations.addPassword,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Search Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: localizations.search,
                hintText: localizations.searchPlaceholder,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
            ),
          ),
        ),

        // Stats
        SliverToBoxAdapter(child: _buildStatsCard()),

        // Entries List
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final entry = _filteredEntries[index];
              return _buildEntryCard(entry);
            },
            childCount: _filteredEntries.length,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    final localizations = AppLocalizations.of(context);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  _entries.where((e) => e.type == VaultEntryType.password).length.toString(),
                  localizations.passwords,
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  _entries.where((e) => e.type == VaultEntryType.note).length.toString(),
                  localizations.notes,
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  _entries.length.toString(),
                  localizations.all,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label),
      ],
    );
  }

  Widget _buildEntryCard(VaultEntry entry) {
    final localizations = AppLocalizations.of(context);
    final isPassword = entry.type == VaultEntryType.password;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _viewEntry(entry),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Icon
              Icon(
                isPassword ? Icons.lock : Icons.note,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.displayCategory,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    if (isPassword) ...[
                      const SizedBox(height: 4),
                      _buildPasswordStrengthIndicator(context, entry.password ?? ''),
                    ],
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPassword)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      onPressed: () => ClipboardService.copyPassword(entry.password ?? ''),
                      icon: const Icon(Icons.copy, size: 20),
                    ),
                  if (!isPassword)
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      onPressed: () => ClipboardService.copyContent(entry.content ?? ''),
                      icon: const Icon(Icons.copy, size: 20),
                    ),
                  IconButton(
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                    onPressed: () => _deleteEntry(entry),
                    icon: const Icon(Icons.delete, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(BuildContext context, String password) {
    final strength = PasswordGeneratorService.calculateStrength(password);
    final color = PasswordGeneratorService.getStrengthColor(strength);
    final level = PasswordGeneratorService.getStrengthLevel(strength);

    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: strength / 100,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: color,
          ),
        ),
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    final localizations = AppLocalizations.of(context);
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.filter),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sort Options
              Text(localizations.sortBy, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: _sortBy,
                items: [
                  DropdownMenuItem(
                    value: 'name',
                    child: Text(localizations.name),
                  ),
                  DropdownMenuItem(
                    value: 'date',
                    child: Text(localizations.date),
                  ),
                  DropdownMenuItem(
                    value: 'category',
                    child: Text(localizations.category),
                  ),
                  if (_sortBy == 'strength')
                    DropdownMenuItem(
                      value: 'strength',
                      child: Text(localizations.strength),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(height: 16),

              // Sort Order
              Row(
                children: [
                  Text(localizations.sort, style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Switch(
                    value: _sortAscending,
                    onChanged: (value) {
                      setState(() {
                        _sortAscending = value;
                      });
                      _applyFilters();
                    },
                  ),
                  Text(_sortAscending ? localizations.ascending : localizations.descending),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
        ],
      ),
    );
  }
}