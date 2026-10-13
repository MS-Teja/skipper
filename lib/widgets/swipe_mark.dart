import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../models/day_record.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Swipe right = present, left = absent. The card follows the finger with a
/// rubber band, tilts, reveals a lime/coral layer, gives haptics at the
/// threshold and springs back with an overshoot.
class SwipeToMark extends StatefulWidget {
  const SwipeToMark({
    super.key,
    required this.child,
    required this.onMark,
    this.enabled = true,
    this.radius = Radii.l,
  });

  final Widget child;
  final ValueChanged<PeriodMark> onMark;
  final bool enabled;
  final double radius;

  @override
  State<SwipeToMark> createState() => _SwipeToMarkState();
}

class _SwipeToMarkState extends State<SwipeToMark>
    with SingleTickerProviderStateMixin {
  static const _threshold = 84.0;
  static const _limit = 120.0;

  // Created eagerly: a lazy controller would be built (and throw) in
  // dispose() for cards that were never swiped.
  late final AnimationController _c;
  double _dx = 0;
  bool _armed = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() => _dx = _c.value));
  }

  void _update(DragUpdateDetails d) {
    var next = _dx + d.delta.dx;
    if (next.abs() > _limit) {
      // Rubber band past the limit.
      next = next.sign * (_limit + (next.abs() - _limit) * 0.3);
    }
    final armed = next.abs() >= _threshold;
    if (armed != _armed) {
      HapticFeedback.selectionClick();
      _armed = armed;
    }
    setState(() => _dx = next);
  }

  void _end(DragEndDetails d) {
    if (_dx >= _threshold) {
      HapticFeedback.mediumImpact();
      widget.onMark(PeriodMark.present);
    } else if (_dx <= -_threshold) {
      HapticFeedback.mediumImpact();
      widget.onMark(PeriodMark.absent);
    }
    _armed = false;
    final reduced = Motion.reduced(context);
    if (reduced) {
      setState(() => _dx = 0);
      return;
    }
    _c.value = _dx;
    _c.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 18),
        _dx,
        0,
        d.velocity.pixelsPerSecond.dx,
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final right = _dx >= 0;
    final progress = (_dx.abs() / _threshold).clamp(0.0, 1.0);
    final reduced = Motion.reduced(context);
    return GestureDetector(
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: progress,
              child: Container(
                decoration: ShapeDecoration(
                  color: right ? Moment.lime : Moment.coral,
                  shape: RoundedSuperellipseBorder(
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                alignment: right ? Alignment.centerLeft : Alignment.centerRight,
                child: Transform.scale(
                  scale: 0.7 + 0.4 * progress,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        right ? Icons.check_rounded : Icons.close_rounded,
                        color: Moment.ink,
                        size: 26,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        right ? 'Present!' : 'Absent',
                        style: display(22, color: Moment.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: Transform.rotate(
              angle: reduced ? 0 : _dx / 2400,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// One period: unmarked (dashed), present (filled + check), absent (coral + x).
class PeriodDot extends StatelessWidget {
  const PeriodDot({
    super.key,
    required this.mark,
    required this.onTap,
    required this.index,
    this.enabled = true,
  });

  final PeriodMark mark;
  final VoidCallback onTap;
  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final presentBg = dark ? Moment.lime : Moment.ink;
    final presentFg = dark ? Moment.ink : Moment.lime;
    final (bg, fg, border) = switch (mark) {
      PeriodMark.present => (presentBg, presentFg, presentBg),
      PeriodMark.absent => (Moment.coral, Moment.ink, Moment.coral),
      PeriodMark.cancelled => (c.track, c.muted, c.track),
      PeriodMark.unmarked => (Colors.transparent, c.muted, c.muted),
    };
    final label = switch (mark) {
      PeriodMark.present => 'present',
      PeriodMark.absent => 'absent',
      PeriodMark.cancelled => 'cancelled',
      PeriodMark.unmarked => 'not marked',
    };
    final rot = switch (mark) {
      PeriodMark.present => -0.1,
      PeriodMark.absent => 0.1,
      _ => 0.0,
    };
    return Semantics(
      button: enabled,
      label: 'Period ${index + 1}, $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: AnimatedRotation(
              turns: rot / (2 * math.pi),
              duration: Motion.d(context, Motion.slow),
              curve: Motion.pop,
              child: AnimatedScale(
                scale: mark == PeriodMark.unmarked ? 0.88 : 1,
                duration: Motion.d(context, Motion.slow),
                curve: Motion.pop,
                child: AnimatedContainer(
                  duration: Motion.d(context, Motion.fast),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: mark == PeriodMark.unmarked
                        ? null
                        : Border.all(color: border, width: 2),
                  ),
                  foregroundDecoration: mark == PeriodMark.unmarked
                      ? _DashedBorder(
                          color: border.withValues(alpha: enabled ? 0.9 : 0.4),
                        )
                      : null,
                  child: AnimatedSwitcher(
                    duration: Motion.d(context, Motion.fast),
                    transitionBuilder: (child, a) =>
                        ScaleTransition(scale: a, child: child),
                    child: switch (mark) {
                      PeriodMark.present => Icon(
                        Icons.check_rounded,
                        key: const ValueKey('p'),
                        size: 18,
                        color: fg,
                      ),
                      PeriodMark.absent => Icon(
                        Icons.close_rounded,
                        key: const ValueKey('a'),
                        size: 16,
                        color: fg,
                      ),
                      PeriodMark.cancelled => Icon(
                        Icons.remove_rounded,
                        key: const ValueKey('c'),
                        size: 16,
                        color: fg,
                      ),
                      PeriodMark.unmarked => const SizedBox.shrink(
                        key: ValueKey('u'),
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends Decoration {
  const _DashedBorder({required this.color});
  final Color color;
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DashedPainter(color);
}

class _DashedPainter extends BoxPainter {
  _DashedPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = (offset & cfg.size!).deflate(1);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(9)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 3.5), paint);
      }
    }
  }
}
