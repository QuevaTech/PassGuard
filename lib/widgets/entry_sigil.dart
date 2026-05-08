import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme_extension.dart';

/// Renders a deterministic geometric "sigil" icon when the Cipher theme is
/// active, based on the SHA-like hash of [seed].  Falls back to a standard
/// [fallbackIcon] for all other themes.
class EntrySigil extends StatelessWidget {
  final String seed;
  final double size;
  final IconData fallbackIcon;

  const EntrySigil({
    super.key,
    required this.seed,
    this.size = 40,
    this.fallbackIcon = Icons.lock_outline,
  });

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();
    if (ext?.isCipher != true) {
      return Icon(fallbackIcon,
          size: size * 0.6,
          color: ext?.primaryAccent ??
              Theme.of(context).colorScheme.primary);
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SigilPainter(
          seed: seed,
          primary: ext!.primaryAccent,
          secondary: ext.secondaryAccent,
        ),
      ),
    );
  }
}

class _SigilPainter extends CustomPainter {
  final String seed;
  final Color primary;
  final Color secondary;

  _SigilPainter({
    required this.seed,
    required this.primary,
    required this.secondary,
  });

  // Deterministic "hash" — folds seed chars into a repeatable integer.
  int _hash() {
    var h = 0x811c9dc5;
    for (final c in seed.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final h = _hash();
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    // Derived values from hash
    final numLines = 3 + (((h >> 4) & 0xFF) % 3);
    final numCircles = 1 + (((h >> 8) & 0xFF) % 2);
    final primaryAngle = ((h >> 12) & 0xFF) / 255.0 * math.pi;
    final hasRing = ((h >> 20) & 1) == 1;

    // Optional outer ring
    if (hasRing) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * 0.95,
        Paint()
          ..color = primary.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Radial lines
    final linePaint = Paint()
      ..color = primary.withValues(alpha: 0.65)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < numLines; i++) {
      final angle = primaryAngle + (i * math.pi / numLines);
      final dx = math.cos(angle) * r;
      final dy = math.sin(angle) * r;
      canvas.drawLine(
        Offset(cx - dx, cy - dy),
        Offset(cx + dx, cy + dy),
        linePaint,
      );
    }

    // Inner circles
    for (var j = 0; j < numCircles; j++) {
      final radiusFraction =
          0.18 + j * 0.14 + (((h >> (16 + j * 4)) & 0xFF) / 255.0) * 0.10;
      canvas.drawCircle(
        Offset(cx, cy),
        r * radiusFraction,
        Paint()
          ..color = secondary.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
    }

    // Core dot
    canvas.drawCircle(
      Offset(cx, cy),
      size.width * 0.07,
      Paint()..color = primary.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.seed != seed ||
      old.primary != primary ||
      old.secondary != secondary;
}
