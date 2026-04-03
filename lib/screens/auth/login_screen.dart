import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault_v0/services/vault_service.dart';
import 'package:passguard_vault_v0/services/biometric_service.dart';
import 'package:passguard_vault_v0/services/session_service.dart';
import 'package:passguard_vault_v0/services/encryption_service.dart';
import 'package:passguard_vault_v0/services/password_generator_service.dart';
import 'package:passguard_vault_v0/services/auth_guard_service.dart';
import '../home_screen.dart';
import '../../utils/app_theme.dart';
import '../vault/vault_screen.dart';
import '../../utils/app_localizations.dart';
import '../../utils/vault_exceptions.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final bool isCreating;

  const LoginScreen({super.key, this.isCreating = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final BiometricService _biometricService = BiometricService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _biometricAvailable = false;
  bool _biometricEnrolled = false;
  bool _enableBiometric = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      _biometricAvailable = await _biometricService.isBiometricAvailable();
      _biometricEnrolled = await _biometricService.isBiometricEnrolled();

      if (_biometricAvailable && _biometricEnrolled) {
        setState(() {
          _enableBiometric = true;
        });
      }
    } catch (e) {
      // Ignore biometric check errors
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check brute-force lockout
    if (!widget.isCreating && AuthGuardService.isLockedOut()) {
      final remaining = AuthGuardService.remainingLockout();
      setState(() {
        _errorMessage = '${AppLocalizations.of(context).tooManyAttempts} '
            '${remaining.inSeconds} ${AppLocalizations.of(context).seconds}';
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
        // Create new vault
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

        // Check password strength
        final strength = PasswordGeneratorService.calculateStrength(password);
        if (strength < 50) {
          setState(() {
            _errorMessage = AppLocalizations.of(context).passwordTooWeak;
            _isLoading = false;
          });
          return;
        }

        // Create vault
        final vault = VaultService.createNewVault(password);
        final Uint8List sessionKey = VaultService.deriveSessionKey(password, vault);
        await VaultService.saveVault(vault, sessionKey);

        // Initialize session with derived key (setSessionKey copies bytes)
        await SessionService.setSessionKey(sessionKey);
        EncryptionService.clearKey(sessionKey);
        SessionService.initialize(biometricEnabled: _enableBiometric);

        // Navigate to home
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        // Unlock existing vault
        try {
          final vault = await VaultService.loadVault(password);

          // Derive session key and upgrade to v4 if needed
          final Uint8List sessionKey = VaultService.deriveSessionKey(password, vault);
          await VaultService.saveVault(vault, sessionKey);

          // Success - reset brute-force counter
          AuthGuardService.recordSuccess();

          // Initialize session with derived key (setSessionKey copies bytes)
          await SessionService.setSessionKey(sessionKey);
          EncryptionService.clearKey(sessionKey);
          SessionService.initialize(biometricEnabled: _enableBiometric);

          // Navigate to vault
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const VaultScreen()),
            );
          }
        } catch (e) {
          // Vault created by a newer app version — don't count as failed attempt
          if (e is VaultVersionUnsupportedException) {
            setState(() {
              _errorMessage = AppLocalizations.of(context).vaultVersionUnsupported;
              _isLoading = false;
            });
            return;
          }

          // Record failed attempt for brute-force protection
          final lockedOut = AuthGuardService.recordFailedAttempt();

          setState(() {
            if (lockedOut) {
              final remaining = AuthGuardService.remainingLockout();
              _errorMessage = '${AppLocalizations.of(context).tooManyAttempts} '
                  '${remaining.inSeconds} ${AppLocalizations.of(context).seconds}';
            } else {
              final attemptsLeft = AuthGuardService.remainingAttempts();
              _errorMessage = '${AppLocalizations.of(context).invalidMasterPassword} '
                  '($attemptsLeft ${AppLocalizations.of(context).attemptsRemaining})';
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

  Future<void> _useBiometric() async {
    if (!_biometricAvailable || !_biometricEnrolled) return;

    setState(() => _isLoading = true);

    try {
      final authenticated = await _biometricService.authenticate(
        reason: AppLocalizations.of(context).biometricAuth,
      );

      if (authenticated) {
        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).biometricEnabled),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).biometricFailed;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Column(
                  children: [
                    Icon(
                      widget.isCreating ? Icons.enhanced_encryption : Icons.lock_open,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.isCreating
                          ? localizations.createMasterPassword
                          : localizations.unlockVault,
                      style: Theme.of(context).textTheme.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isCreating
                          ? localizations.createMasterPassword
                          : localizations.enterMasterPassword,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: localizations.masterPassword,
                    hintText: localizations.enterMasterPassword,
                    prefixIcon: const Icon(Icons.password),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return localizations.enterMasterPassword;
                    }
                    if (widget.isCreating && value.length < 8) {
                      return localizations.passwordTooShort;
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Confirm Password Field (only for creation)
                if (widget.isCreating)
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: localizations.confirmMasterPassword,
                      hintText: localizations.confirmMasterPassword,
                      prefixIcon: const Icon(Icons.password),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return localizations.confirmMasterPassword;
                      }
                      if (value != _passwordController.text) {
                        return localizations.passwordsDoNotMatch;
                      }
                      return null;
                    },
                  ),

                const SizedBox(height: 20),

                // Biometric Authentication Option
                if (_biometricAvailable && _biometricEnrolled)
                  Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _enableBiometric,
                            onChanged: (value) {
                              setState(() {
                                _enableBiometric = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              localizations.enableBiometric,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _useBiometric,
                        icon: const Icon(Icons.fingerprint),
                        label: Text(localizations.biometricAuth),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text(
                          widget.isCreating ? localizations.createVault : localizations.unlockVault,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
