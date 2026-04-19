import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _disclaimerAccepted = false;

  List<_OnboardingPageData> _buildPages(AppLocalizations l) => [
    _OnboardingPageData(
      icon: Icons.lock_outline,
      color: const Color(0xFF1565C0),
      title: l.onboardingTitle1,
      desc: l.onboardingDesc1,
      isWarning: false,
      isDisclaimer: false,
    ),
    _OnboardingPageData(
      icon: Icons.warning_amber_rounded,
      color: const Color(0xFFE65100),
      title: l.onboardingTitle2,
      desc: l.onboardingDesc2,
      isWarning: true,
      isDisclaimer: false,
    ),
    _OnboardingPageData(
      icon: Icons.fingerprint,
      color: const Color(0xFF2E7D32),
      title: l.onboardingTitle3,
      desc: l.onboardingDesc3,
      isWarning: false,
      isDisclaimer: false,
    ),
    _OnboardingPageData(
      icon: Icons.sync_alt,
      color: const Color(0xFF6A1B9A),
      title: l.onboardingTitle4,
      desc: l.onboardingDesc4,
      isWarning: false,
      isDisclaimer: false,
    ),
    _OnboardingPageData(
      icon: Icons.shield_outlined,
      color: const Color(0xFF00695C),
      title: l.onboardingTitle5,
      desc: l.onboardingDesc5,
      isWarning: false,
      isDisclaimer: false,
    ),
    _OnboardingPageData(
      icon: Icons.gavel_rounded,
      color: const Color(0xFFB71C1C),
      title: l.disclaimerTitle,
      desc: l.disclaimerText,
      isWarning: false,
      isDisclaimer: true,
    ),
  ];

  Future<void> _finish() async {
    if (!_disclaimerAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).disclaimerMustAccept),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
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
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pages = _buildPages(l);
    final isLast = _currentPage == pages.length - 1;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Skip — jumps to disclaimer page, never bypasses it
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: isLast
                      ? null
                      : () {
                          _controller.animateToPage(
                            pages.length - 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                  child: Text(
                    l.skip,
                    style: TextStyle(
                      color: isLast
                          ? theme.colorScheme.primary.withOpacity(0.3)
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = pages[index];
                  if (page.isDisclaimer) {
                    return _DisclaimerPageWidget(
                      data: page,
                      accepted: _disclaimerAccepted,
                      acceptLabel: l.disclaimerAccept,
                      onAcceptChanged: (v) =>
                          setState(() => _disclaimerAccepted = v ?? false),
                    );
                  }
                  return _OnboardingPageWidget(data: page);
                },
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(pages.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),

            const SizedBox(height: 32),

            // Next / Get Started
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (isLast && !_disclaimerAccepted)
                      ? null
                      : () {
                          if (isLast) {
                            _finish();
                          } else {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLast
                        ? (_disclaimerAccepted
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withOpacity(0.12))
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isLast ? l.getStarted : l.next,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

class _OnboardingPageData {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final bool isWarning;
  final bool isDisclaimer;

  const _OnboardingPageData({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    required this.isWarning,
    this.isDisclaimer = false,
  });
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPageData data;

  const _OnboardingPageWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: data.isWarning
                  ? Border.all(color: data.color.withOpacity(0.4), width: 2)
                  : null,
            ),
            child: Icon(
              data.icon,
              size: 60,
              color: data.color,
            ),
          ),

          const SizedBox(height: 48),

          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: data.isWarning ? data.color : null,
            ),
          ),

          const SizedBox(height: 20),

          // Warning sayfası için özel kutu
          if (data.isWarning)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: data.color.withOpacity(isDark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: data.color.withOpacity(0.3)),
              ),
              child: Text(
                data.desc,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark
                      ? data.color.withOpacity(0.9)
                      : data.color.withOpacity(0.85),
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Text(
              data.desc,
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

class _DisclaimerPageWidget extends StatelessWidget {
  final _OnboardingPageData data;
  final bool accepted;
  final String acceptLabel;
  final ValueChanged<bool?> onAcceptChanged;

  const _DisclaimerPageWidget({
    required this.data,
    required this.accepted,
    required this.acceptLabel,
    required this.onAcceptChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: data.color.withOpacity(0.4), width: 2),
            ),
            child: Icon(data.icon, size: 40, color: data.color),
          ),
          const SizedBox(height: 20),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: data.color,
            ),
          ),
          const SizedBox(height: 16),
          // Scrollable disclaimer text
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: data.color.withOpacity(isDark ? 0.08 : 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: data.color.withOpacity(0.25)),
              ),
              child: SingleChildScrollView(
                child: Text(
                  data.desc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? theme.colorScheme.onSurface.withOpacity(0.85)
                        : theme.colorScheme.onSurface.withOpacity(0.8),
                    height: 1.7,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Checkbox
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onAcceptChanged(!accepted),
            child: Row(
              children: [
                Checkbox(
                  value: accepted,
                  onChanged: onAcceptChanged,
                  activeColor: data.color,
                ),
                Expanded(
                  child: Text(
                    acceptLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: accepted
                          ? data.color
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
