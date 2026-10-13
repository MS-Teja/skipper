import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

enum Illustration { beach, books, calendar, cloud, party }

/// Illustrated empty / error state with a witty line and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.art,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final Illustration art;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 16 : 32,
        horizontal: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: compact ? 96 : 132,
            height: compact ? 72 : 100,
            child: CustomPaint(
              painter: _ArtPainter(art, c, Theme.of(context).brightness),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: display(compact ? 20 : 24, color: c.text, height: 1.15),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: body(15, color: c.muted, height: 1.4),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, this.c, this.brightness);
  final Illustration art;
  final AppColors c;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size s) {
    final ink = brightness == Brightness.dark ? Colors.black : Moment.ink;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    Paint fill(Color col) => Paint()..color = col;
    void shape(Path p, Color col) {
      canvas.drawPath(p.shift(const Offset(0, 4)), fill(ink));
      canvas.drawPath(p, fill(col));
      canvas.drawPath(p, stroke);
    }

    final w = s.width, h = s.height;
    switch (art) {
      case Illustration.beach:
        canvas.drawCircle(Offset(w * .74, h * .26), h * .17, fill(Moment.sun));
        canvas.drawCircle(Offset(w * .74, h * .26), h * .17, stroke);
        shape(
          Path()..addRRect(
            RRect.fromLTRBR(
              w * .06,
              h * .66,
              w * .94,
              h * .9,
              const Radius.circular(12),
            ),
          ),
          Moment.lime,
        );
        final umbrella = Path()
          ..moveTo(w * .18, h * .5)
          ..quadraticBezierTo(w * .36, h * .08, w * .58, h * .5)
          ..close();
        shape(umbrella, Moment.coral);
        canvas.drawLine(
          Offset(w * .38, h * .44),
          Offset(w * .42, h * .72),
          stroke,
        );
      case Illustration.books:
        for (var i = 0; i < 3; i++) {
          final colors = [Moment.coral, Moment.lime, Moment.sun];
          shape(
            Path()..addRRect(
              RRect.fromLTRBR(
                w * (.16 + i * .22),
                h * (.22 + i * .06),
                w * (.34 + i * .22),
                h * .88,
                const Radius.circular(6),
              ),
            ),
            colors[i],
          );
        }
      case Illustration.calendar:
        shape(
          Path()..addRRect(
            RRect.fromLTRBR(
              w * .18,
              h * .14,
              w * .82,
              h * .9,
              const Radius.circular(14),
            ),
          ),
          c.surface,
        );
        canvas.drawRect(
          Rect.fromLTRB(w * .18 + 1.5, h * .14 + 1.5, w * .82 - 1.5, h * .36),
          fill(Moment.coral),
        );
        canvas.drawLine(
          Offset(w * .18, h * .36),
          Offset(w * .82, h * .36),
          stroke,
        );
        final check = Path()
          ..moveTo(w * .38, h * .62)
          ..lineTo(w * .48, h * .73)
          ..lineTo(w * .64, h * .52);
        canvas.drawPath(check, stroke..strokeWidth = 4);
      case Illustration.cloud:
        Path oval(double x, double y, double r) => Path()
          ..addOval(
            Rect.fromCircle(center: Offset(w * x, h * y), radius: h * r),
          );
        final base = Path()
          ..addRRect(
            RRect.fromLTRBR(
              w * .2,
              h * .55,
              w * .82,
              h * .82,
              const Radius.circular(20),
            ),
          );
        final cloud = Path.combine(
          PathOperation.union,
          Path.combine(
            PathOperation.union,
            oval(.38, .55, .22),
            oval(.58, .45, .28),
          ),
          base,
        );
        shape(cloud, c.surface);
        canvas.drawLine(
          Offset(w * .42, h * .66),
          Offset(w * .58, h * .66),
          stroke,
        );
      case Illustration.party:
        final rnd = math.Random(4);
        for (var i = 0; i < 14; i++) {
          final colors = [Moment.coral, Moment.lime, Moment.sun, c.accent];
          final o = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * .55);
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(rnd.nextDouble() * math.pi);
          canvas.drawRect(
            const Rect.fromLTWH(-4, -2, 8, 4),
            fill(colors[i % 4]),
          );
          canvas.restore();
        }
        final cone = Path()
          ..moveTo(w * .3, h * .92)
          ..lineTo(w * .5, h * .4)
          ..lineTo(w * .7, h * .92)
          ..close();
        shape(cone, Moment.lime);
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.art != art || old.brightness != brightness;
}

/// A soft moving highlight for loading placeholders.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: [c.track, c.surface, c.track],
          stops: const [0.35, 0.5, 0.65],
          begin: Alignment(-1.6 + 3.2 * _c.value, -0.3),
          end: Alignment(-0.6 + 3.2 * _c.value, 0.3),
        ).createShader(rect),
        child: child,
      ),
    );
  }
}

/// A grey block used inside [Shimmer].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: ShapeDecoration(
      color: AppColors.of(context).track,
      shape: RoundedSuperellipseBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
  );
}
