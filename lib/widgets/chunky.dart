import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The B-moment surface: ink outline, hard offset shadow, presses down.
/// Used only for callouts, celebrations, tickets and primary moments.
class Chunky extends StatefulWidget {
  const Chunky({
    super.key,
    required this.child,
    required this.color,
    this.onTap,
    this.radius = Radii.m,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.depth = 3,
    this.semanticLabel,
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  final EdgeInsets padding;
  final double depth;
  final String? semanticLabel;

  @override
  State<Chunky> createState() => _ChunkyState();
}

class _ChunkyState extends State<Chunky> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final edge = dark ? Colors.black : Moment.ink;
    final pressed = _down ? widget.depth : 0.0;
    final box = AnimatedContainer(
      duration: Motion.d(context, const Duration(milliseconds: 90)),
      transform: Matrix4.translationValues(0, pressed, 0),
      padding: widget.padding,
      decoration: ShapeDecoration(
        color: widget.color,
        // Capsules keep round ends; boxes get continuous (squircle) corners.
        shape: widget.radius >= 100
            ? StadiumBorder(side: BorderSide(color: edge, width: 2))
            : RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(widget.radius),
                side: BorderSide(color: edge, width: 2),
              ),
        shadows: [
          BoxShadow(color: edge, offset: Offset(0, widget.depth - pressed)),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Moment.ink),
        child: IconTheme.merge(
          data: const IconThemeData(color: Moment.ink),
          child: widget.child,
        ),
      ),
    );
    if (widget.onTap == null) return box;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap!();
        },
        child: box,
      ),
    );
  }
}

/// A small rounded label.
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    required this.background,
    required this.foreground,
    this.icon,
    this.dense = false,
  });

  final String text;
  final Color background;
  final Color foreground;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.d(context, Motion.medium),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 11,
        vertical: dense ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 13 : 15, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: body(dense ? 12 : 13, color: foreground, weight: 600),
          ),
        ],
      ),
    );
  }
}

/// Colours for a status pill by risk: safe = ink/lime, edge = sun, danger = coral.
(Color, Color) pillColors(
  BuildContext context, {
  required bool danger,
  required bool edge,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (danger) return (Moment.coral, Moment.ink);
  if (edge) return (Moment.sun, Moment.ink);
  return dark ? (Moment.lime, Moment.ink) : (Moment.ink, Moment.lime);
}

/// Round icon button in the calm style.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: c.surface,
        shape: CircleBorder(side: BorderSide(color: c.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 44,
            child: Icon(icon, size: 20, color: c.text),
          ),
        ),
      ),
    );
  }
}
