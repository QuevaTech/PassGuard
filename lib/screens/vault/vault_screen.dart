import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:passguard_vault_v0/services/vault_service.dart';
import 'package:passguard_vault_v0/services/clipboard_service.dart';
import 'package:passguard_vault_v0/services/password_generator_service.dart';
import 'package:passguard_vault_v0/services/session_service.dart';
import 'package:passguard_vault_v0/models/vault_entry.dart';
import 'add_entry_screen.dart';
import 'entry_detail_screen.dart';
import 'password_health_screen.dart';
import '../settings/settings_screen.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/glass_card.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen>
    with WidgetsBindingObserver {
  List<VaultEntry> _entries = [];
  List<VaultEntry> _filteredEntries = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  String _sortBy = 'name';
  bool _sortAscending = true;
  Uint8List? _sessionKey;
  Timer? _searchDebounce;

  // Multi-select state
  bool _isSelectMode = false;
  final Set<String> _selectedIds = {};

  // Favorites strip auto-hide state
  bool _favoritesExpanded = false;
  Timer? _favoritesTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadEntries();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _favoritesTimer?.cancel();
    super.dispose();
  }

  void _showFavorites() {
    _favoritesTimer?.cancel();
    setState(() => _favoritesExpanded = true);
    _favoritesTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _favoritesExpanded = false);
    });
  }

  // Feature 8: Auto-lock when app goes to background (mobile only)
  // macOS/Windows/Linux don't have a true "background" concept — minimizing
  // triggers inactive/paused which would falsely lock the vault mid-use.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    if (state == AppLifecycleState.paused) {
      SessionService.forceLock();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _loadEntries() async {
    _favoritesTimer?.cancel();
    setState(() { _isLoading = true; _favoritesExpanded = false; });
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

    // Sort — favorites always float to top within the chosen order
    filtered.sort((a, b) {
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
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
        builder: (_) => AddEntryScreen(rawKey: _getSessionKey()),
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
          rawKey: _getSessionKey(),
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
      HapticFeedback.mediumImpact();
      try {
        await VaultService.deleteEntry(entry.id, _getSessionKey());
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

  void _showQuickCopySheet(VaultEntry entry) {
    final localizations = AppLocalizations.of(context);
    final isPassword = entry.type == VaultEntryType.password;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(isPassword ? Icons.lock : Icons.note,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.displayTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            if (isPassword) ...[
              if (entry.password != null)
                ListTile(
                  leading: const Icon(Icons.password),
                  title: Text(localizations.copyPassword),
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                    ClipboardService.copyPassword(entry.password!);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${localizations.passwordCopied} · 30s'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ));
                  },
                ),
              if (entry.username != null && entry.username!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(localizations.copyUsername),
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                    ClipboardService.copyUsername(entry.username!);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${localizations.usernameCopied} · 30s'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ));
                  },
                ),
              if (entry.website != null && entry.website!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(localizations.copyWebsite),
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                    ClipboardService.copyWebsite(entry.website!);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${localizations.websiteCopied} · 30s'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ));
                  },
                ),
            ] else ...[
              if (entry.content != null)
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: Text(localizations.copyContent),
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                    ClipboardService.copyContent(entry.content!);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${localizations.contentCopied} · 30s'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ));
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.check_box_outlined),
              title: Text(localizations.select),
              onTap: () {
                Navigator.pop(ctx);
                _toggleSelectMode();
                _toggleSelect(entry.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _toggleSelectMode() {
    setState(() {
      _isSelectMode = !_isSelectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final localizations = AppLocalizations.of(context);
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.deleteConfirmation),
        content: Text('$count ${localizations.delete}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(localizations.no)),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(localizations.yes)),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in List.of(_selectedIds)) {
      await VaultService.deleteEntry(id, _getSessionKey());
    }
    setState(() { _isSelectMode = false; _selectedIds.clear(); });
    await _loadEntries();
  }

  Future<void> _moveSelectedToCategory(String category) async {
    for (final id in List.of(_selectedIds)) {
      final entry = _entries.firstWhere((e) => e.id == id);
      await VaultService.updateEntry(
        entry.copyWith(category: category, updatedAt: DateTime.now()),
        _getSessionKey(),
      );
    }
    setState(() { _isSelectMode = false; _selectedIds.clear(); });
    await _loadEntries();
  }

  Future<void> _showMoveDialog() async {
    final localizations = AppLocalizations.of(context);
    const categories = ['Personal', 'Work', 'Banking', 'Social', 'Shopping', 'Entertainment', 'Security', 'Other'];
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(localizations.category),
        children: categories.map((c) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, c),
          child: Text(c),
        )).toList(),
      ),
    );
    if (chosen != null) await _moveSelectedToCategory(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: _isSelectMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectMode,
              ),
              title: Text('${_selectedIds.length} ${localizations.selected}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.drive_file_move_outline),
                  tooltip: localizations.category,
                  onPressed: _selectedIds.isEmpty ? null : _showMoveDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: localizations.delete,
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: Text(localizations.passwords),
              actions: [
                IconButton(onPressed: _addEntry, icon: const Icon(Icons.add)),
                IconButton(onPressed: _showFilterDialog, icon: const Icon(Icons.filter_list)),
                IconButton(
                  icon: const Icon(Icons.health_and_safety_outlined),
                  tooltip: 'Password Health',
                  onPressed: () {
                    if (_sessionKey != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PasswordHealthScreen(rawKey: _getSessionKey()),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ).then((_) => _loadEntries()),
                  icon: const Icon(Icons.settings),
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildVaultContent(),
        ],
      ),
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

    final hasFavorites = _entries.any((e) => e.isFavorite);

    return CustomScrollView(
      slivers: [
        // Favorites Strip — auto-hide, revealed by hover (desktop) or swipe
        if (hasFavorites)
          SliverToBoxAdapter(child: _buildFavoritesStrip()),

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
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                  setState(() {
                    _searchQuery = value;
                  });
                  _applyFilters();
                });
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

  Widget _buildFavoritesStrip() {
    final favorites = _entries.where((e) => e.isFavorite).toList();
    final theme = Theme.of(context);
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;

    // Trigger area — shows a thin peek bar; hover (desktop) or swipe-down (mobile) expands
    return MouseRegion(
      onEnter: isDesktop ? (_) => _showFavorites() : null,
      child: GestureDetector(
        // Swipe down reveals favorites on mobile
        onVerticalDragEnd: !isDesktop
            ? (d) {
                if (d.primaryVelocity != null && d.primaryVelocity! > 100) {
                  _showFavorites();
                }
              }
            : null,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _favoritesExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 6),
                          Text(
                            'Favorites',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              _favoritesTimer?.cancel();
                              setState(() => _favoritesExpanded = false);
                            },
                            child: const Icon(Icons.keyboard_arrow_up, size: 18),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: favorites.length,
                        itemBuilder: (context, i) {
                          final entry = favorites[i];
                          final isPassword = entry.type == VaultEntryType.password;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                if (isPassword && entry.password != null) {
                                  ClipboardService.copyPassword(entry.password!);
                                } else if (entry.content != null) {
                                  ClipboardService.copyContent(entry.content!);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(isPassword
                                      ? '${AppLocalizations.of(context).passwordCopied} · 30s'
                                      : '${AppLocalizations.of(context).contentCopied} · 30s'),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 3),
                                ));
                              },
                              onLongPress: () => _showQuickCopySheet(entry),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isPassword ? Icons.lock : Icons.note,
                                      size: 20,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 70,
                                      child: Text(
                                        entry.displayTitle,
                                        style: theme.textTheme.bodySmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                )
              // Collapsed: just a thin peek strip with star icon
              : InkWell(
                  onTap: _showFavorites,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          'Favorites  ▾',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.amber,
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

  Widget _buildStatsCard() {
    final localizations = AppLocalizations.of(context);

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    final isPassword = entry.type == VaultEntryType.password;
    final isSelected = _selectedIds.contains(entry.id);
    final isOld = isPassword &&
        DateTime.now().difference(entry.updatedAt).inDays > 90;

    final card = GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leftAccentColor: entry.color,
      color: isSelected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isSelectMode ? () => _toggleSelect(entry.id) : () => _viewEntry(entry),
        onLongPress: () {
          if (_isSelectMode) {
            _toggleSelect(entry.id);
          } else {
            _showQuickCopySheet(entry);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Checkbox in select mode, icon otherwise
              if (_isSelectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelect(entry.id),
                )
              else
                Icon(
                  isPassword ? Icons.lock : Icons.note,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              const SizedBox(width: 8),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.displayTitle,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOld)
                          Tooltip(
                            message: '90+ gün',
                            child: Icon(Icons.warning_amber_rounded,
                                size: 14, color: Colors.orange.shade600),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.displayCategory,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (isPassword) ...[
                      const SizedBox(height: 4),
                      _buildPasswordStrengthIndicator(context, entry.password ?? ''),
                    ],
                  ],
                ),
              ),

              // Actions (hidden in select mode)
              if (!_isSelectMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      onPressed: () async {
                        final updated = entry.copyWith(
                          isFavorite: !entry.isFavorite,
                          updatedAt: DateTime.now(),
                        );
                        // Optimistic update — reflect change instantly, save in background
                        final idx = _entries.indexWhere((e) => e.id == entry.id);
                        if (idx != -1) {
                          setState(() {
                            _entries[idx] = updated;
                          });
                          _applyFilters();
                        }
                        await VaultService.updateEntry(updated, _getSessionKey());
                      },
                      icon: Icon(
                        entry.isFavorite ? Icons.star : Icons.star_border,
                        size: 22,
                        color: entry.isFavorite ? Colors.amber : Colors.grey,
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        if (isPassword) {
                          ClipboardService.copyPassword(entry.password ?? '');
                        } else {
                          ClipboardService.copyContent(entry.content ?? '');
                        }
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isPassword
                              ? '${AppLocalizations.of(context).passwordCopied} · 30s'
                              : '${AppLocalizations.of(context).contentCopied} · 30s'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 3),
                        ));
                      },
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

    if (_isSelectMode) return card;

    return Slidable(
      key: ValueKey(entry.id),
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) async {
              HapticFeedback.mediumImpact();
              final updated = entry.copyWith(
                isFavorite: !entry.isFavorite,
                updatedAt: DateTime.now(),
              );
              final idx = _entries.indexWhere((e) => e.id == entry.id);
              if (idx != -1) {
                setState(() => _entries[idx] = updated);
                _applyFilters();
              }
              await VaultService.updateEntry(updated, _getSessionKey());
            },
            backgroundColor: Colors.amber,
            foregroundColor: Colors.white,
            icon: entry.isFavorite ? Icons.star_border : Icons.star,
            label: entry.isFavorite ? 'Unpin' : 'Pin',
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              _deleteEntry(entry);
            },
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: card,
    );
  }

  Widget _buildPasswordStrengthIndicator(BuildContext context, String password) {
    final strength = PasswordGeneratorService.calculateStrength(password);
    final color = PasswordGeneratorService.getStrengthColor(strength);

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