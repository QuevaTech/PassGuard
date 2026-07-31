// Generates the product screenshots used by README.md.
//
// Run one screen at a time from the project root:
//
//   flutter run -d macos -t tool/readme_screens.dart \
//     --dart-define=SCREENSHOT=overview
//
// Accepted values: overview, filters, locked, theme-light, theme-dark, health.
// The data below is fictional and is never loaded into, saved to, or otherwise
// connected to a vault.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:passguard_vault/theme/app_theme_style.dart';
import 'package:passguard_vault/utils/app_theme.dart';
import 'package:passguard_vault/widgets/app_scaffold.dart';
import 'package:passguard_vault/widgets/category_badge.dart';
import 'package:passguard_vault/widgets/glass_card.dart';
import 'package:passguard_vault/widgets/themed_fab.dart';

const _screen = String.fromEnvironment('SCREENSHOT', defaultValue: 'overview');
const _imageWidth = 440.0;
const _imageHeight = 920.0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ReadmeScreenshotApp());
}

class _ReadmeScreenshotApp extends StatelessWidget {
  const _ReadmeScreenshotApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(
        AppThemeStyle.vault,
        _screen == 'theme-light' ? Brightness.light : Brightness.dark,
      ),
      home: const _ScreenshotExporter(),
    );
  }
}

class _ScreenshotExporter extends StatefulWidget {
  const _ScreenshotExporter();

  @override
  State<_ScreenshotExporter> createState() => _ScreenshotExporterState();
}

class _ScreenshotExporterState extends State<_ScreenshotExporter> {
  final _boundaryKey = GlobalKey();
  var _saved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _export());
  }

  Future<void> _export() async {
    if (_saved) return;
    _saved = true;

    // Let backdrop filters and the first frame settle before capturing.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final boundary = _boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    final output = File(
      '${Directory.current.path}/docs/images/passguard-${_safeScreenName()}.png',
    );
    await output.parent.create(recursive: true);
    await output.writeAsBytes(data!.buffer.asUint8List());

    // Keep the preview visible for manual review. Stop it with Ctrl+C after
    // checking it; the PNG has already been written at this point.
  }

  String _safeScreenName() {
    switch (_screen) {
      case 'filters':
      case 'locked':
      case 'theme-light':
      case 'theme-dark':
      case 'health':
        return _screen;
      default:
        return 'overview';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF10142C),
      child: Center(
        child: RepaintBoundary(
          key: _boundaryKey,
          child: Container(
            width: _imageWidth,
            height: _imageHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF11142B),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0x33D4B038)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  blurRadius: 38,
                  offset: Offset(0, 20),
                ),
              ],
            ),
            child: _screenBody(),
          ),
        ),
      ),
    );
  }

  Widget _screenBody() {
    switch (_screen) {
      case 'filters':
        return const _FilterPreview();
      case 'locked':
        return const _LockedPreview();
      case 'theme-light':
        return const _ThemePreview(selectedBrightness: Brightness.light);
      case 'theme-dark':
        return const _ThemePreview(selectedBrightness: Brightness.dark);
      case 'health':
        return const _PasswordHealthPreview();
      default:
        return const _VaultOverviewPreview();
    }
  }
}

class _VaultOverviewPreview extends StatelessWidget {
  const _VaultOverviewPreview();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: _vaultAppBar(context),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: const [
              _DemoGreeting(),
              _FavoritesPreview(),
              _StatsPreview(),
              _SectionLabel('RECENTLY UPDATED'),
              _EntryPreview(
                icon: Icons.account_balance_rounded,
                title: 'Kite & Quill',
                username: 'vault.demo@sample.invalid',
                category: 'Banking',
                favorite: true,
                color: Color(0xFF16A34A),
                strength: 0.94,
              ),
              _EntryPreview(
                icon: Icons.cloud_outlined,
                title: 'Pebble Lantern',
                username: 'cloud.demo@sample.invalid',
                category: 'Personal',
                favorite: true,
                color: Color(0xFFD4B038),
                strength: 0.82,
              ),
              _EntryPreview(
                icon: Icons.palette_outlined,
                title: 'Orchid Tally',
                username: 'studio.demo@sample.invalid',
                category: 'Work',
                color: Color(0xFFD87E37),
                strength: 1,
              ),
              _EntryPreview(
                icon: Icons.shopping_bag_outlined,
                title: 'Velvet Compass',
                username: 'shop.demo@sample.invalid',
                category: 'Shopping',
                color: Color(0xFF06B6D4),
                strength: 0.76,
              ),
            ],
          ),
          const Align(
              alignment: Alignment.bottomCenter, child: _BottomActions()),
        ],
      ),
    );
  }
}

