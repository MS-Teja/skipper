import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../models/settings.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../services/attendance_math.dart';
import '../../services/schedule_engine.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../widgets/chunky.dart';
import '../../widgets/motion.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';
import '../../widgets/inputs.dart';
import '../../widgets/large_title.dart';
import '../../widgets/swipe_mark.dart';
import '../home_shell.dart';
import 'class_card.dart';
import 'day_sheets.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime _day = today();

  /// Applies a mark; a firm haptic when it completes the day.
  Future<void> _mark(Future<void> Function() change) async {
    final a = context.read<AttendanceProvider>();
    bool done() {
      final cs = a.classesOn(_day);
      return cs.isNotEmpty && cs.every((e) => e.fullyMarked);
    }

    final before = done();
    await change();
    if (!before && done()) HapticFeedback.mediumImpact();
  }

  void _select(DateTime d) {
    HapticFeedback.selectionClick();
    setState(() => _day = dayOnly(d));
  }

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AttendanceProvider>();
    final classes = a.classesOn(_day);
    final isFuture = _day.isAfter(today());
    final allMarked = classes.isNotEmpty && classes.every((e) => e.fullyMarked);
    final rel = relativeDay(_day);
    return LargeTitleScrollView(
      overline: _overline(_day),
      title: rel.contains(' ') ? _weekdays[_day.weekday - 1] : rel,
      trailing: isSameDay(_day, today())
          ? null
          : TextButton(
              onPressed: () => _select(today()),
              child: const Text('Today'),
            ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.list(
            children: [
              _WeekStrip(selected: _day, onSelect: _select),
              const SizedBox(height: 16),
              const _Hero(),
              if (a.pendingCount > 0) ...[
                const SizedBox(height: 12),
                _PendingBanner(count: a.pendingCount),
              ],
              const SizedBox(height: 26),
              if (classes.isNotEmpty) const SectionTitle('Classes'),
            ],
          ),
        ),
        if (classes.isEmpty)
          SliverToBoxAdapter(child: _OffDay(day: _day))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            sliver: SliverList.separated(
              itemCount: classes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final entry = classes[i];
                return StaggerIn(
                  key: ValueKey(entry.subject.id),
                  index: i,
                  child: SwipeToMark(
                    enabled: !isFuture,
                    onMark: (m) => _mark(() => a.markAll(_day, entry, m)),
                    child: ClassCard(
                      entry: entry,
                      stats: a.statsFor(entry.subject),
                      rule: a.rule,
                      enabled: !isFuture,
                      onDot: (index) =>
                          _mark(() => a.cycleMark(_day, entry, index)),
                      onLongPress: () => showClassSheet(context, _day, entry),
                    ),
                  ),
                );
              },
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 16, Space.gutter, 0),
          sliver: SliverList.list(
            children: [
              if (allMarked && !isFuture)
                Center(
                  child: PopIn(
                    key: ValueKey('done${dayKey(_day)}'),
                    child: Chunky(
                      color: Moment.lime,
                      radius: 999,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_rounded, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Day done.',
                            style: display(18, color: Moment.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              _DayActions(day: _day, hasClasses: classes.isNotEmpty),
            ],
          ),
        ),
      ],
    );
  }
}

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// "Wednesday 7 October".
String _overline(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${_weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}

/// Big overall % + a single moment chip that sums up the rule.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = context.watch<AttendanceProvider>();
    final overall = a.overall;
    if (a.subjects.isEmpty) return const SizedBox.shrink();

    final String chip;
    final Color chipColor;
    if (a.rule == AttendanceRule.overall) {
      chip = statusLabel(overall);
      chipColor = !overall.isAtOrAboveTarget
          ? Moment.coral
          : overall.canSkip == 0
          ? Moment.sun
          : Moment.lime;
    } else {
      final risk = a.atRisk;
      chip = risk.isEmpty
          ? 'All safe'
          : risk.length <= 2
          ? '${risk.map((s) => s.code).join(' & ')} slipping'
          : '${risk.length} slipping';
      chipColor = risk.isEmpty ? Moment.lime : Moment.coral;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: ShapeDecoration(
        color: c.surface,
        shape: RoundedSuperellipseBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
          side: BorderSide(color: c.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overall.hasClasses)
                    RollingNumber(
                      overall.percentFloor,
                      style: display(64, color: c.text, height: 0.9),
                      suffix: '%',
                      suffixStyle: display(28, color: c.muted),
                    )
                  else
                    Text(
                      'New sem',
                      style: display(44, color: c.text, height: 0.95),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Shrinks rather than overflowing on narrow phones.
              Flexible(
                child: Align(
                  alignment: Alignment.topRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Chunky(
                      color: chipColor,
                      radius: 999,
                      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                      semanticLabel: '$chip. Open attendance',
                      onTap: () => HomeShell.of(context)?.goTo(1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            chip,
                            style: display(16, color: Moment.ink, weight: 700),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TargetBar(stats: overall),
        ],
      ),
    );
  }
}

class _TargetBar extends StatelessWidget {
  const _TargetBar({required this.stats});
  final AttendanceStats stats;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        return SizedBox(
          height: 6,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: c.track,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SpringBuilder(
                from: 0,
                value: stats.ratio,
                response: 0.8,
                damping: 0.85,
                builder: (context, v, _) => Container(
                  width: (w * v.clamp(0, 1)).toDouble(),
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.risk(stats.risk),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.selected, required this.onSelect});
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = context.watch<AttendanceProvider>();
    final monday = startOfWeek(selected);
    final days = a.settings.sundayClasses ? 7 : 6;
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final now = today();

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 200) return;
        onSelect(addDays(selected, v < 0 ? 7 : -7));
      },
      child: Row(
        children: [
          for (var i = 0; i < days; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final d = addDays(monday, i);
                  final sel = isSameDay(d, selected);
                  final entries = a.classesOn(d);
                  final off = entries.isEmpty;
                  final future = d.isAfter(now);
                  final unmarked = entries.fold(0, (n, e) => n + e.unmarked);
                  final dot = off || future
                      ? Colors.transparent
                      : unmarked == 0
                      ? c.accent
                      : (isSameDay(d, now) ? c.muted : Moment.coral);
                  final fg = sel
                      ? c.onInverse
                      : (off
                            ? c.muted.withValues(alpha: 0.6)
                            : (future ? c.muted : c.text));
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Semantics(
                      selected: sel,
                      button: true,
                      label:
                          '${shortDate(d)}${off
                              ? ', no classes'
                              : unmarked > 0 && !future
                              ? ', $unmarked unmarked'
                              : ''}',
                      child: GestureDetector(
                        onTap: () => onSelect(d),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                letters[d.weekday - 1],
                                style: body(12, color: c.muted, weight: 500),
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: Motion.d(context, Motion.medium),
                                curve: Motion.spring,
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: sel ? c.inverse : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '${d.day}',
                                  style: body(
                                    17,
                                    color: fg,
                                    weight: sel ? 700 : 500,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedContainer(
                                duration: Motion.d(context, Motion.medium),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: dot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.m),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.m),
        onTap: () => Navigator.pushNamed(context, Routes.pending),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(Radii.m),
              side: BorderSide(color: c.line),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Moment.coral,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${plural(count, 'earlier class', 'earlier classes')} not marked',
                  style: body(15, color: c.text, weight: 500),
                ),
              ),
              Text('Review', style: body(15, color: c.accent, weight: 600)),
              Icon(Icons.chevron_right_rounded, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _OffDay extends StatelessWidget {
  const _OffDay({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AttendanceProvider>();
    final reason = a.offReason(day);
    final engine = a.engine;
    const weekdays = [
      'Mondays',
      'Tuesdays',
      'Wednesdays',
      'Thursdays',
      'Fridays',
      'Saturdays',
      'Sundays',
    ];
    final (art, title, message) = switch (reason) {
      OffReason.holiday => (
        Illustration.beach,
        engine.holidayOn(day)!.name,
        'No classes. Enjoy it.',
      ),
      OffReason.breakPeriod => (
        Illustration.books,
        engine.breakOn(day)!.label,
        'Classes don’t count during a break.',
      ),
      OffReason.sunday => (
        Illustration.beach,
        'Sunday',
        'Rest up. Monday’s coming.',
      ),
      OffReason.beforeTracking => (
        Illustration.calendar,
        'Before tracking began',
        'Earlier attendance lives in each subject’s starting numbers.',
      ),
      _ => (
        Illustration.calendar,
        'No classes',
        'Your timetable is free on ${weekdays[day.weekday - 1]}.',
      ),
    };
    return StaggerIn(
      index: 0,
      child: EmptyState(
        art: art,
        title: title,
        message: message,
        compact: true,
      ),
    );
  }
}

class _DayActions extends StatelessWidget {
  const _DayActions({required this.day, required this.hasClasses});
  final DateTime day;
  final bool hasClasses;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final holidays = context.watch<HolidayProvider>();
    final manual = holidays.manualHolidayOn(day);
    final style = TextButton.styleFrom(
      foregroundColor: c.accent,
      textStyle: body(16, weight: 500),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      children: [
        if (manual != null)
          TextButton(
            style: style,
            onPressed: () => holidays.removeHoliday(manual),
            child: const Text('Not a holiday'),
          )
        else if (hasClasses)
          TextButton(
            style: style,
            onPressed: () => showHolidaySheet(context, day),
            child: const Text('Mark holiday'),
          ),
        TextButton(
          style: style,
          onPressed: () => showExtraClassSheet(context, day),
          child: const Text('Add extra class'),
        ),
      ],
    );
  }
}
