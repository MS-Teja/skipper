import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'motion.dart';

/// − value + with springy number changes.
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 99,
    this.label,
    this.big = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String? label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget button(IconData icon, int next, String tip) {
      final enabled = next >= min && next <= max;
      return IconButton(
        tooltip: tip,
        onPressed: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged(next);
              }
            : null,
        icon: Icon(icon, size: big ? 22 : 20),
        color: c.text,
        disabledColor: c.muted.withValues(alpha: 0.35),
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: big ? c.track : Colors.transparent,
        ),
      );
    }

    return Semantics(
      label: label,
      value: '$value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, value - 1, 'Fewer'),
          SizedBox(
            width: big ? 44 : 30,
            child: AnimatedSwitcher(
              duration: Motion.d(context, Motion.medium),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Motion.pop),
                child: FadeTransition(opacity: a, child: child),
              ),
              child: Text(
                '$value',
                key: ValueKey(value),
                textAlign: TextAlign.center,
                style: big
                    ? display(30, color: c.text)
                    : body(17, color: c.text, weight: 600),
              ),
            ),
          ),
          button(Icons.add_rounded, value + 1, 'More'),
        ],
      ),
    );
  }
}

/// Small grey heading above a group.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: body(
                13,
                color: c.muted,
                weight: 600,
              ).copyWith(letterSpacing: 0.3),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A white rounded group of rows with hairline dividers.
class Group extends StatelessWidget {
  const Group({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    // A Material (not a coloured box) so row press highlights show.
    return // Clip with the native superellipse clip: a squircle-shaped Material clip
    // falls back to a slow general path clip on every frame.
    ClipRSuperellipse(
      borderRadius: BorderRadius.circular(Radii.l),
      child: Material(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Radii.l),
          side: BorderSide(color: c.line),
        ),

        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 16, color: c.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A calm segmented control (two or three options).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final n = options.length;
    final index = options.indexWhere((o) => o.$1 == value).clamp(0, n - 1);

    // Equal segments, as wide as the widest label (like UISegmentedControl).
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final (_, label) in options) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: body(14, weight: 600)),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (tp.width > widest) widest = tp.width;
      tp.dispose();
    }
    final seg = widest.ceilToDouble() + 28;

    return Container(
      width: seg * n + 6,
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(
        color: c.track,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Stack(
        children: [
          // The thumb slides on a spring and keeps its velocity if the
          // selection changes mid-slide.
          Positioned.fill(
            child: SpringBuilder(
              value: index.toDouble(),
              response: 0.32,
              damping: 0.9,
              builder: (context, v, child) => Padding(
                padding: EdgeInsets.only(left: v * seg),
                child: Align(alignment: Alignment.centerLeft, child: child),
              ),
              child: Container(
                width: seg,
                decoration: BoxDecoration(
                  color: dark ? const Color(0xFF3A3D44) : c.surface,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (v, label) in options)
                Semantics(
                  selected: v == value,
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (v == value) return;
                      HapticFeedback.selectionClick();
                      onChanged(v);
                    },
                    child: Container(
                      width: seg,
                      constraints: const BoxConstraints(minHeight: 36),
                      alignment: Alignment.center,
                      child: AnimatedDefaultTextStyle(
                        duration: Motion.d(context, Motion.fast),
                        style: body(
                          14,
                          color: v == value ? c.text : c.muted,
                          weight: v == value ? 600 : 500,
                        ),
                        child: Text(label, maxLines: 1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A settings row with an iOS-style switch (on every platform). The whole
/// row toggles it, like UITableView switch cells.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.secondary,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? secondary;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    void toggle(bool v) {
      HapticFeedback.selectionClick();
      onChanged(v);
    }

    return MergeSemantics(
      child: ListTile(
        leading: secondary,
        title: title,
        subtitle: subtitle,
        onTap: () => toggle(!value),
        trailing: CupertinoSwitch(
          value: value,
          activeTrackColor: c.accent,
          onChanged: toggle,
        ),
      ),
    );
  }
}

/// A section heading in the display face ("Classes", "History"), with an
/// optional action on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: display(22, color: c.text)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// An iOS-style row with a tick circle; the whole row toggles.
class CheckRow extends StatelessWidget {
  const CheckRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      checked: value,
      button: true,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.d(context, Motion.fast),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: value ? c.accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value ? c.accent : c.muted.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: value
                    ? Icon(Icons.check_rounded, size: 16, color: c.onAccent)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: body(16, color: c.text, weight: 500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: body(13, color: c.muted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