class _FilterPreview extends StatelessWidget {
  const _FilterPreview();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: _vaultAppBar(context, activeFilter: true),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.42,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: const [
                _DemoGreeting(),
                _StatsPreview(),
                _SectionLabel('ALL ENTRIES'),
                _EntryPreview(
                  icon: Icons.account_balance_rounded,
                  title: 'Kite & Quill',
                  username: 'vault.demo@sample.invalid',
                  category: 'Banking',
                  favorite: true,
                  color: Color(0xFF16A34A),
                  strength: 0.94,
                ),
                _EntryPreview(
                  icon: Icons.cloud_outlined,
                  title: 'Pebble Lantern',
                  username: 'cloud.demo@sample.invalid',
                  category: 'Personal',
                  color: Color(0xFFD4B038),
                  strength: 0.82,
                ),
              ],
            ),
          ),
          const Align(
              alignment: Alignment.bottomCenter, child: _SmartFilterSheet()),
        ],
      ),
    );
  }
}

class _LockedPreview extends StatelessWidget {
  const _LockedPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return AppScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.shield_rounded, color: accent, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Text('PassGuard Vault', style: theme.textTheme.titleLarge),
                ],
              ),
              const Spacer(),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Icon(Icons.lock_rounded, color: accent, size: 50),
              ),
              const SizedBox(height: 28),
              Text(
                'Vault locked',
                style: theme.textTheme.displayLarge?.copyWith(fontSize: 27),
              ),
              const SizedBox(height: 12),
              Text(
                'Your session key has been cleared.\nUnlock to continue securely.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.lock_open_rounded),
                  label: const Text('Unlock vault'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'OFFLINE · END-TO-END ENCRYPTED',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.privacy_tip_outlined, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your vault stays on this device. No account required.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final Brightness selectedBrightness;

  const _ThemePreview({required this.selectedBrightness});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final isLight = selectedBrightness == Brightness.light;

    return AppScaffold(
      appBar: AppBar(
        title: Text('Settings',
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Icon(Icons.tune_rounded, size: 22),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _SectionLabel('APPEARANCE'),
          GlassCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child:
                          Icon(Icons.palette_outlined, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Theme', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 3),
                          Text(
                            'Choose how PassGuard looks on this device.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 19),
                Row(
                  children: [
                    _ThemeChoice(
                      icon: Icons.light_mode_rounded,
                      label: 'Light',
                      selected: isLight,
                    ),
                    const SizedBox(width: 8),
                    _ThemeChoice(
                      icon: Icons.dark_mode_rounded,
                      label: 'Dark',
                      selected: !isLight,
                    ),
                    const SizedBox(width: 8),
                    const _ThemeChoice(
                      icon: Icons.brightness_auto_rounded,
                      label: 'System',
                      selected: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('VAULT STYLE'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const _SettingsRow(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Vault',
                  subtitle: 'Warm, focused and private',
                  selected: true,
                ),
                Divider(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.10)),
                const _SettingsRow(
                  icon: Icons.layers_outlined,
                  title: 'Stratum',
                  subtitle: 'Clear and minimal',
                ),
                Divider(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.10)),
                const _SettingsRow(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Cipher',
                  subtitle: 'High-contrast neon',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, color: accent, size: 21),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    isLight
                        ? 'Light mode is active for comfortable daytime use.'
                        : 'Dark mode is active for a focused, low-glare view.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;

  const _ThemeChoice({
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.14) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : theme.colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected
                    ? accent
                    : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? accent : null,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (selected ? accent : theme.colorScheme.secondary)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 19,
                color: selected ? accent : theme.colorScheme.secondary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(subtitle, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: accent, size: 21),
        ],
      ),
    );
  }
}

class _PasswordHealthPreview extends StatelessWidget {
  const _PasswordHealthPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    const scoreColor = Color(0xFF22C55E);

    return AppScaffold(
      appBar: AppBar(
        title: Text('Password health',
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Icon(Icons.refresh_rounded, size: 22),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'SECURITY SCORE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 17),
                SizedBox(
                  width: 126,
                  height: 126,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: 0.82,
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.09),
                          valueColor: const AlwaysStoppedAnimation(scoreColor),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('82',
                              style: theme.textTheme.displayLarge
                                  ?.copyWith(color: scoreColor, fontSize: 37)),
                          Text('Good',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: scoreColor,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    _HealthStat(
                        label: 'Weak', count: '0', color: Color(0xFF22C55E)),
                    _HealthStat(
                        label: 'Old', count: '2', color: Color(0xFFF97316)),
                    _HealthStat(
                        label: 'Reused', count: '0', color: Color(0xFF22C55E)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: Color(0xFFF97316), size: 20),
              const SizedBox(width: 8),
              Text('UPDATE RECOMMENDED',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      letterSpacing: 0.9,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          const _HealthIssue(
            icon: Icons.cloud_outlined,
            title: 'Pebble Lantern',
            detail: 'Last updated 124 days ago',
            color: Color(0xFFF97316),
          ),
          const _HealthIssue(
            icon: Icons.palette_outlined,
            title: 'Orchid Tally',
            detail: 'Last updated 96 days ago',
            color: Color(0xFFF97316),
          ),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: accent, size: 21),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'Refresh passwords you have not updated in 90 days.',
                        style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthStat extends StatelessWidget {
  final String label;
  final String count;
  final Color color;

  const _HealthStat(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(count,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _HealthIssue extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final Color color;

  const _HealthIssue({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 7),
      leftAccentColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(detail, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: color, size: 23),
        ],
      ),
    );
  }
}

PreferredSizeWidget _vaultAppBar(BuildContext context,
    {bool activeFilter = false}) {
  return AppBar(
    title: Text(
      'Passwords',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 19),
    ),
    actions: [
      Icon(
        activeFilter ? Icons.filter_alt_rounded : Icons.tune_rounded,
        size: 22,
      ),
      const SizedBox(width: 17),
      const Icon(Icons.health_and_safety_outlined, size: 22),
      const SizedBox(width: 17),
      const Icon(Icons.settings_outlined, size: 22),
      const SizedBox(width: 17),
    ],
  );
}

class _DemoGreeting extends StatelessWidget {
  const _DemoGreeting();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Everything, protected.',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Your private vault · stored locally',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: accent.withValues(alpha: 0.13),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Text(
              'LOCAL',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: accent,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoritesPreview extends StatelessWidget {
  const _FavoritesPreview();

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0x29FFC107),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Favorites',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Text('2',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StatsPreview extends StatelessWidget {
  const _StatsPreview();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          _StatPreview(
              value: '7',
              label: 'Passwords',
              icon: Icons.key_rounded,
              color: colors.primary),
          const SizedBox(width: 7),
          _StatPreview(
              value: '2',
              label: 'Notes',
              icon: Icons.sticky_note_2_rounded,
              color: colors.tertiary),
          const SizedBox(width: 7),
          _StatPreview(
              value: '9',
              label: 'All',
              icon: Icons.grid_view_rounded,
              color: colors.secondary),
        ],
      ),
    );
  }
}

class _StatPreview extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatPreview({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.17)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w800,
                    )),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 5),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EntryPreview extends StatelessWidget {
  final IconData icon;
  final String title;
  final String username;
  final String category;
  final bool favorite;
  final Color color;
  final double strength;

  const _EntryPreview({
    required this.icon,
    required this.title,
    required this.username,
    required this.category,
    this.favorite = false,
    required this.color,
    required this.strength,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leftAccentColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 6),
                Row(
                  children: [
                    CategoryBadge(category: category),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: strength,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          valueColor:
                              const AlwaysStoppedAnimation(Color(0xFF22C55E)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (favorite)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.star_rounded, color: Colors.amber, size: 21),
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.copy_rounded, size: 19),
            ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.60);
    final accent = theme.colorScheme.primary;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
        child: Row(
          children: [
            Expanded(
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 19, color: iconColor),
                    const SizedBox(width: 8),
                    Text('Search your vault', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            Container(
              width: 49,
              height: 49,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.23)),
                color: accent.withValues(alpha: 0.10),
              ),
              child: Icon(Icons.lock_outline_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 9),
            ThemedFab(onPressed: () {}, tooltip: 'Add password'),
          ],
        ),
      ),
    );
  }
}

