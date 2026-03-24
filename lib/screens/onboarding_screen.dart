import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.lock_outline,
      color: Color(0xFF1565C0),
      titleKey: 'onboarding_title_1',
      descKey: 'onboarding_desc_1',
    ),
    _OnboardingPage(
      icon: Icons.fingerprint,
      color: Color(0xFF2E7D32),
      titleKey: 'onboarding_title_2',
      descKey: 'onboarding_desc_2',
    ),
    _OnboardingPage(
      icon: Icons.sync_alt,
      color: Color(0xFF6A1B9A),
      titleKey: 'onboarding_title_3',
      descKey: 'onboarding_desc_3',
    ),
    _OnboardingPage(
      icon: Icons.shield_outlined,
      color: Color(0xFFE65100),
      titleKey: 'onboarding_title_4',
      descKey: 'onboarding_desc_4',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(isCreating: true)),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _OnboardingPageWidget(page: page);
                },
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Next / Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (isLast) {
                      _finish();
                    } else {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(
                    isLast ? 'Get Started' : 'Next',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Color color;
  final String titleKey;
  final String descKey;

  const _OnboardingPage({
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.descKey,
  });
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageWidget({required this.page});

  static const _titles = {
    'onboarding_title_1': 'Your Passwords, Safe & Encrypted',
    'onboarding_title_2': 'Biometric Authentication',
    'onboarding_title_3': 'Import & Backup',
    'onboarding_title_4': 'Zero Knowledge Security',
  };

  static const _descs = {
    'onboarding_desc_1': 'All your passwords are protected with AES-256-GCM encryption and Argon2id key derivation. Only you can access your data.',
    'onboarding_desc_2': 'Use Face ID, fingerprint or PIN to unlock your vault quickly and securely without typing your master password every time.',
    'onboarding_desc_3': 'Import from Chrome, Bitwarden or 1Password. Back up your encrypted vault and restore it on any device.',
    'onboarding_desc_4': 'Your data never leaves your device. No cloud sync, no servers, no accounts — complete privacy by design.',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _titles[page.titleKey] ?? '';
    final desc = _descs[page.descKey] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: page.color,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
