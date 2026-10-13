import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../providers/attendance_provider.dart';
import '../../services/attendance_math.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../widgets/chunky.dart';
import '../../widgets/inputs.dart';
import '../../widgets/large_title.dart';
import '../../widgets/motion.dart';
import '../../widgets/ring.dart';
import '../../widgets/status.dart';

/// One subject's attendance, or the overall total when [subjectId] is null.
class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.subjectId});
  final String? subjectId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  int _skip = 1;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = Theme.of(context).brightness;
    final a = context.watch<AttendanceProvider>();
    final subject = widget.subjectId == null
        ? null
        : a.subjects.where((s) => s.id == widget.subjectId).firstOrNull;
    if (widget.subjectId != null && subject == null) {
      // Deleted while open.
      return Scaffold(appBar: AppBar());
    }
    final stats = subject == null ? a.overall : a.statsFor(subject);
    final color = subject == null ? null : subjectColor(subject.colorIndex);

    final (calloutColor, calloutIcon) = !stats.hasClasses
        ? (c.surface, Icons.hourglass_empty_rounded)
        : !stats.isAtOrAboveTarget
        ? (Moment.coral, Icons.trending_up_rounded)
        : stats.canSkip == 0
        ? (Moment.sun, Icons.warning_amber_rounded)
        : (Moment.lime, Icons.celebration_outlined);

    return Scaffold(
      body: LargeTitleScrollView(
        overline: subject?.name ?? 'All subjects',
        title: subject?.code ?? 'Overall',
        leading: const BackButton(),
        bottomPadding: 40,
        trailing: subject == null
            ? null
            : RoundIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit subject',
                onPressed: () => Navigator.pushNamed(
                  context,
                  Routes.subjectForm,
                  arguments: subject.id,
                ),
              ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverList.list(
              children: [
                // Hero: the subject's own colour, like its Today card.
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
                  decoration: ShapeDecoration(
                    color: color?.fill(b) ?? c.surface,
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(Radii.xl),
                      side: BorderSide(color: color?.border(b) ?? c.line),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: stats.hasClasses
                                  ? RollingNumber(
                                      stats.percentFloor,
                                      style: display(
                                        60,
                                        color: c.text,
                                        height: 0.9,
                                      ),
                                      suffix: '%',
                                      suffixStyle: display(26, color: c.muted),
                                    )
                                  : Text(
                                      '–',
                                      style: display(60, color: c.text),
                                    ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${stats.attended} of ${stats.conducted} attended',
                              style: body(14, color: c.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AttendanceRing(
                        ratio: stats.ratio,
                        color: c.risk(stats.risk),
                        track: color == null
                            ? c.track
                            : c.bg.withValues(alpha: 0.7),
                        size: 92,
                        stroke: 11,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PopIn(
                  rotate: 0,
                  child: Chunky(
                    color: calloutColor,
                    radius: Radii.l,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(calloutIcon, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            statusLabel(stats, long: true),
                            style: display(
                              18,
                              color: Moment.ink,
                              weight: 700,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (stats.hasClasses) ...[
                  const SizedBox(height: 28),
                  const SectionTitle('What if I skip'),
                  _WhatIf(
                    stats: stats,
                    skip: _skip,
                    onChanged: (v) => setState(() => _skip = v),
                  ),
                ],
                const SizedBox(height: 28),
                const SectionTitle('History'),
                _Heatmap(subjectId: widget.subjectId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatIf extends StatelessWidget {
  const _WhatIf({
    required this.stats,
    required this.skip,
    required this.onChanged,
  });
  final AttendanceStats stats;
  final int skip;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final after = stats.afterSkipping(skip);
    final need = after.toRecover;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 18, 14),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Radii.l),
          side: BorderSide(color: c.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.translate(
                      offset: const Offset(-10, 0),
                      child: CountStepper(
                        value: skip,
                        min: 1,
                        max: 30,
                        big: true,
                        label: 'Classes to skip',
                        onChanged: onChanged,
                      ),
                    ),
                  ],
                ),
              ),
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: c.risk(after.risk)),
                duration: Motion.d(context, Motion.medium),
                builder: (context, color, _) => RollingNumber(
                  after.percentFloor,
                  style: display(44, color: color),
                  suffix: '%',
                  suffixStyle: display(20, color: color, weight: 700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            after.isAtOrAboveTarget
                ? 'Still safe. ${plural(after.canSkip, 'skip', 'skips')} left after that.'
                : need == null
                ? 'You couldn’t get back to ${stats.target}%.'
                : 'Then you’d need ${plural(need, 'class', 'classes')} in a row to recover.',
            style: body(14, color: c.muted),
          ),
        ],
      ),
    );
  }
}

/// Weeks as columns, weekdays as rows, coloured by how each day went.
class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.subjectId});
  final String? subjectId;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = context.watch<AttendanceProvider>();
    final now = today();
    // Only weeks since tracking began (6–10 columns) and only weekdays
    // that actually have this subject.
    final start = a.settings.trackingStart ?? now;
    final weeks =
        (startOfWeek(now).difference(startOfWeek(start)).inDays ~/ 7 + 1).clamp(
          6,
          10,
        );
    final firstMonday = addDays(startOfWeek(now), -7 * (weeks - 1));
    final rowDays = [
      for (var r = 0; r < (a.settings.sundayClasses ? 7 : 6); r++)
        if (Iterable.generate(
          weeks,
          (w) => addDays(firstMonday, 7 * w + r),
        ).any(
          (d) => a
              .classesOn(d)
              .any((e) => subjectId == null || e.subject.id == subjectId),
        ))
          r,
    ];
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    (Color, Border?) cell(DateTime d) {
      if (d.isAfter(now)) {
        return (Colors.transparent, Border.all(color: c.line));
      }
      var att = 0, held = 0, unmarked = 0, scheduled = 0;
      for (final e in a.classesOn(d)) {
        if (subjectId != null && e.subject.id != subjectId) continue;
        att += e.attended;
        held += e.held;
        unmarked += e.unmarked;
        scheduled += e.periods;
      }
      if (scheduled == 0) return (c.track.withValues(alpha: 0.5), null);
      if (unmarked > 0 && held == 0) {
        return (Colors.transparent, Border.all(color: c.muted, width: 1.4));
      }
      if (held == 0) return (c.track, null);
      if (att == held) return (c.accent, null);
      if (att == 0) return (c.danger, null);
      return (c.accent.withValues(alpha: 0.42), null);
    }

    // One fade for the whole grid (cheaper than animating ~60 cells).
    final grid = Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 18),
            for (var w = 0; w < weeks; w++)
              Expanded(
                child: Builder(
                  builder: (_) {
                    final monday = addDays(firstMonday, 7 * w);
                    final show = w == 0 || monday.day <= 7;
                    return Text(
                      show ? months[monday.month - 1] : '',
                      style: body(11, color: c.muted),
                    );
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final r in rowDays)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: Text(letters[r], style: body(11, color: c.muted)),
                ),
                for (var w = 0; w < weeks; w++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Builder(
                        builder: (_) {
                          final (fill, border) = cell(
                            addDays(firstMonday, 7 * w + r),
                          );
                          return Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: fill,
                              border: border,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (label, color) in [
              ('Present', c.accent),
              ('Partly', c.accent.withValues(alpha: 0.42)),
              ('Missed', c.danger),
            ]) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(label, style: body(12, color: c.muted)),
              const SizedBox(width: 14),
            ],
          ],
        ),
      ],
    );
    return SpringBuilder(
      from: 0,
      value: 1,
      response: 0.5,
      damping: 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: ShapeDecoration(
          color: c.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(Radii.l),
            side: BorderSide(color: c.line),
          ),
        ),
        child: grid,
      ),
      builder: (context, t, child) =>
          Opacity(opacity: t.clamp(0.0, 1.0), child: child),
    );
  }
}
