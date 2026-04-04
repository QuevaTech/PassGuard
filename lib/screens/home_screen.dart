import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passguard_vault/services/session_service.dart';
import 'package:passguard_vault/services/biometric_service.dart';
import 'package:passguard_vault/services/clipboard_service.dart';
import 'package:passguard_vault/services/password_generator_service.dart';
import 'vault/vault_screen.dart';
import 'settings/settings_screen.dart';
import '../../utils/app_localizations.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    _isLocked = SessionService.isLocked();
    SessionService.addListener(_onSessionChange);
  }

  @override
  void dispose() {
    SessionService.removeListener(_onSessionChange);
    super.dispose();
  }

  void _onSessionChange() {
    if (!mounted) return;
    setState(() {
      _isLocked = SessionService.isLocked();
    });
  }

  Future<void> _reauthenticate() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).biometricFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _lockSession() async {
    SessionService.forceLock();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.appName),
        actions: [
          IconButton(
            onPressed: _isLocked ? null : _lockSession,
            icon: Icon(
              _isLocked ? Icons.lock : Icons.lock_open,
              color: _isLocked ? Colors.red : Colors.green,
            ),
            tooltip: _isLocked ? localizations.vaultLocked : localizations.logout,
          ),
        ],
      ),
      body: _isLocked ? _buildLockedView() : _buildUnlockedView(),
    );
  }

  Widget _buildLockedView() {
    final localizations = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              localizations.vaultLocked,
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _reauthenticate,
              icon: const Icon(Icons.fingerprint),
              label: Text(localizations.biometricAuth),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedView() {
    final localizations = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.welcome,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 32),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildQuickActionButton(
                icon: Icons.lock,
                label: localizations.passwords,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VaultScreen()),
                  );
                },
              ),
              _buildQuickActionButton(
                icon: Icons.password,
                label: localizations.generatePassword,
                onTap: () {
                  final generatedPassword = PasswordGeneratorService.generatePassword(
                    length: 16,
                    includeUppercase: true,
                    includeLowercase: true,
                    includeNumbers: true,
                    includeSymbols: true,
                  );
                  ClipboardService.copyPassword(generatedPassword);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.passwordCopied),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              _buildQuickActionButton(
                icon: Icons.settings,
                label: localizations.settings,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              _buildQuickActionButton(
                icon: Icons.fingerprint,
                label: localizations.biometricAuth,
                onTap: _reauthenticate,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
