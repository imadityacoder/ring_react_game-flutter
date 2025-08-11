import 'dart:math';
import 'package:flutter/material.dart';

class RingPainter extends CustomPainter {
  final double ballAngle;
  final double safeStart;
  final double safeSweep;
  final bool isGameOver;
  final bool isDark;

  RingPainter({
    required this.ballAngle,
    required this.safeStart,
    required this.safeSweep,
    required this.isGameOver,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2 - 30;

    // Ring with static color (add opacity for light theme)
    final ringPaint = Paint()
      ..color = isDark
          ? Colors.blueGrey.shade800
          : Colors.blue.shade400.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, ringPaint);

    // Safe zone gradient (fixed, not rotating with safeStart)
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    final fixedSafeGradient = SweepGradient(
      startAngle: 0,
      endAngle: safeSweep,
      colors: isGameOver
          ? [Colors.redAccent, Colors.deepOrange]
          : [Colors.greenAccent.shade400, Colors.green.shade700],
    );

    final safePaint = Paint()
      ..shader = fixedSafeGradient.createShader(ringRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 40
      ..strokeCap = StrokeCap.butt;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(safeStart);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      safeSweep,
      false,
      safePaint,
    );
    canvas.restore();

    // Ball
    final ballPaint = Paint()..color = isDark ? Colors.white : Colors.black;
    final bx = center.dx + radius * cos(ballAngle);
    final by = center.dy + radius * sin(ballAngle);
    // shadow
    canvas.drawCircle(
      Offset(bx + 2, by + 2),
      10.6,
      Paint()..color = Colors.black26,
    );
    canvas.drawCircle(Offset(bx, by), 16, ballPaint);
  }

  @override
  bool shouldRepaint(covariant RingPainter old) {
    return ballAngle != old.ballAngle ||
        safeStart != old.safeStart ||
        safeSweep != old.safeSweep ||
        isGameOver != old.isGameOver ||
        isDark != old.isDark;
  }
}
