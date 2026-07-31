import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault/services/session_service.dart';
import 'package:passguard_vault/services/biometric_service.dart';
import 'package:passguard_vault/services/clipboard_service.dart';
import 'package:passguard_vault/services/password_generator_service.dart';
import 'vault/vault_screen.dart';
import 'settings/settings_screen.dart';
import 'auth/login_screen.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/glass_card.dart';
import '../../theme/app_theme_extension.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  bool _isLocked = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _isLocked = SessionService.isLocked();
    SessionService.addListener(_onSessionChange);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    SessionService.removeListener(_onSessionChange);
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _onSessionChange() {
    if (!mounted) return;
    setState(() => _isLocked = SessionService.isLocked());
  }

  Future<void> _reauthenticate() async {
    if (!SessionService.isBiometricEnabled()) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    try {
      final authenticated = await _biometricService.authenticate(
        reason: AppLocalizations.of(context).biometricAuth,
      );
      if (authenticated) {
        await SessionService.loadSessionKey();
        SessionService.unlockSession();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context).biometricFailed),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _lockSession() async => SessionService.forceLock();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: _isLocked ? _buildLockedView() : _buildUnlockedView(),
    );
  }

  // ── LOCKED ────────────────────────────────────────────────────────────────

  Widget _buildLockedView() {
    final l = AppLocalizations.of(context);
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final accent = ext?.primaryAccent ?? Theme.of(context).colorScheme.primary;
    final textPrimary =
        ext?.textPrimary ?? Theme.of(context).colorScheme.onSurface;
    final textSecondary = ext?.textSecondary ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),

            // Pulsing lock icon
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 140 * _pulseAnim.value,
                    height: 140 * _pulseAnim.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.06 * _pulseAnim.value),
                    ),
                  ),
                  // Inner ring
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                      border: Border.all(
                          color: accent.withValues(alpha: 0.30), width: 1.5),
                    ),
                  ),
                  // Icon
                  Icon(Icons.lock_rounded, size: 48, color: accent),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'PassGuard Vault',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.vaultLocked,
              style: TextStyle(fontSize: 15, color: textSecondary),
            ),

            const Spacer(flex: 3),

            // Biometric button — full width pill
            SizedBox(
              width: double.infinity,
              child: _GradientButton(
                onTap: _reauthenticate,
                gradient: ext?.ctaGradient,
                fallbackColor: accent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      l.biometricAuth,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── UNLOCKED ──────────────────────────────────────────────────────────────

  Widget _buildUnlockedView() {
    final l = AppLocalizations.of(context);
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final accent = ext?.primaryAccent ?? Theme.of(context).colorScheme.primary;
    final secondary =
        ext?.secondaryAccent ?? Theme.of(context).colorScheme.secondary;
    final textPrimary =
        ext?.textPrimary ?? Theme.of(context).colorScheme.onSurface;
    final textSecondary = ext?.textSecondary ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PassGuard',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.5,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.welcome,
                        style: TextStyle(fontSize: 14, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                // Lock button
                GlassCard(
                  padding: const EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: _lockSession,
                    child: Icon(
                      Icons.lock_open_rounded,
                      size: 22,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Settings button
                GlassCard(
                  padding: const EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen())),
                    child: Icon(
                      Icons.settings_outlined,
                      size: 22,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Hero card: Vault ─────────────────────────────────────────
            GlassCard(
              child: InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const VaultScreen())),
                borderRadius: BorderRadius.circular(ext?.cardRadius ?? 14),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      // Icon badge
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: ext?.ctaGradient ??
                              LinearGradient(colors: [accent, secondary]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.shield_rounded,
                            size: 26, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.passwords,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              l.addPassword,
                              style:
                                  TextStyle(fontSize: 12, color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: textSecondary),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Secondary cards row ──────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _SecondaryCard(
                    icon: Icons.shuffle_rounded,
                    label: l.generatePassword,
                    accent: accent,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    ext: ext,
                    onTap: () {
                      final pw = PasswordGeneratorService.generatePassword(
                        length: 16,
                        includeUppercase: true,
                        includeLowercase: true,
                        includeNumbers: true,
                        includeSymbols: true,
                      );
                      ClipboardService.copyPassword(pw);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(l.passwordCopied),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SecondaryCard(
                    icon: Icons.fingerprint_rounded,
                    label: l.biometricAuth,
                    accent: secondary,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    ext: ext,
                    onTap: _reauthenticate,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Divider label ────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child:
                      Divider(color: accent.withValues(alpha: 0.15), height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'PassGuard Vault',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: accent.withValues(alpha: 0.5),
                        letterSpacing: 0.8),
                  ),
                ),
                Expanded(
                  child:
                      Divider(color: accent.withValues(alpha: 0.15), height: 1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Secondary action card ─────────────────────────────────────────────────

class _SecondaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final AppThemeExtension? ext;
  final VoidCallback onTap;

  const _SecondaryCard({
    required this.icon,
    required this.label,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.ext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ext?.cardRadius ?? 14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gradient CTA button ───────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final VoidCallback onTap;
  final LinearGradient? gradient;
  final Color fallbackColor;
  final Widget child;

  const _GradientButton({
    required this.onTap,
    required this.gradient,
    required this.fallbackColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = fallbackColor.computeLuminance() > 0.35
        ? const Color(0xFF1b1f3b)
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? fallbackColor : null,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: fallbackColor.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: onColor,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          child: IconTheme(
            data: IconThemeData(color: onColor),
            child: child,
          ),
        ),
      ),
    );
  }
}
