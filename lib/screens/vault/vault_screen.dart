import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:passguard_vault/services/vault_service.dart';
import 'package:passguard_vault/services/clipboard_service.dart';
import 'package:passguard_vault/services/password_generator_service.dart';
import 'package:passguard_vault/services/session_service.dart';
import 'package:passguard_vault/models/vault_entry.dart';
import 'add_entry_screen.dart';
import 'entry_detail_screen.dart';
import 'password_health_screen.dart';
import '../settings/settings_screen.dart';
import '../auth/login_screen.dart';
import '../auth/verification_screen.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/glass_card.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/themed_fab.dart';
import '../../widgets/category_badge.dart';

enum _SmartCollection { all, favorites, weak, old, reused }

class _VaultHealthSnapshot {
  final Set<String> weakEntryIds;
  final Set<String> oldEntryIds;
  final Set<String> reusedEntryIds;

  const _VaultHealthSnapshot({
    required this.weakEntryIds,
    required this.oldEntryIds,
    required this.reusedEntryIds,
  });
}

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<VaultEntry> _entries = [];
  List<VaultEntry> _filteredEntries = [];
  bool _isLoading = true;
  String _searchQuery = '';
  _SmartCollection _selectedCollection = _SmartCollection.all;
  String _sortBy = 'name';
  bool _sortAscending = true;
  bool _isSessionLocked = false;
  Uint8List? _sessionKey;
  Timer? _searchDebounce;
  int _loadGeneration = 0;
  late final AnimationController _lockAnimationController;

  // Search overlay state
  bool _isSearchActive = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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
    _lockAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _isSessionLocked =
        SessionService.isLocked() || SessionService.getSessionKey() == null;
    if (_isSessionLocked) {
      _lockAnimationController.repeat(reverse: true);
    }
    SessionService.addListener(_onSessionChanged);
    if (!_isSessionLocked) {
      _loadEntries();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SessionService.removeListener(_onSessionChanged);
    _searchDebounce?.cancel();
    _favoritesTimer?.cancel();
    _lockAnimationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;

    final isLocked =
        SessionService.isLocked() || SessionService.getSessionKey() == null;
    if (!isLocked) {
      _lockAnimationController.stop();
      setState(() => _isSessionLocked = false);
      _loadEntries();
      return;
    }

    _loadGeneration++;
    _lockAnimationController.repeat(reverse: true);
    _searchDebounce?.cancel();
    _favoritesTimer?.cancel();
    _searchFocusNode.unfocus();
    _searchController.clear();
    ClipboardService.clearClipboard();
    setState(() {
      _isSessionLocked = true;
      _isLoading = false;
      _sessionKey = null;
      _entries = [];
      _filteredEntries = [];
      _searchQuery = '';
      _isSearchActive = false;
      _isSelectMode = false;
      _selectedIds.clear();
      _favoritesExpanded = false;
    });

    // Remove entry, edit, and settings routes that may still hold decrypted data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
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
    }
  }

  Future<void> _loadEntries() async {
    if (_isSessionLocked || SessionService.isLocked()) return;
    final loadGeneration = ++_loadGeneration;
    _favoritesTimer?.cancel();
    setState(() {
      _isLoading = true;
      _favoritesExpanded = false;
    });
    try {
      final sessionKey = _getSessionKey();
      final entries = await VaultService.getAllEntries(sessionKey);
      if (!mounted ||
          loadGeneration != _loadGeneration ||
          _isSessionLocked ||
          SessionService.isLocked()) {
        return;
      }
      _sessionKey = sessionKey;
      _entries = entries;
      _applyFilters();
    } catch (e) {
      if (mounted && !_isSessionLocked && !SessionService.isLocked()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).somethingWentWrong),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted &&
          loadGeneration == _loadGeneration &&
          !_isSessionLocked &&
          !SessionService.isLocked()) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reauthenticate() async {
    final screen = SessionService.isBiometricEnabled()
        ? const VerificationScreen()
        : const LoginScreen();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _openPasswordHealth() {
    if (_sessionKey == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PasswordHealthScreen(rawKey: _getSessionKey()),
      ),
    );
  }

  void _lockVault() {
    HapticFeedback.mediumImpact();
    SessionService.forceLock();
  }

  Uint8List _getSessionKey() {
    final key = SessionService.getSessionKey();
    if (key == null) {
      throw Exception('Session expired. Please login again.');
    }
    return key;
  }

  _VaultHealthSnapshot _healthSnapshot() {
    final passwords =
        _entries.where((entry) => entry.type == VaultEntryType.password);
    final weakEntryIds = <String>{};
    final oldEntryIds = <String>{};
    final passwordsByValue = <String, List<String>>{};

    for (final entry in passwords) {
      final password = entry.password ?? '';
      if (password.isNotEmpty) {
        if (PasswordGeneratorService.calculateStrength(password) < 40) {
          weakEntryIds.add(entry.id);
        }
        passwordsByValue.putIfAbsent(password, () => []).add(entry.id);
      }
      if (DateTime.now().difference(entry.updatedAt).inDays > 90) {
        oldEntryIds.add(entry.id);
      }
    }

    final reusedEntryIds = passwordsByValue.values
        .where((entryIds) => entryIds.length > 1)
        .expand((entryIds) => entryIds)
        .toSet();

    return _VaultHealthSnapshot(
      weakEntryIds: weakEntryIds,
      oldEntryIds: oldEntryIds,
      reusedEntryIds: reusedEntryIds,
    );
  }

  void _selectCollection(_SmartCollection collection) {
    if (_selectedCollection == collection) return;
    setState(() => _selectedCollection = collection);
    _applyFilters();
  }

  void _applyFilters() {
    var filtered = List<VaultEntry>.of(_entries);

    // Search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((entry) {
        return entry.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            entry.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (entry.username
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false) ||
            (entry.website
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false) ||
            (entry.content
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false) ||
            (entry.publicKey
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false) ||
            (entry.keyFingerprint
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false) ||
            (entry.certificateData
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ??
                false);
      }).toList();
    }

    // Smart collection filter
    final health = _healthSnapshot();
    switch (_selectedCollection) {
      case _SmartCollection.all:
        break;
      case _SmartCollection.favorites:
        filtered = filtered.where((entry) => entry.isFavorite).toList();
        break;
      case _SmartCollection.weak:
        filtered = filtered
            .where((entry) => health.weakEntryIds.contains(entry.id))
            .toList();
        break;
      case _SmartCollection.old:
        filtered = filtered
            .where((entry) => health.oldEntryIds.contains(entry.id))
            .toList();
        break;
      case _SmartCollection.reused:
        filtered = filtered
            .where((entry) => health.reusedEntryIds.contains(entry.id))
            .toList();
        break;
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
          if (a.type == VaultEntryType.password &&
              b.type == VaultEntryType.password) {
            final strengthA =
                PasswordGeneratorService.calculateStrength(a.password ?? '');
            final strengthB =
                PasswordGeneratorService.calculateStrength(b.password ?? '');
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
    final isNote = entry.type == VaultEntryType.note;
    final isSshKey = entry.type == VaultEntryType.sshKey;

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
                  Icon(_entryIcon(entry),
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
            ] else if (isNote) ...[
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
            ] else if (isSshKey) ...[
              if (entry.publicKey != null && entry.publicKey!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Copy public key'),
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                    ClipboardService.copyContent(entry.publicKey!);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Public key copied · 15s'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ));
                  },
                ),
              if (entry.privateKey != null && entry.privateKey!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.vpn_key_rounded),
                  title: const Text('Copy private key'),
                  subtitle:
                      const Text('Sensitive — clipboard clears in 15 seconds'),
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                    ClipboardService.copyContent(entry.privateKey!);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Private key copied · 15s'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
                    ));
                  },
                ),
            ] else ...[
              if (entry.certificateData != null &&
                  entry.certificateData!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Copy certificate'),
                  onTap: () {
                    Navigator.pop(ctx);
                    HapticFeedback.lightImpact();
                    ClipboardService.copyContent(entry.certificateData!);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Certificate copied · 15s'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 3),
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(localizations.no)),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(localizations.yes)),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in List.of(_selectedIds)) {
      await VaultService.deleteEntry(id, _getSessionKey());
    }
    setState(() {
      _isSelectMode = false;
      _selectedIds.clear();
    });
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
    setState(() {
      _isSelectMode = false;
      _selectedIds.clear();
    });
    await _loadEntries();
  }

  Future<void> _showMoveDialog() async {
    final localizations = AppLocalizations.of(context);
    const categories = [
      'Personal',
      'Work',
      'Servers',
      'Certificates',
      'Banking',
      'Social',
      'Shopping',
      'Entertainment',
      'Security',
      'Other'
    ];
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(localizations.category),
        children: categories
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c),
                  child: Text(c),
                ))
            .toList(),
      ),
    );
    if (chosen != null) await _moveSelectedToCategory(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (_isSessionLocked || SessionService.isLocked()) {
      final theme = Theme.of(context);
      final accent = theme.colorScheme.primary;
      return AppScaffold(
        body: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: _lockAnimationController,
              builder: (context, child) {
                final motion =
                    Curves.easeInOut.transform(_lockAnimationController.value) -
                        0.5;
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: Offset(motion * 7, motion * -12),
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.22),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.18),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 42,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Transform.translate(
                        offset: Offset(motion * -4, motion * 6),
                        child: Text(
                          localizations.vaultLocked,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      ElevatedButton.icon(
                        onPressed: _reauthenticate,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(localizations.unlockVault),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return AppScaffold(
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
                IconButton(
                  tooltip: localizations.filter,
                  onPressed: _showFilterDialog,
                  icon: Icon(
                    _selectedCollection == _SmartCollection.all
                        ? Icons.tune_rounded
                        : Icons.filter_alt_rounded,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.health_and_safety_outlined),
                  tooltip: 'Password Health',
                  onPressed: _openPasswordHealth,
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildVaultContent(),
          ),
          if (!_isSelectMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _isSearchActive
                  ? _buildSearchOverlay(localizations)
                  : _buildBottomBar(localizations),
            ),
        ],
      ),
    );
  }

  Widget _buildVaultContent() {
    final localizations = AppLocalizations.of(context);

    if (_entries.isEmpty) {
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
              _entries.isEmpty
                  ? localizations.noPasswords
                  : localizations.noData,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
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
        if (hasFavorites) SliverToBoxAdapter(child: _buildFavoritesStrip()),

        // Stats
        SliverToBoxAdapter(child: _buildStatsCard()),

        // Entries List
        if (_filteredEntries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 110),
                child: Text(
                  localizations.noData,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final entry = _filteredEntries[index];
                return _buildEntryCard(entry);
              },
              childCount: _filteredEntries.length,
            ),
          ),

        // Bottom padding so last item isn't hidden behind the bottom bar
        const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
      ],
    );
  }

  Widget _buildFavoritesStrip() {
    final favorites = _entries.where((e) => e.isFavorite).toList();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;

    // Trigger area — hover (desktop), tap, or swipe-down (mobile) expands it.
    return MouseRegion(
      onEnter: isDesktop ? (_) => _showFavorites() : null,
      child: GestureDetector(
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
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: GlassCard(
                    borderRadius: 24,
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: Colors.amber,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Favorites',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  favorites.length.toString(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: 'Hide favorites',
                                onPressed: () {
                                  _favoritesTimer?.cancel();
                                  setState(() => _favoritesExpanded = false);
                                },
                                icon: const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 92,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                            itemCount: favorites.length,
                            itemBuilder: (context, index) {
                              final entry = favorites[index];
                              final isPassword =
                                  entry.type == VaultEntryType.password;
                              final accent = entry.type == VaultEntryType.sshKey
                                  ? colors.secondary
                                  : entry.type == VaultEntryType.certificate
                                      ? colors.tertiary
                                      : isPassword
                                          ? colors.primary
                                          : colors.tertiary;

                              return SizedBox(
                                width: 148,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _copyPrimaryValue(entry);
                                    },
                                    onLongPress: () =>
                                        _showQuickCopySheet(entry),
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.09),
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.15),
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: accent.withValues(
                                                  alpha: 0.16),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              _entryIcon(entry),
                                              size: 18,
                                              color: accent,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  entry.displayTitle,
                                                  style: theme
                                                      .textTheme.labelLarge
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _entryTypeLabel(entry),
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: theme.textTheme
                                                        .bodySmall?.color
                                                        ?.withValues(
                                                            alpha: 0.70),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _showFavorites,
                      child: Ink(
                        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.10),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.18),
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 17, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text(
                              'Favorites',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              favorites.length.toString(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_down_rounded,
                                size: 18, color: Colors.amber.shade800),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final localizations = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              count: _entries
                  .where((entry) => entry.type == VaultEntryType.password)
                  .length
                  .toString(),
              label: localizations.passwords,
              icon: Icons.key_rounded,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatItem(
              count: _entries
                  .where(
                    (entry) =>
                        entry.type == VaultEntryType.sshKey ||
                        entry.type == VaultEntryType.certificate,
                  )
                  .length
                  .toString(),
              label: 'Keys & certs',
              icon: Icons.verified_user_outlined,
              color: colors.tertiary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatItem(
              count: _entries.length.toString(),
              label: localizations.all,
              icon: Icons.grid_view_rounded,
              color: colors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String count,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$label: $count',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: textTheme.bodySmall?.color?.withValues(alpha: 0.78),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(VaultEntry entry) {
    final isPassword = entry.type == VaultEntryType.password;
    final isSelected = _selectedIds.contains(entry.id);
    final isOld =
        isPassword && DateTime.now().difference(entry.updatedAt).inDays > 90;
    final theme = Theme.of(context);
    final themeExtension = theme.extension<AppThemeExtension>();
    final entryAccent = entry.color ??
        themeExtension?.categoryColors[entry.category.toLowerCase()] ??
        theme.colorScheme.primary;

    final card = GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leftAccentColor: entryAccent,
      color:
          isSelected ? theme.colorScheme.primary.withValues(alpha: 0.12) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: _isSelectMode
            ? () => _toggleSelect(entry.id)
            : () => _viewEntry(entry),
        onLongPress: () {
          if (_isSelectMode) {
            _toggleSelect(entry.id);
          } else {
            _showQuickCopySheet(entry);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              // Checkbox in select mode, category-coloured icon otherwise.
              if (_isSelectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelect(entry.id),
                )
              else
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: entryAccent.withValues(alpha: 0.13),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _entryIcon(entry),
                    color: entryAccent,
                    size: 21,
                  ),
                ),
              const SizedBox(width: 10),

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
                            style: theme.textTheme.titleMedium,
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
                    if (isPassword &&
                        entry.username != null &&
                        entry.username!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.username!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: CategoryBadge(
                            category: entry.displayCategory,
                          ),
                        ),
                        if (!isPassword) ...[
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              _entryTypeLabel(entry),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: entryAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (isPassword) ...[
                          const SizedBox(width: 9),
                          _buildPasswordStrengthIndicator(
                            context,
                            entry.password ?? '',
                          ),
                        ],
                      ],
                    ),
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
                        final idx =
                            _entries.indexWhere((e) => e.id == entry.id);
                        if (idx != -1) {
                          setState(() {
                            _entries[idx] = updated;
                          });
                          _applyFilters();
                        }
                        await VaultService.updateEntry(
                            updated, _getSessionKey());
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
                        _copyPrimaryValue(entry);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 19),
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
              topLeft: Radius.circular(28),
              bottomLeft: Radius.circular(28),
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
              topRight: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
        ],
      ),
      child: card,
    );
  }

  IconData _entryIcon(VaultEntry entry) {
    switch (entry.type) {
      case VaultEntryType.note:
        return Icons.sticky_note_2_rounded;
      case VaultEntryType.sshKey:
        return Icons.terminal_rounded;
      case VaultEntryType.certificate:
        return Icons.verified_user_rounded;
      case VaultEntryType.password:
        break;
    }

    switch (entry.category.toLowerCase()) {
      case 'banking':
        return Icons.account_balance_rounded;
      case 'work':
        return Icons.work_outline_rounded;
      case 'social':
        return Icons.people_outline_rounded;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'entertainment':
        return Icons.movie_outlined;
      case 'security':
        return Icons.shield_outlined;
      case 'personal':
        return Icons.person_outline_rounded;
      default:
        return Icons.lock_outline_rounded;
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

  void _copyPrimaryValue(VaultEntry entry) {
    String? value;
    String label;
    switch (entry.type) {
      case VaultEntryType.password:
        value = entry.password;
        label = 'Password copied';
        break;
      case VaultEntryType.note:
        value = entry.content;
        label = 'Content copied';
        break;
      case VaultEntryType.sshKey:
        // A public key is the safe default for a one-tap copy action.
        value = entry.publicKey;
        label = 'Public key copied';
        break;
      case VaultEntryType.certificate:
        value = entry.certificateData;
        label = 'Certificate copied';
        break;
    }
    if (value == null || value.isEmpty) {
      _viewEntry(entry);
      return;
    }
    ClipboardService.copyContent(value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label · 15s'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(
      BuildContext context, String password) {
    final strength = PasswordGeneratorService.calculateStrength(password);
    final color = PasswordGeneratorService.getStrengthColor(strength);

    return Container(
      width: 56,
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

  void _openSearch() {
    setState(() => _isSearchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() {
      _isSearchActive = false;
      _searchQuery = '';
    });
    _applyFilters();
  }

  Widget _buildBottomBar(AppLocalizations l) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final hintColor = ext?.textTertiary ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    final iconColor = ext?.textSecondary ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: [
            // Search pill
            Expanded(
              child: GestureDetector(
                onTap: _openSearch,
                child: GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: iconColor),
                      const SizedBox(width: 8),
                      Text(
                        l.searchPlaceholder,
                        style: TextStyle(fontSize: 14, color: hintColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _buildQuickLockButton(l),
            const SizedBox(width: 10),
            ThemedFab(onPressed: _addEntry, tooltip: l.addPassword),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLockButton(AppLocalizations l) {
    final theme = Theme.of(context);
    final ext = theme.extension<AppThemeExtension>();
    final accent = ext?.primaryAccent ?? theme.colorScheme.primary;

    return Tooltip(
      message: l.lockVault,
      child: Semantics(
        button: true,
        label: l.lockVault,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _lockVault,
            child: Ink(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.20)),
              ),
              child: Icon(Icons.lock_outline_rounded, color: accent, size: 22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(AppLocalizations l) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final accent = ext?.primaryAccent ?? Theme.of(context).colorScheme.primary;
    final textColor =
        ext?.textPrimary ?? Theme.of(context).colorScheme.onSurface;
    final hintColor = ext?.textTertiary ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: SafeArea(
        bottom: keyboardHeight == 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Quick actions above the search field
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildQuickLockButton(l),
                  const SizedBox(width: 10),
                  ThemedFab(onPressed: _addEntry, tooltip: l.addPassword),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: TextStyle(fontSize: 15, color: textColor),
                        decoration: InputDecoration(
                          hintText: l.searchPlaceholder,
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) {
                          setState(() => _searchQuery = v);
                          _applyFilters();
                        },
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _applyFilters();
                        },
                        child: Icon(Icons.cancel_rounded,
                            size: 18, color: hintColor),
                      ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _closeSearch,
                      child: Icon(Icons.keyboard_hide_rounded,
                          size: 22, color: hintColor),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SortBottomSheet(
        sortBy: _sortBy,
        sortAscending: _sortAscending,
        selectedCollection: _selectedCollection,
        health: _healthSnapshot(),
        entryCount: _entries.length,
        favoriteCount: _entries.where((entry) => entry.isFavorite).length,
        onChanged: (sortBy, ascending) {
          setState(() {
            _sortBy = sortBy;
            _sortAscending = ascending;
          });
          _applyFilters();
        },
        onCollectionChanged: _selectCollection,
      ),
    );
  }
}

// ── Sort bottom sheet ────────────────────────────────────────────────────────

class _SortBottomSheet extends StatefulWidget {
  final String sortBy;
  final bool sortAscending;
  final _SmartCollection selectedCollection;
  final _VaultHealthSnapshot health;
  final int entryCount;
  final int favoriteCount;
  final void Function(String sortBy, bool ascending) onChanged;
  final ValueChanged<_SmartCollection> onCollectionChanged;

  const _SortBottomSheet({
    required this.sortBy,
    required this.sortAscending,
    required this.selectedCollection,
    required this.health,
    required this.entryCount,
    required this.favoriteCount,
    required this.onChanged,
    required this.onCollectionChanged,
  });

  @override
  State<_SortBottomSheet> createState() => _SortBottomSheetState();
}

class _SortBottomSheetState extends State<_SortBottomSheet> {
  late String _sortBy;
  late bool _sortAscending;
  late _SmartCollection _selectedCollection;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _sortAscending = widget.sortAscending;
    _selectedCollection = widget.selectedCollection;
  }

  void _update(String sortBy, bool ascending) {
    setState(() {
      _sortBy = sortBy;
      _sortAscending = ascending;
    });
    widget.onChanged(sortBy, ascending);
  }

  void _updateCollection(_SmartCollection collection) {
    setState(() => _selectedCollection = collection);
    widget.onCollectionChanged(collection);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final accent = theme.colorScheme.primary;

    final sortOptions = [
      (value: 'name', label: l.name, icon: Icons.sort_by_alpha),
      (value: 'date', label: l.date, icon: Icons.calendar_today_outlined),
      (value: 'category', label: l.category, icon: Icons.label_outline),
      (value: 'strength', label: l.strength, icon: Icons.shield_outlined),
    ];
    final collectionOptions = [
      (
        collection: _SmartCollection.all,
        label: l.all,
        icon: Icons.grid_view_rounded,
        count: widget.entryCount,
        color: accent,
      ),
      (
        collection: _SmartCollection.favorites,
        label: l.favorites,
        icon: Icons.star_rounded,
        count: widget.favoriteCount,
        color: Colors.amber,
      ),
      (
        collection: _SmartCollection.weak,
        label: l.weak,
        icon: Icons.warning_amber_rounded,
        count: widget.health.weakEntryIds.length,
        color: const Color(0xFFEF4444),
      ),
      (
        collection: _SmartCollection.old,
        label: l.oldPasswords,
        icon: Icons.schedule_rounded,
        count: widget.health.oldEntryIds.length,
        color: const Color(0xFFF97316),
      ),
      (
        collection: _SmartCollection.reused,
        label: l.duplicatePasswords,
        icon: Icons.content_copy_rounded,
        count: widget.health.reusedEntryIds.length,
        color: const Color(0xFFFF6B35),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Smart collections
              Text(
                l.smartCollections,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: collectionOptions
                    .map((option) => _collectionButton(
                          collection: option.collection,
                          label: option.label,
                          icon: option.icon,
                          count: option.count,
                          color: option.color,
                        ))
                    .toList(),
              ),

              const SizedBox(height: 22),

              // Sort title
              Text(
                l.sortBy,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 14),

              // Sort options grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 3.2,
                children: sortOptions.map((opt) {
                  final isSelected = _sortBy == opt.value;
                  return GestureDetector(
                    onTap: () => _update(opt.value, _sortAscending),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.withValues(alpha: 0.15)
                            : onSurface.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? accent : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            opt.icon,
                            size: 16,
                            color: isSelected
                                ? accent
                                : onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? accent
                                  : onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Sort direction
              Text(
                l.sort,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _directionButton(
                    context,
                    label: l.ascending,
                    icon: Icons.arrow_upward_rounded,
                    selected: _sortAscending,
                    accent: accent,
                    onSurface: onSurface,
                    onTap: () => _update(_sortBy, true),
                  ),
                  const SizedBox(width: 10),
                  _directionButton(
                    context,
                    label: l.descending,
                    icon: Icons.arrow_downward_rounded,
                    selected: !_sortAscending,
                    accent: accent,
                    onSurface: onSurface,
                    onTap: () => _update(_sortBy, false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _collectionButton({
    required _SmartCollection collection,
    required String label,
    required IconData icon,
    required int count,
    required Color color,
  }) {
    final selected = _selectedCollection == collection;

    return Semantics(
      button: true,
      selected: selected,
      label: '$label: $count',
      child: GestureDetector(
        onTap: () => _updateCollection(collection),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.50)
                  : color.withValues(alpha: 0.14),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.18 : 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _directionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required Color accent,
    required Color onSurface,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 48,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.15)
                : onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? accent : onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
