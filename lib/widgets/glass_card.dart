import 'dart:ui';
import 'package:flutter/material.dart';

/// A frosted-glass card using BackdropFilter.
/// Must be placed over a non-opaque background (gradient) to produce the blur effect.
/// Nesting order is critical: ClipRRect > BackdropFilter > Container(decoration) > child.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double blur;
  final Color? color;
  /// Optional left accent bar rendered as a thick left border.
  final Color? leftAccentColor;

  const GlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 12,
    this.blur = 10,
    this.color,
    this.leftAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = color ??
        (isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.60));
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.80);

    final border = leftAccentColor != null
        ? Border(
            left: BorderSide(color: leftAccentColor!, width: 4),
            top: BorderSide(color: glassBorder, width: 1),
            right: BorderSide(color: glassBorder, width: 1),
            bottom: BorderSide(color: glassBorder, width: 1),
          )
        : Border.all(color: glassBorder, width: 1);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              // omit borderRadius when border is non-uniform; ClipRRect handles rounding
              borderRadius: leftAccentColor == null ? BorderRadius.circular(borderRadius) : null,
              color: fillColor,
              border: border,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
