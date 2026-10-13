import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// An iOS-style slider for a whole-number percentage.
///
/// The thumb follows the finger 1:1 (sub-step precision while dragging), a
/// selection haptic ticks on every whole step and a firmer one at [detent].
/// [onChanged] fires per step for live previews; [onChangeEnd] once on
/// release, so expensive work (saving, recomputing) never runs per frame.
class TargetSlider extends StatefulWidget {
  const TargetSlider({
    super.key,
    required this.value,
    required this.onChangeEnd,
    this.onChanged,
    this.min = 50,
    this.max = 100,
    this.detent = 75,
  });

  final int value;
  final int min, max, detent;
  final ValueChanged<int>? onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  State<TargetSlider> createState() => _TargetSliderState();
}

class _TargetSliderState extends State<TargetSlider> {
  static const _thumb = 28.0;

  /// Exact position while dragging, else null (show [TargetSlider.value]).
  double? _drag;
  int? _lastStep;

  double get _position => _drag ?? widget.value.toDouble();

  void _moveTo(double dx, double width) {
    final usable = width - _thumb;
    final t = ((dx - _thumb / 2) / usable).clamp(0.0, 1.0);
    final v = widget.min + t * (widget.max - widget.min);
    final step = v.round();
    if (step != _lastStep) {
      if (step == widget.detent) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
      _lastStep = step;
      widget.onChanged?.call(step);
    }
    setState(() => _drag = v);
  }

  void _end() {
    final step = _position.round();
    setState(() => _drag = null);
    _lastStep = null;
    widget.onChangeEnd(step);
  }

  void _nudge(int by) {
    final v = (widget.value + by).clamp(widget.min, widget.max);
    HapticFeedback.selectionClick();
    widget.onChanged?.call(v);
    widget.onChangeEnd(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = (_position - widget.min) / (widget.max - widget.min);
    final dragging = _drag != null;
    return Semantics(
      slider: true,
      value: '${_position.round()}%',
      increasedValue: '${(widget.value + 1).clamp(widget.min, widget.max)}%',
      decreasedValue: '${(widget.value - 1).clamp(widget.min, widget.max)}%',
      onIncrease: () => _nudge(1),
      onDecrease: () => _nudge(-1),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final x = _thumb / 2 + t * (w - _thumb);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (d) => _moveTo(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _moveTo(d.localPosition.dx, w),
            onHorizontalDragEnd: (_) => _end(),
            onHorizontalDragCancel: _end,
            onTapDown: (d) => _moveTo(d.localPosition.dx, w),
            onTapUp: (_) => _end(),
            child: SizedBox(
              height: 44,
              child: RepaintBoundary(
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: _thumb / 2,
                      right: _thumb / 2,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.track,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      left: _thumb / 2,
                      width: x - _thumb / 2,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      left: x - _thumb / 2,
                      child: AnimatedScale(
                        scale: dragging ? 1.12 : 1,
                        duration: Motion.d(context, Motion.fast),
                        curve: Motion.spring,
                        child: Container(
                          width: _thumb,
                          height: _thumb,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.06),
                              width: 0.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                              BoxShadow(
                                color: Color(0x0F000000),
                                blurRadius: 1,
                                offset: Offset(0, 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
