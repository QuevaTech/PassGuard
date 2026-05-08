import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:passguard_vault/models/vault_entry.dart';
import 'package:passguard_vault/services/vault_service.dart';
import 'package:passguard_vault/services/password_generator_service.dart';
import '../../utils/app_localizations.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/glass_card.dart';
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
    final passwords =
        entries.where((e) => e.type == VaultEntryType.password).toList();

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

    int score = 100;
    if (passwords.isNotEmpty) {
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

  Color _scoreColor(int s) {
    if (s >= 80) return const Color(0xFF22C55E);
    if (s >= 50) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String _scoreLabel(int s, AppLocalizations l) {
    if (s >= 80) return l.scoreGood;
    if (s >= 50) return l.scoreFair;
    return l.scorePoor;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final accent = ext?.primaryAccent ?? Theme.of(context).colorScheme.primary;
    final textPrimary =
        ext?.textPrimary ?? Theme.of(context).colorScheme.onSurface;
    final textSecondary = ext?.textSecondary ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return AppScaffold(
      appBar: AppBar(
        title: Text(l.passwordHealth),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _analyze),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: accent),
            )
          : RefreshIndicator(
              onRefresh: _analyze,
              color: accent,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ── Score card ───────────────────────────────────────────
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          l.securityScore,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: _score / 100,
                                  strokeWidth: 9,
                                  strokeCap: StrokeCap.round,
                                  backgroundColor:
                                      textPrimary.withValues(alpha: 0.08),
                                  valueColor: AlwaysStoppedAnimation(
                                      _scoreColor(_score)),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$_score',
                                    style: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w800,
                                      color: _scoreColor(_score),
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _scoreLabel(_score, l),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _scoreColor(_score)
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statChip(
                                context, l.weak, _weak.length, const Color(0xFFEF4444)),
                            _divider(context),
                            _statChip(context, l.oldPasswords, _old.length,
                                const Color(0xFFF97316)),
                            _divider(context),
                            _statChip(context, l.duplicatePasswords,
                                _duplicate.length, const Color(0xFFFF6B35)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── All good ─────────────────────────────────────────────
                  if (_weak.isEmpty && _old.isEmpty && _duplicate.isEmpty)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 28),
                      child: Column(
                        children: [
                          Icon(Icons.verified_rounded,
                              size: 52,
                              color: const Color(0xFF22C55E)
                                  .withValues(alpha: 0.9)),
                          const SizedBox(height: 12),
                          Text(
                            l.allPasswordsGood,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                  // ── Weak ─────────────────────────────────────────────────
                  if (_weak.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _sectionHeader(context, Icons.warning_amber_rounded,
                        const Color(0xFFEF4444),
                        '${l.weakPasswords} (${_weak.length})'),
                    ..._weak.map((e) => _EntryTile(
                        entry: e, rawKey: widget.rawKey, subtitle: l.strengthTooLow)),
                    const SizedBox(height: 8),
                  ],

                  // ── Old ──────────────────────────────────────────────────
                  if (_old.isNotEmpty) ...[
                    _sectionHeader(context, Icons.schedule,
                        const Color(0xFFF97316),
                        '${l.oldPasswords} (${_old.length})'),
                    ..._old.map((e) => _EntryTile(
                        entry: e, rawKey: widget.rawKey, subtitle: l.notUpdated90)),
                    const SizedBox(height: 8),
                  ],

                  // ── Duplicate ────────────────────────────────────────────
                  if (_duplicate.isNotEmpty) ...[
                    _sectionHeader(context, Icons.content_copy,
                        const Color(0xFFFF6B35),
                        '${l.duplicatePasswords} (${_duplicate.length})'),
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

  Widget _statChip(
      BuildContext context, String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    return Container(
      width: 1,
      height: 36,
      color: (ext?.textTertiary ??
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))
          .withValues(alpha: 0.3),
    );
  }

  Widget _sectionHeader(
      BuildContext context, IconData icon, Color color, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entry tile ───────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final VaultEntry entry;
  final Uint8List rawKey;
  final String subtitle;

  const _EntryTile(
      {required this.entry, required this.rawKey, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final textPrimary =
        ext?.textPrimary ?? Theme.of(context).colorScheme.onSurface;
    final textSecondary = ext?.textSecondary ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final accent = ext?.primaryAccent ?? Theme.of(context).colorScheme.primary;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EntryDetailScreen(entry: entry, rawKey: rawKey),
          ),
        ),
        borderRadius: BorderRadius.circular(ext?.cardRadius ?? 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lock_outline, size: 18, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                  size: 18,
                  color: textSecondary.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}
