import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault_v0/services/pin_service.dart';
import 'package:passguard_vault_v0/services/session_service.dart';
import 'package:passguard_vault_v0/services/auth_guard_service.dart';
import '../vault/vault_screen.dart';
import '../auth/login_screen.dart';

enum PinScreenMode { setup, unlock }

class PinScreen extends ConsumerStatefulWidget {
  final PinScreenMode mode;

  const PinScreen({super.key, required this.mode});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  static const int _pinLength = 4;

  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  String _errorMessage = '';

  String get _currentPin => _isConfirming ? _confirmPin : _pin;

  void _onDigit(String digit) {
    if (_isLoading || _currentPin.length >= _pinLength) return;
    setState(() {
      _errorMessage = '';
      if (_isConfirming) {
        _confirmPin += digit;
      } else {
        _pin += digit;
      }
    });
    if (_currentPin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 80), _onPinComplete);
    }
  }

  void _onBackspace() {
    setState(() {
      if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _onPinComplete() async {
    if (_isLoading) return;

    if (widget.mode == PinScreenMode.setup) {
      if (!_isConfirming) {
        setState(() => _isConfirming = true);
      } else {
        if (_pin == _confirmPin) {
          setState(() => _isLoading = true);
          try {
            await PinService.setPin(_pin);
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
          if (mounted) Navigator.pop(context, true);
        } else {
          setState(() {
            _errorMessage = 'PINs do not match. Try again.';
            _pin = '';
            _confirmPin = '';
            _isConfirming = false;
          });
        }
      }
      return;
    }

    // Unlock mode
    if (AuthGuardService.isLockedOut()) {
      final remaining = AuthGuardService.remainingLockout();
      setState(() {
        _errorMessage =
            'Too many attempts. Try again in ${remaining.inSeconds}s.';
        _pin = '';
      });
      return;
    }

    setState(() => _isLoading = true);
    final valid = await PinService.verifyPin(_pin);
    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;

    if (valid) {
      AuthGuardService.recordSuccess();

      // Try in-memory key first, then Keychain
      var key = SessionService.getSessionKey();
      key ??= await SessionService.loadSessionKey();

      if (!mounted) return;

      if (key != null) {
        if (SessionService.isLocked()) {
          SessionService.unlockSession();
        } else {
          SessionService.initialize(biometricEnabled: false);
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VaultScreen()),
        );
      } else {
        // No session key available — need master password
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      final lockedOut = AuthGuardService.recordFailedAttempt();
      setState(() {
        _pin = '';
        if (lockedOut) {
          final remaining = AuthGuardService.remainingLockout();
          _errorMessage =
              'Too many attempts. Try again in ${remaining.inSeconds}s.';
        } else {
          final left = AuthGuardService.remainingAttempts();
          _errorMessage = 'Incorrect PIN. $left attempts left.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSetup = widget.mode == PinScreenMode.setup;

    String title;
    if (isSetup) {
      title = _isConfirming ? 'Confirm PIN' : 'Create PIN';
    } else {
      title = 'Enter PIN';
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: isSetup
          ? AppBar(title: const Text('Set PIN Lock'))
          : null,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSetup ? Icons.pin_outlined : Icons.lock_outline,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 28),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _currentPin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              )
            else
              const SizedBox(height: 24),

            const SizedBox(height: 24),

            // Keypad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3'], theme),
                  _buildRow(['4', '5', '6'], theme),
                  _buildRow(['7', '8', '9'], theme),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 72, height: 60),
                      _buildDigitKey('0', theme),
                      SizedBox(
                        width: 72,
                        height: 60,
                        child: IconButton(
                          onPressed: _onBackspace,
                          icon: const Icon(Icons.backspace_outlined),
                          iconSize: 26,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (!isSetup) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Use master password instead'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitKey(d, theme)).toList(),
    );
  }

  Widget _buildDigitKey(String digit, ThemeData theme) {
    return SizedBox(
      width: 72,
      height: 60,
      child: TextButton(
        onPressed: () => _onDigit(digit),
        style: TextButton.styleFrom(shape: const CircleBorder()),
        child: Text(
          digit,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
