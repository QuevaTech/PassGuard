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
    final effectiveRadius = borderRadius ?? ext?.cardRadius ?? 12.0;

    final fillColor = color ??
        ext?.cardBackground ??
        (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.60));

    final borderColor = ext?.cardBorderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.80));

    final border = leftAccentColor != null
        ? Border(
            left: BorderSide(color: leftAccentColor!, width: 4),
            top: BorderSide(color: borderColor, width: 1),
            right: BorderSide(color: borderColor, width: 1),
            bottom: BorderSide(color: borderColor, width: 1),
          )
        : Border.all(color: borderColor, width: 1);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: leftAccentColor == null
            ? BorderRadius.circular(effectiveRadius)
            : null,
        color: fillColor,
        border: border,
      ),
      child: child,
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
