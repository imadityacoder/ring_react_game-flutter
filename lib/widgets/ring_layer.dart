import 'dart:math';
import 'package:flutter/material.dart';

class RingLayer extends StatefulWidget {
  final double safeStart; // target safe start (radians)
  final double safeSweep;
  final bool isGameOver;
  final bool isDark;
  final double strokeWidth;
  final double size; // size of the square canvas

  const RingLayer({
    super.key,
    required this.safeStart,
    required this.safeSweep,
    required this.isGameOver,
    required this.isDark,
    required this.size,
    this.strokeWidth = 40,
  });

  @override
  @override
  State<RingLayer> createState() => _RingLayerState();
}

class _RingLayerState extends State<RingLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;
  double _current = 0.0;

  @override
  void initState() {
    super.initState();
    _current = widget.safeStart;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _anim = AlwaysStoppedAnimation(_current);
  }

  @override
  void didUpdateWidget(covariant RingLayer old) {
    super.didUpdateWidget(old);
    if ((widget.safeStart - old.safeStart).abs() > 1e-6) {
      // animate from old to new, picking the shortest rotation direction
      final from = _current;
      final to = widget.safeStart;

      // normalize to -pi..pi for shortest path smoothing
      double diff = (to - from) % (2 * pi);
      if (diff > pi) diff -= 2 * pi;
      final target = from + diff;

      _anim =
          Tween<double>(begin: from, end: target).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          )..addListener(() {
            // Only update this small subtree
            setState(() {
              _current = _anim.value;
            });
          });

      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        painter: _RingPainter(
          safeStartAnim: _current,
          safeSweep: widget.safeSweep,
          isGameOver: widget.isGameOver,
          isDark: widget.isDark,
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double safeStartAnim;
  final double safeSweep;
  final bool isGameOver;
  final bool isDark;
  final double strokeWidth;

  _RingPainter({
    required this.safeStartAnim,
    required this.safeSweep,
    required this.isGameOver,
    required this.isDark,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2 - strokeWidth / 2 - 10;

    // Ring background
    final ringPaint = Paint()
      ..color = isDark
          ? Colors.blueGrey.shade800
          : Colors.blue.shade400.withAlpha((0.55 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, ringPaint);

    // Safe zone gradient (rotating using safeStartAnim)
    final ringRect = Rect.fromCircle(center: center, radius: radius);
    final safeGradient = SweepGradient(
      startAngle: 0,
      endAngle: safeSweep,
      colors: isGameOver
          ? [Colors.redAccent, Colors.deepOrange]
          : [Colors.greenAccent.shade400, Colors.green.shade700],
    );

    final safePaint = Paint()
      ..shader = safeGradient.createShader(ringRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(safeStartAnim);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      safeSweep,
      false,
      safePaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return safeStartAnim != old.safeStartAnim ||
        safeSweep != old.safeSweep ||
        isGameOver != old.isGameOver ||
        isDark != old.isDark ||
        strokeWidth != old.strokeWidth;
  }
}
