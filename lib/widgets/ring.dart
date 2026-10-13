import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'motion.dart';

/// A progress ring. Its colour carries the verdict (safe / edge / at risk).
/// Sweeps in with a spring when it first appears and whenever the value
/// changes.
class AttendanceRing extends StatelessWidget {
  const AttendanceRing({
    super.key,
    required this.ratio,
    required this.color,
    required this.track,
    this.size = 48,
    this.stroke = 5,
    this.child,
    this.delay = Duration.zero,
  });

  final double ratio;
  final Color color;
  final Color track;
  final double size;
  final double stroke;
  final Widget? child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: SpringBuilder(
          from: reduced ? null : 0,
          value: ratio.clamp(0.0, 1.0),
          delay: delay,
          response: 0.8,
          damping: 0.82,
          child: Center(child: child),
          builder: (context, value, child) => CustomPaint(
            painter: _RingPainter(
              value: math.max(0, value),
              color: color,
              track: track,
              stroke: stroke,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double value;
  final Color color, track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, base..color = track);
    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * value.clamp(0.0, 1.0),
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
