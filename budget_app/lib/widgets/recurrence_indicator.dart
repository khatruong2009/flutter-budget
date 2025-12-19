import 'package:flutter/material.dart';
import '../design_system.dart';

/// A visual indicator for recurring transactions.
/// Displays two arrows forming an elongated oval shape.
class RecurrenceIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const RecurrenceIndicator({
    super.key,
    this.size = 16.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppDesign.getTextSecondary(context);

    return CustomPaint(
      size: Size(size, size * 0.6), // Elongated oval aspect ratio
      painter: _RecurrenceIconPainter(iconColor),
    );
  }
}

/// Custom painter that draws an elongated oval with two arrows
/// to represent recurring transactions.
class _RecurrenceIconPainter extends CustomPainter {
  final Color color;

  _RecurrenceIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final width = size.width;
    final height = size.height;
    final centerY = height / 2;

    // Define the oval boundaries
    final leftX = width * 0.1;
    final rightX = width * 0.9;
    final arrowSize = width * 0.18;

    // Draw top arc (clockwise, right-pointing)
    final topPath = Path();
    topPath.moveTo(leftX + arrowSize * 0.5, centerY);
    topPath.cubicTo(
      leftX + arrowSize * 0.5, height * 0.05, // Control point 1
      rightX - arrowSize * 0.5, height * 0.05, // Control point 2
      rightX - arrowSize * 0.5, centerY,       // End point (before arrow)
    );
    canvas.drawPath(topPath, paint);

    // Draw right arrow head (pointing clockwise/right)
    final rightArrow = Path();
    rightArrow.moveTo(rightX - arrowSize, centerY - arrowSize * 0.5);
    rightArrow.lineTo(rightX, centerY);
    rightArrow.lineTo(rightX - arrowSize, centerY + arrowSize * 0.5);
    canvas.drawPath(rightArrow, paint);

    // Draw bottom arc (clockwise, left-pointing)
    final bottomPath = Path();
    bottomPath.moveTo(rightX - arrowSize * 0.5, centerY);
    bottomPath.cubicTo(
      rightX - arrowSize * 0.5, height * 0.95, // Control point 1
      leftX + arrowSize * 0.5, height * 0.95,  // Control point 2
      leftX + arrowSize * 0.5, centerY,        // End point (before arrow)
    );
    canvas.drawPath(bottomPath, paint);

    // Draw left arrow head (pointing clockwise/left)
    final leftArrow = Path();
    leftArrow.moveTo(leftX + arrowSize, centerY - arrowSize * 0.5);
    leftArrow.lineTo(leftX, centerY);
    leftArrow.lineTo(leftX + arrowSize, centerY + arrowSize * 0.5);
    canvas.drawPath(leftArrow, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is _RecurrenceIconPainter) {
      return oldDelegate.color != color;
    }
    return false;
  }
}
