import 'package:flutter/material.dart';
import '../theme/app_theme_extension.dart';

/// Modern pill badge for an entry category.
/// Reads its colour from [AppThemeExtension.categoryColors]; falls back to
/// the colorScheme primary when the theme extension is absent.
class CategoryBadge extends StatelessWidget {
  final String category;
  /// Compact mode: smaller font + tighter padding (for list rows).
  final bool compact;

  const CategoryBadge({
    super.key,
    required this.category,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    final key = category.toLowerCase();
    final color = ext?.categoryColors[key] ??
        ext?.primaryAccent ??
        Theme.of(context).colorScheme.primary;

    final fontSize = compact ? 10.0 : 12.0;
    final hPad = compact ? 7.0 : 10.0;
    final vPad = compact ? 3.0 : 5.0;
    final dotSize = compact ? 5.0 : 6.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: compact ? 4 : 5),
          Text(
            category.isEmpty ? 'Other' : category,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
