import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Conic progress ring with a dark inner disc and an outer glow, animating
/// from 0 to [value] on entry. Matches the CSS
/// `conic-gradient(color 0 X%, #1B1B2C X% 100%)` rings on Goals.
class ProgressRing extends StatelessWidget {
  /// Progress fraction 0..1 (clamped).
  final double value;

  /// Outer diameter (72 summary ring, 84 goal rings).
  final double size;

  /// Ring thickness (design: 8 at 72px, 9 at 84px).
  final double thickness;

  final Color color;

  /// Inner disc color; defaults to the card surface.
  final Color? innerColor;

  /// Center content (percent label or check icon).
  final Widget? child;

  /// Glow strength (Goals rings use 28px blur at 30–45%).
  final double glowAlpha;

  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    required this.color,
    this.thickness = 9,
    this.innerColor,
    this.child,
    this.glowAlpha = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final inner = innerColor ?? AppColors.getCard(isDark);
    final track = AppColors.getTrack(isDark);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? clamped : 0, end: clamped),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: t > 0
                ? AppColors.glow(color,
                    blurRadius: 28, alpha: glowAlpha * t, isDark: isDark)
                : null,
          ),
          child: CustomPaint(
            painter: _RingPainter(
              progress: t,
              color: color,
              trackColor: track,
              thickness: thickness,
            ),
            child: Center(
              child: Container(
                width: size - thickness * 2,
                height: size - thickness * 2,
                decoration: BoxDecoration(
                  color: inner,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double thickness;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - thickness / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = color;
      // Hard-stop conic look: butt caps, starting at 12 o'clock.
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.progress != progress ||
        old.color != color ||
        old.trackColor != trackColor ||
        old.thickness != thickness;
  }
}
