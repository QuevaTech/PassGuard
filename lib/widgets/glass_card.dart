import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme_extension.dart';

/// A frosted-glass card that adapts to the current [AppThemeExtension].
///
/// - Vault: 18px blur, gold border
/// - Stratum: no blur (flat surface)
/// - Cipher: 20px blur, neon border
///
/// Constructor params act as overrides when explicitly provided.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  /// Explicit border-radius override. Falls back to [AppThemeExtension.cardRadius].
  final double? borderRadius;

  /// Explicit blur override. Falls back to [AppThemeExtension.cardBlur].
  final double? blur;

  /// Explicit background colour override.
  final Color? color;

  /// Optional left accent bar.
  final Color? leftAccentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius,
    this.blur,
    this.color,
    this.leftAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBlur = blur ?? ext?.cardBlur ?? 10.0;
    final effectiveRadius = borderRadius ?? ext?.cardRadius ?? 28.0;

    final fillColor = color ??
        ext?.cardBackground ??
        (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.60));

    final borderColor = ext?.cardBorderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.80));

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: ext?.isFlat == true ? 0.16 : 0.22)
        : (ext?.primaryAccent ?? Theme.of(context).colorScheme.primary)
            .withValues(alpha: 0.10);

    // BoxDecoration cannot paint a rounded [Border] whose sides have
    // different colours. Keep the outer border uniform and render the colour
    // tag as a clipped inner strip instead, so tagged entries work on every
    // platform without a paint-time assertion.
    final border = Border.all(color: borderColor, width: 1);

    final contentChild = leftAccentColor == null
        ? child
        : Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: leftAccentColor),
              ),
            ],
          );

    Widget content = Container(
      padding: leftAccentColor == null ? padding : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(effectiveRadius),
        color: fillColor,
        border: border,
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: contentChild,
    );

    if (effectiveBlur > 0) {
      content = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
        child: content,
      );
    }

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius),
        child: content,
      ),
    );
  }
}
