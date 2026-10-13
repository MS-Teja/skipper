import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// Animates a number with a spring, the way UIKit does: when [value]
/// changes mid-flight the spring retargets from where it is *with its current
/// velocity*, so interrupted animations never jump or restart.
///
/// [response] is roughly the duration in seconds; [damping] 1 settles without
/// overshoot, lower values overshoot once. Starts at [from] (then springs to
/// [value] after [delay]) or directly at [value].
class SpringBuilder extends StatefulWidget {
  const SpringBuilder({
    super.key,
    required this.value,
    required this.builder,
    this.from,
    this.delay = Duration.zero,
    this.response = 0.45,
    this.damping = 0.86,
    this.child,
  });

  final double value;
  final double? from;
  final Duration delay;
  final double response;
  final double damping;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<SpringBuilder> createState() => _SpringBuilderState();
}

class _SpringBuilderState extends State<SpringBuilder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  SpringDescription get _spring {
    // Apple's response / damping-fraction parameterisation.
    final k = math.pow(2 * math.pi / widget.response, 2).toDouble();
    final d = 4 * math.pi * widget.damping / widget.response;
    return SpringDescription(mass: 1, stiffness: k, damping: d);
  }

  @override
  void initState() {
    super.initState();
    _c = AnimationController.unbounded(
      vsync: this,
      value: widget.from ?? widget.value,
    );
    if (widget.from != null && widget.from != widget.value) {
      Future.delayed(widget.delay, () {
        if (mounted) _to(widget.value);
      });
    }
  }

  void _to(double target) {
    if (Motion.reduced(context)) {
      _c.value = target;
      return;
    }
    _c.animateWith(
      SpringSimulation(
        _spring,
        _c.value,
        target,
        _c.velocity,
        tolerance: const Tolerance(distance: 1e-4, velocity: 1e-3),
      ),
    );
  }

  @override
  void didUpdateWidget(SpringBuilder old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _to(widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => widget.builder(context, _c.value, child),
  );
}

/// Counts smoothly to [value] whenever it changes.
class RollingNumber extends StatelessWidget {
  const RollingNumber(
    this.value, {
    super.key,
    required this.style,
    this.suffix,
    this.suffixStyle,
  });

  final int value;
  final TextStyle style;
  final String? suffix;
  final TextStyle? suffixStyle;

  @override
  Widget build(BuildContext context) {
    return SpringBuilder(
      value: value.toDouble(),
      response: 0.6,
      damping: 1,
      builder: (context, v, _) => Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${v.round()}', style: style),
            if (suffix != null)
              TextSpan(text: suffix, style: suffixStyle ?? style),
          ],
        ),
        semanticsLabel: '$value${suffix ?? ''}',
      ),
    );
  }
}

/// Fades and slides a child in, [index] steps after its siblings.
class StaggerIn extends StatefulWidget {
  const StaggerIn({
    super.key,
    required this.index,
    required this.child,
    this.offset = 18,
  });

  final int index;
  final Widget child;
  final double offset;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    Future.delayed(Duration(milliseconds: 40 * math.min(widget.index, 10)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Motion.calm.transform(_c.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * widget.offset),
            child: child,
          ),
        );
      },
    );
  }
}

/// Shrinks a little while pressed. Wrap anything tappable.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.d(context, _down ? Motion.fast : Motion.medium),
        curve: _down ? Curves.easeOut : Motion.bounce,
        child: widget.child,
      ),
    );
  }
}

/// Shakes its child horizontally when [ShakeController.shake] is called.
class ShakeController extends ChangeNotifier {
  void shake() {
    HapticFeedback.mediumImpact();
    notifyListeners();
  }
}

class Shake extends StatefulWidget {
  const Shake({super.key, required this.controller, required this.child});
  final ShakeController controller;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    widget.controller.addListener(_run);
  }

  void _run() => _c.forward(from: 0);

  @override
  void dispose() {
    widget.controller.removeListener(_run);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = _c.value;
      final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
  );
}

/// Pops in with an overshoot (scale + slight rotation) — the "stamp" moment.
class PopIn extends StatelessWidget {
  const PopIn({
    super.key,
    required this.child,
    this.rotate = -0.06,
    this.delay = Duration.zero,
  });
  final Widget child;
  final double rotate;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 620),
      curve: Motion.pop,
      child: child,
      builder: (context, t, child) => Transform.rotate(
        angle: rotate * (1 - t.clamp(0, 1)) * 3 + rotate * 0.3,
        child: Transform.scale(
          scale: 0.4 + 0.6 * t,
          child: Opacity(opacity: t.clamp(0, 1), child: child),
        ),
      ),
    );
  }
}
