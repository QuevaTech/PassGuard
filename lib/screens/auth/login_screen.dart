import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault/services/vault_service.dart';
import 'package:passguard_vault/services/biometric_service.dart';
import 'package:passguard_vault/services/session_service.dart';
import 'package:passguard_vault/services/encryption_service.dart';
import 'package:passguard_vault/services/password_generator_service.dart';
import 'package:passguard_vault/services/auth_guard_service.dart';
import '../home_screen.dart';
import '../vault/vault_screen.dart';
import '../../utils/app_localizations.dart';
import '../../utils/vault_exceptions.dart';
import '../../theme/app_theme_extension.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/glass_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool isCreating;
  const LoginScreen({super.key, this.isCreating = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocus = FocusNode();

  final BiometricService _biometricService = BiometricService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _biometricAvailable = false;
  bool _biometricEnrolled = false;
  bool _enableBiometric = false;
  String _errorMessage = '';

  // Live strength bar when creating
  double _strength = 0;

  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entryCtrl.forward();

    if (widget.isCreating) {
      _passwordController.addListener(() {
        final s = PasswordGeneratorService.calculateStrength(
            _passwordController.text);
        setState(() => _strength = s / 100.0);
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocus.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      _biometricAvailable = await _biometricService.isBiometricAvailable();
      _biometricEnrolled = await _biometricService.isBiometricEnrolled();
      if (_biometricAvailable && _biometricEnrolled) {
        setState(() => _enableBiometric = true);
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!widget.isCreating && AuthGuardService.isLockedOut()) {
      final remaining = AuthGuardService.remainingLockout();
      setState(() {
        _errorMessage =
            '${AppLocalizations.of(context).tooManyAttempts} ${remaining.inSeconds} ${AppLocalizations.of(context).seconds}';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final password = _passwordController.text;

      if (widget.isCreating) {
        final confirmPassword = _confirmPasswordController.text;
        if (password != confirmPassword) {
          setState(() {
            _errorMessage = AppLocalizations.of(context).passwordsDoNotMatch;
            _isLoading = false;
          });
          return;
        }
        if (password.length < 8) {
          setState(() {
            _errorMessage = AppLocalizations.of(context).passwordTooShort;
            _isLoading = false;
          });
          return;
        }
        final strength = PasswordGeneratorService.calculateStrength(password);
        if (strength < 50) {
          setState(() {
            _errorMessage = AppLocalizations.of(context).passwordTooWeak;
            _isLoading = false;
          });
          return;
        }

        final vault = await VaultService.createNewVault(password);
        final Uint8List sessionKey =
            await VaultService.deriveSessionKey(password, vault);
        await VaultService.saveVault(vault, sessionKey);
        await SessionService.setSessionKey(sessionKey);
        EncryptionService.clearKey(sessionKey);
        SessionService.initialize(biometricEnabled: _enableBiometric);

        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        try {
          var vault = await VaultService.loadVault(password);
          var sessionKey = await VaultService.deriveSessionKey(password, vault);
          try {
            final migration = await VaultService.migrateKdfParamsIfNeeded(
                vault, password, sessionKey);
            if (migration != null) {
              EncryptionService.clearKey(sessionKey);
              vault = migration.$1;
              sessionKey = migration.$2;
            }
          } catch (e) {
            debugPrint('LoginScreen: KDF migration failed (non-fatal): $e');
          }
          await VaultService.saveVault(vault, sessionKey);
          AuthGuardService.recordSuccess();
          await SessionService.setSessionKey(sessionKey);
          EncryptionService.clearKey(sessionKey);
          SessionService.initialize(biometricEnabled: _enableBiometric);

          if (mounted) {
            Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const VaultScreen()));
          }
        } catch (e) {
          if (e is VaultVersionUnsupportedException) {
            setState(() {
              _errorMessage =
                  AppLocalizations.of(context).vaultVersionUnsupported;
              _isLoading = false;
            });
            return;
          }
          final lockedOut = AuthGuardService.recordFailedAttempt();
          setState(() {
            if (lockedOut) {
              final remaining = AuthGuardService.remainingLockout();
              _errorMessage =
                  '${AppLocalizations.of(context).tooManyAttempts} ${remaining.inSeconds} ${AppLocalizations.of(context).seconds}';
            } else {
              final left = AuthGuardService.remainingAttempts();
              _errorMessage =
                  '${AppLocalizations.of(context).invalidMasterPassword} ($left ${AppLocalizations.of(context).attemptsRemaining})';
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).somethingWentWrong;
        _isLoading = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final accent = ext?.primaryAccent ?? Theme.of(context).colorScheme.primary;
    final secondary = ext?.secondaryAccent ?? accent;
    final textPrimary =
        ext?.textPrimary ?? Theme.of(context).colorScheme.onSurface;
    final textSecondary = ext?.textSecondary ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final textTertiary = ext?.textTertiary ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);

    return AppScaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Icon header ─────────────────────────────────────
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                accent.withValues(alpha: 0.18),
                                accent.withValues(alpha: 0.0),
                              ]),
                            ),
                          ),
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.12),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.25),
                                  width: 1.5),
                            ),
                            child: Icon(
                              widget.isCreating
                                  ? Icons.add_moderator_rounded
                                  : Icons.lock_rounded,
                              size: 34,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Title ───────────────────────────────────────────
                    Text(
                      widget.isCreating
                          ? l.createMasterPassword
                          : l.unlockVault,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.isCreating
                          ? l.createMasterPassword
                          : l.enterMasterPassword,
                      style: TextStyle(fontSize: 14, color: textSecondary),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 36),

                    // ── Password field ───────────────────────────────────
                    GlassCard(
                      padding: EdgeInsets.zero,
                      child: TextFormField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        style: TextStyle(fontSize: 15, color: textPrimary),
                        decoration: InputDecoration(
                          hintText: l.masterPassword,
                          hintStyle:
                              TextStyle(color: textTertiary, fontSize: 14),
                          prefixIcon:
                              Icon(Icons.lock_outline_rounded, color: accent),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: textTertiary,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return l.enterMasterPassword;
                          if (widget.isCreating && v.length < 8) return l.passwordTooShort;
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    ),

                    // Strength bar (create mode only)
                    if (widget.isCreating && _passwordController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _StrengthBar(value: _strength, accent: accent),
                    ],

                    // ── Confirm password field ───────────────────────────
                    if (widget.isCreating) ...[
                      const SizedBox(height: 10),
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: TextStyle(fontSize: 15, color: textPrimary),
                          decoration: InputDecoration(
                            hintText: l.confirmMasterPassword,
                            hintStyle:
                                TextStyle(color: textTertiary, fontSize: 14),
                            prefixIcon: Icon(Icons.lock_person_outlined,
                                color: accent),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: textTertiary,
                                size: 20,
                              ),
                              onPressed: () => setState(() =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return l.confirmMasterPassword;
                            if (v != _passwordController.text) return l.passwordsDoNotMatch;
                            return null;
                          },
                        ),
                      ),
                    ],

                    // ── Warning banner (create mode) ─────────────────────
                    if (widget.isCreating) ...[
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.warning_amber_rounded,
                                  color: Colors.orange, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l.masterPasswordUnrecoverable,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Biometric toggle ─────────────────────────────────
                    if (_biometricAvailable && _biometricEnrolled) ...[
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.fingerprint_rounded,
                                  color: secondary, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l.enableBiometric,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: textPrimary,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            Switch(
                              value: _enableBiometric,
                              onChanged: (v) =>
                                  setState(() => _enableBiometric = v),
                              activeColor: secondary,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Error banner ─────────────────────────────────────
                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GlassCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFEF4444), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Submit button ────────────────────────────────────
                    SizedBox(
                      height: 54,
                      child: _isLoading
                          ? Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: accent),
                              ),
                            )
                          : GestureDetector(
                              onTap: _submit,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: ext?.ctaGradient ??
                                      LinearGradient(
                                          colors: [accent, secondary]),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.35),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  widget.isCreating
                                      ? l.createVault
                                      : l.unlockVault,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: accent.computeLuminance() > 0.35
                                        ? const Color(0xFF1b1f3b)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Strength bar ──────────────────────────────────────────────────────────

class _StrengthBar extends StatelessWidget {
  final double value; // 0.0–1.0
  final Color accent;

  const _StrengthBar({required this.value, required this.accent});

  Color get _color {
    if (value < 0.3) return const Color(0xFFEF4444);
    if (value < 0.6) return const Color(0xFFF97316);
    if (value < 0.8) return const Color(0xFFEAB308);
    return const Color(0xFF22C55E);
  }

  String get _label {
    if (value < 0.3) return 'Zayıf';
    if (value < 0.6) return 'Orta';
    if (value < 0.8) return 'İyi';
    return 'Güçlü';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: _color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: _color),
        ),
      ],
    );
  }
}
