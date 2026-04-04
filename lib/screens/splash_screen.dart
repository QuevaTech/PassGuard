import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:passguard_vault/services/vault_service.dart';
import 'package:passguard_vault/services/biometric_service.dart';
import 'package:passguard_vault/services/session_service.dart';
import 'auth/login_screen.dart';
import 'auth/verification_screen.dart';
import 'auth/pin_screen.dart';
import 'onboarding_screen.dart';
import '../utils/app_localizations.dart';
import '../services/pin_service.dart';
import '../services/auth_guard_service.dart';
import '../services/storage_availability_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  final BiometricService _biometricService = BiometricService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Short delay for splash branding
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    // Check whether secure storage (keychain/libsecret/DPAPI) is available.
    await StorageAvailabilityService.initialize();

    // Load persisted brute-force lockout state (only if storage is available).
    await AuthGuardService.initialize();

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;

      if (!mounted) return;

      if (!onboardingDone) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        return;
      }

      final vaultExists = await VaultService.vaultExists();

      if (!mounted) return;

      if (vaultExists) {
        // PIN check: if PIN enabled, always route to PIN screen
        final pinEnabled = await PinService.isPinEnabled();
        if (!mounted) return;

        if (pinEnabled) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const PinScreen(mode: PinScreenMode.unlock)),
          );
          return;
        }

        final biometricAvailable = await _biometricService.isBiometricAvailable();
        final biometricEnrolled = await _biometricService.isBiometricEnrolled();

        if (!mounted) return;

        final biometricPref = prefs.getBool('biometric_enabled') ?? true;
        final biometricEnabled = biometricAvailable && biometricEnrolled && biometricPref;

        if (!mounted) return;

        if (biometricEnabled) {
          SessionService.initialize(biometricEnabled: true);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VerificationScreen()),
          );
        } else {
          SessionService.initialize(biometricEnabled: false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen(isCreating: true)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(isCreating: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield,
                size: 120,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                localizations.appName,
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
