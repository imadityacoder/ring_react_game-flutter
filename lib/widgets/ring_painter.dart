import 'dart:math';
import 'package:flutter/material.dart';

class BallPainter extends CustomPainter {
  final double ballAngle;
  final bool isDark;
  final double strokeWidth; // to calculate radius position

  BallPainter({
    required this.ballAngle,
    required this.isDark,
    this.strokeWidth = 40,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2 - strokeWidth / 2 - 10;

    final ballPaint = Paint()..color = isDark ? Colors.white : Colors.black;
    final shadowPaint = Paint()..color = Colors.black26;

    final bx = center.dx + radius * cos(ballAngle);
    final by = center.dy + radius * sin(ballAngle);

    // single small shadow + ball draw (cheap)
    canvas.drawCircle(Offset(bx + 2, by + 2), 10.5, shadowPaint);
    canvas.drawCircle(Offset(bx, by), 16, ballPaint);
  }

  @override
  bool shouldRepaint(covariant BallPainter old) {
    return ballAngle != old.ballAngle || isDark != old.isDark || strokeWidth != old.strokeWidth;
  }
}
