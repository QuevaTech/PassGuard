import 'package:flutter/material.dart';
import '../theme/app_theme_extension.dart';

/// A floating action button that adapts to the current [AppThemeExtension].
///
/// - Vault: gold→ember gradient with warm glow
/// - Stratum: accent-bordered flat button (no gradient)
/// - Cipher: cyan→magenta gradient with neon glow
class ThemedFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;

  const ThemedFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final isFlat = ext?.isFlat == true;
    final isCipher = ext?.isCipher == true;

    final gradient = ext?.ctaGradient;
    final primary = ext?.primaryAccent ?? Theme.of(context).colorScheme.primary;
    final secondary = ext?.secondaryAccent ?? primary;
    final glowColor =
        (ext?.ctaGlowColors.firstOrNull) ?? primary.withValues(alpha: 0.4);

    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isFlat ? null : gradient,
            color: isFlat ? primary : null,
            border: isFlat ? Border.all(color: primary, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: isCipher ? 20 : 14,
                spreadRadius: isCipher ? 2 : 0,
                offset: const Offset(0, 4),
              ),
              if (isCipher)
                BoxShadow(
                  color: secondary.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: Icon(
            icon,
            size: 27,
            color: isFlat
                ? (primary.computeLuminance() > 0.35
                    ? const Color(0xFF1b1f3b)
                    : Colors.white)
                : (primary.computeLuminance() > 0.35
                    ? const Color(0xFF1b1f3b)
                    : Colors.white),
          ),
        ),
      ),
    );
  }
}
