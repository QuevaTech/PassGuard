import 'package:flutter/material.dart';
import '../theme/app_theme_extension.dart';
import '../theme/cipher_theme.dart';

class AppBackground extends StatelessWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>();

    Gradient gradient;
    if (ext == null) {
      gradient = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1b1f3b), Color(0xFF11142b)],
      );
    } else if (ext.isRadialGradient) {
      gradient = RadialGradient(
        center: ext.gradientCenter,
        radius: 1.2,
        colors: ext.backgroundGradientColors,
        stops: ext.backgroundGradientStops,
      );
    } else {
      gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: ext.backgroundGradientColors,
        stops: ext.backgroundGradientStops,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(gradient: gradient),
          ),
        ),
        if (ext?.hasAuroraRibbons == true)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AuroraPainter(CipherTheme.auroraRibbons),
              ),
            ),
          ),
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final List<AuroraRibbon> ribbons;
  _AuroraPainter(this.ribbons);

  @override
  void paint(Canvas canvas, Size size) {
    for (final ribbon in ribbons) {
      final paint = Paint()
        ..color = ribbon.color
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, ribbon.blurRadius);

      final w = size.width * ribbon.widthFraction;
      final h = 130.0;
      final left = (size.width - w) / 2;
      final top = size.height * ribbon.topFraction;

      canvas.drawOval(
        Rect.fromLTWH(left, top, w, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => false;
}