class _SmartFilterSheet extends StatelessWidget {
  const _SmartFilterSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        decoration: BoxDecoration(
          color: const Color(0xFF252B4E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: accent.withValues(alpha: 0.20)),
          boxShadow: const [
            BoxShadow(
                color: Color(0xAA000000), blurRadius: 24, offset: Offset(0, -8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 17),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: accent, size: 20),
                const SizedBox(width: 9),
                Text('Smart collections', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            const _CollectionRow(
                icon: Icons.grid_view_rounded,
                label: 'All entries',
                count: '9',
                selected: true),
            const _CollectionRow(
                icon: Icons.star_rounded,
                label: 'Favorites',
                count: '2',
                color: Colors.amber),
            const _CollectionRow(
                icon: Icons.warning_amber_rounded,
                label: 'Weak passwords',
                count: '1',
                color: Color(0xFFEF4444)),
            const _CollectionRow(
                icon: Icons.schedule_rounded,
                label: 'Updated 90+ days ago',
                count: '2',
                color: Color(0xFFF97316)),
            const _CollectionRow(
                icon: Icons.content_copy_rounded,
                label: 'Reused passwords',
                count: '0',
                color: Color(0xFF06B6D4)),
            const SizedBox(height: 8),
            Divider(color: Colors.white.withValues(alpha: 0.10)),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.sort_rounded,
                    size: 19, color: theme.textTheme.bodySmall?.color),
                const SizedBox(width: 9),
                Text('Sort by name', style: theme.textTheme.bodyMedium),
                const Spacer(),
                Icon(Icons.arrow_upward_rounded, color: accent, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final Color? color;
  final bool selected;

  const _CollectionRow({
    required this.icon,
    required this.label,
    required this.count,
    this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: selected ? active.withValues(alpha: 0.13) : Colors.transparent,
        border:
            selected ? Border.all(color: active.withValues(alpha: 0.26)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: active),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: active.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(999)),
            child: Text(count,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: active, fontWeight: FontWeight.w800)),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, color: active, size: 18),
          ],
        ],
      ),
    );
  }
}
