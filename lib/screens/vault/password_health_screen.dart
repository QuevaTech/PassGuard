import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:passguard_vault_v0/models/vault_entry.dart';
import 'package:passguard_vault_v0/services/vault_service.dart';
import 'package:passguard_vault_v0/services/password_generator_service.dart';
import '../../utils/app_localizations.dart';
import 'entry_detail_screen.dart';

class PasswordHealthScreen extends StatefulWidget {
  final Uint8List rawKey;

  const PasswordHealthScreen({super.key, required this.rawKey});

  @override
  State<PasswordHealthScreen> createState() => _PasswordHealthScreenState();
}

class _PasswordHealthScreenState extends State<PasswordHealthScreen> {
  bool _isLoading = true;
  List<VaultEntry> _weak = [];
  List<VaultEntry> _old = [];
  List<VaultEntry> _duplicate = [];
  int _score = 0;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    setState(() => _isLoading = true);
    final entries = await VaultService.getAllEntries(widget.rawKey);
    final passwords = entries.where((e) => e.type == VaultEntryType.password).toList();

    final weak = <VaultEntry>[];
    final old = <VaultEntry>[];
    final pwMap = <String, List<VaultEntry>>{};

    for (final e in passwords) {
      final pw = e.password ?? '';
      if (pw.isNotEmpty) {
        final strength = PasswordGeneratorService.calculateStrength(pw);
        if (strength < 40) weak.add(e);
        pwMap.putIfAbsent(pw, () => []).add(e);
      }
      if (DateTime.now().difference(e.updatedAt).inDays > 90) old.add(e);
    }

    final duplicate = pwMap.entries
        .where((e) => e.value.length > 1)
        .expand((e) => e.value)
        .toList();

    // Score: start 100, deduct per issue
    int score = 100;
    if (passwords.isEmpty) {
      score = 100;
    } else {
      score -= (weak.length * 15).clamp(0, 40);
      score -= (old.length * 5).clamp(0, 30);
      score -= (duplicate.length * 10).clamp(0, 30);
      score = score.clamp(0, 100);
    }

    setState(() {
      _weak = weak;
      _old = old;
      _duplicate = duplicate;
      _score = score;
      _isLoading = false;
    });
  }

  Color _scoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  String _scoreLabel(int score, AppLocalizations l) {
    if (score >= 80) return l.scoreGood;
    if (score >= 50) return l.scoreFair;
    return l.scorePoor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.passwordHealth),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _analyze,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _analyze,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Score card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(l.securityScore,
                              style: theme.textTheme.titleMedium),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _score / 100,
                                  strokeWidth: 10,
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation(
                                      _scoreColor(_score)),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_score',
                                      style: theme.textTheme.headlineMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: _scoreColor(_score),
                                      ),
                                    ),
                                    Text(
                                      _scoreLabel(_score, l),
                                      style: TextStyle(
                                          color: _scoreColor(_score),
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _StatChip(
                                  label: l.weak,
                                  count: _weak.length,
                                  color: Colors.red),
                              _StatChip(
                                  label: l.oldPasswords,
                                  count: _old.length,
                                  color: Colors.orange),
                              _StatChip(
                                  label: l.duplicatePasswords,
                                  count: _duplicate.length,
                                  color: Colors.deepOrange),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_weak.isEmpty && _old.isEmpty && _duplicate.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 48, color: Colors.green),
                            const SizedBox(height: 12),
                            Text(l.allPasswordsGood,
                                style: theme.textTheme.titleMedium),
                          ],
                        ),
                      ),
                    ),

                  if (_weak.isNotEmpty) ...[
                    _SectionHeader(
                        icon: Icons.warning_amber_rounded,
                        color: Colors.red,
                        title: '${l.weakPasswords} (${_weak.length})'),
                    ..._weak.map((e) => _EntryTile(
                        entry: e,
                        rawKey: widget.rawKey,
                        subtitle: l.strengthTooLow)),
                    const SizedBox(height: 8),
                  ],

                  if (_old.isNotEmpty) ...[
                    _SectionHeader(
                        icon: Icons.schedule,
                        color: Colors.orange,
                        title: '${l.oldPasswords} (${_old.length})'),
                    ..._old.map((e) => _EntryTile(
                        entry: e,
                        rawKey: widget.rawKey,
                        subtitle: l.notUpdated90)),
                    const SizedBox(height: 8),
                  ],

                  if (_duplicate.isNotEmpty) ...[
                    _SectionHeader(
                        icon: Icons.content_copy,
                        color: Colors.deepOrange,
                        title: '${l.duplicatePasswords} (${_duplicate.length})'),
                    ..._duplicate.map((e) => _EntryTile(
                        entry: e,
                        rawKey: widget.rawKey,
                        subtitle: l.samePasswordElsewhere)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: color)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;

  const _SectionHeader(
      {required this.icon, required this.color, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final VaultEntry entry;
  final Uint8List rawKey;
  final String subtitle;

  const _EntryTile(
      {required this.entry, required this.rawKey, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: const Icon(Icons.lock),
        title: Text(entry.displayTitle, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                EntryDetailScreen(entry: entry, rawKey: rawKey),
          ),
        ),
      ),
    );
  }
}
