import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault/services/biometric_service.dart';
import 'package:passguard_vault/services/vault_service.dart';
import 'package:passguard_vault/services/session_service.dart';
import 'package:passguard_vault/services/auth_guard_service.dart';
import 'package:passguard_vault/services/encryption_service.dart';
import '../vault/vault_screen.dart';
import '../../utils/app_localizations.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isLoading = false;
  bool _showPasswordInput = false;
  bool _obscurePassword = true;
  final _passwordController = TextEditingController();
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricAndAuthenticate();
  }

  Future<void> _checkBiometricAndAuthenticate() async {
    try {
      final available = await _biometricService.isBiometricAvailable();
      final enrolled = await _biometricService.isBiometricEnrolled();

      if (available && enrolled) {
        await _authenticateWithBiometric();
      } else {
        setState(() {
          _showPasswordInput = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).biometricFailed;
        _showPasswordInput = true;
      });
    }
  }

  Future<void> _authenticateWithBiometric() async {
    setState(() => _isLoading = true);

    try {
      final authenticated = await _biometricService.authenticate(
        reason: AppLocalizations.of(context).biometricAuth,
        cancelButtonText: AppLocalizations.of(context).cancel,
      );

      if (authenticated) {
        // Biometric successful — session key stays in memory on lock, just unlock
        if (SessionService.getSessionKey() != null) {
          AuthGuardService.recordSuccess();
          SessionService.unlockSession();

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const VaultScreen()),
            );
          }
          return;
        }

        // Fresh app start — key not in memory yet, need master password once
        if (mounted) {
          setState(() {
            _isLoading = false;
            _showPasswordInput = true;
            _errorMessage = AppLocalizations.of(context).enterMasterPassword;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _showPasswordInput = true;
          _errorMessage = AppLocalizations.of(context).biometricNotRecognized;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _showPasswordInput = true;
        _errorMessage = AppLocalizations.of(context).biometricFailed;
      });
    }
  }

  Future<void> _authenticateWithPassword() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = AppLocalizations.of(context).enterMasterPassword;
      });
      return;
    }

    // Check brute-force lockout
    if (AuthGuardService.isLockedOut()) {
      final remaining = AuthGuardService.remainingLockout();
      setState(() {
        _errorMessage = '${AppLocalizations.of(context).tooManyAttempts} '
            '${remaining.inSeconds} ${AppLocalizations.of(context).seconds}';
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Load vault with password, derive session key
      var vault = await VaultService.loadVault(_passwordController.text);
      var sessionKey = await VaultService.deriveSessionKey(_passwordController.text, vault);

      // Upgrade KDF params if the vault was created with older defaults.
      // Failure here is non-fatal — fall back to original vault/key.
      try {
        final migration = await VaultService.migrateKdfParamsIfNeeded(
          vault, _passwordController.text, sessionKey,
        );
        if (migration != null) {
          EncryptionService.clearKey(sessionKey);
          vault = migration.$1;
          sessionKey = migration.$2;
        }
      } catch (e) {
        debugPrint('VerificationScreen: KDF migration failed (non-fatal): $e');
      }

      await VaultService.saveVault(vault, sessionKey);

      // Password authentication successful
      AuthGuardService.recordSuccess();
      await SessionService.setSessionKey(sessionKey);
      SessionService.unlockSession();

      // Navigate to vault
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VaultScreen()),
        );
      }
    } catch (e) {
      // Vault created by a newer app version — don't count as failed attempt
      if (e.toString().contains('vault_version_unsupported')) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context).vaultVersionUnsupported;
        });
        return;
      }

      // Record failed attempt
      final lockedOut = AuthGuardService.recordFailedAttempt();

      setState(() {
        _isLoading = false;
        if (lockedOut) {
          final remaining = AuthGuardService.remainingLockout();
          _errorMessage = '${AppLocalizations.of(context).tooManyAttempts} '
              '${remaining.inSeconds} ${AppLocalizations.of(context).seconds}';
        } else {
          final attemptsLeft = AuthGuardService.remainingAttempts();
          _errorMessage = '${AppLocalizations.of(context).invalidMasterPassword} '
              '($attemptsLeft ${AppLocalizations.of(context).attemptsRemaining})';
        }
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Column(
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.biometricAuth,
                    style: Theme.of(context).textTheme.displayLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.useBiometric,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Biometric Authentication
              if (!_showPasswordInput && !_isLoading)
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _authenticateWithBiometric,
                      icon: const Icon(Icons.fingerprint),
                      label: Text(localizations.biometricAuth),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showPasswordInput = true;
                        });
                      },
                      child: Text(localizations.usePassword),
                    ),
                  ],
                ),

              // Password Input
              if (_showPasswordInput)
                Column(
                  children: [
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
                        return null;
                      },
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

              // Loading Indicator
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),

              // Submit Button (for password)
              if (_showPasswordInput)
                ElevatedButton(
                  onPressed: _isLoading ? null : _authenticateWithPassword,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text(localizations.unlockVault),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
