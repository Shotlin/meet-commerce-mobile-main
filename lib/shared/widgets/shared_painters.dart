import 'package:flutter/material.dart';

class DashedLinePainter extends CustomPainter {
  const DashedLinePainter({
    required this.color,
    this.strokeWidth = 1.4,
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
    this.style = PaintingStyle.stroke,
  });

  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final PaintingStyle? style;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth;
    if (style != null) {
      paint.style = style!;
    }

    var startX = 0.0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(startX + dashWidth, y),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StoreToSearchWaveClipper extends CustomClipper<Path> {
  const StoreToSearchWaveClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height * 0.96)
      ..cubicTo(
        size.width * 0.2,
        size.height * 1.12,
        size.width * 0.45,
        size.height * 0.14,
        size.width * 0.74,
        size.height * 0.34,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.42,
        size.width,
        size.height * 0.12,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
