import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../models/settings.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../providers/planner_provider.dart';
import '../../services/leave_planner.dart';
import '../../services/long_weekend_finder.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../widgets/chunky.dart';
import '../../widgets/inputs.dart';
import '../../widgets/large_title.dart';
import '../../widgets/motion.dart';
import '../../widgets/states.dart';
import '../../widgets/pickers.dart';
import '../home_shell.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  Future<void> _pickRange() async {
    final p = context.read<PlannerProvider>();
    final range = await pickDateRange(
      context,
      first: today(),
      last: addDays(today(), 365),
      initial: p.hasRange ? DateTimeRange(start: p.start!, end: p.end!) : null,
      title: 'When will you be away?',
      done: 'Check',
    );
    if (range != null) p.setRange(range.start, range.end);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final planner = context.watch<PlannerProvider>();
    final plan = planner.plan;
    // Best-value option per holiday only; the finder already ranks them.
    final seen = <String>{};
    final weekends = [
      for (final w in planner.longWeekends)
        if (seen.add(w.holidays.map((h) => h.key).join())) w,
    ];
    final hasHolidays = context.watch<HolidayProvider>().holidays.any(
      (h) => h.applied,
    );

    return LargeTitleScrollView(
      title: 'Planner',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.list(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
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
                      children: [
                        Expanded(
                          child: Text(
                            'Can I take a leave?',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (plan != null)
                          IconButton(
                            tooltip: 'Clear',
                            onPressed: planner.clear,
                            icon: Icon(Icons.close_rounded, color: c.muted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range_rounded),
                      label: Text(
                        plan == null
                            ? 'Pick dates'
                            : isSameDay(plan.start, plan.end)
                            ? shortDate(plan.start)
                            : '${shortDate(plan.start)}  →  ${shortDate(plan.end)}',
                      ),
                    ),
                    if (plan != null) ...[
                      const SizedBox(height: 18),
                      _PlanResult(plan: plan),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const SectionTitle('Long weekends'),
              if (!hasHolidays)
                EmptyState(
                  art: Illustration.beach,
                  compact: true,
                  title: 'Holidays first',
                  message:
                      'Import this year’s holidays and I’ll find the long weekends.',
                  action: OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.holidays),
                    child: const Text('Import holidays'),
                  ),
                )
              else if (weekends.isEmpty)
                const EmptyState(
                  art: Illustration.calendar,
                  compact: true,
                  title: 'Nothing in the next 60 days',
                  message:
                      'No holiday sits close enough to a weekend. Check back later.',
                )
              else
                for (var i = 0; i < weekends.length && i < 8; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: StaggerIn(
                      index: i,
                      child: _Ticket(
                        weekend: weekends[i],
                        onTap: () {
                          planner.planWeekend(weekends[i]);
                          PrimaryScrollController.of(context).animateTo(
                            0,
                            duration: Motion.medium,
                            curve: Motion.calm,
                          );
                        },
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanResult extends StatelessWidget {
  const _PlanResult({required this.plan});
  final LeavePlan plan;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = context.read<AttendanceProvider>();
    if (plan.totalMissed == 0) {
      return Text(
        'No classes on those days. Go.',
        style: display(20, color: c.text, weight: 700),
      );
    }
    final rows = plan.rule == AttendanceRule.overall
        ? [plan.overall]
        : plan.subjects.where((i) => i.missed > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            PopIn(
              key: ValueKey('${plan.start}${plan.end}${plan.isSafe}'),
              child: Chunky(
                color: plan.isSafe ? Moment.lime : Moment.coral,
                radius: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Text(
                  plan.isSafe ? 'SAFE' : 'RISKY',
                  style: display(
                    22,
                    color: Moment.ink,
                  ).copyWith(letterSpacing: 1),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'You’d miss ${plan.totalMissed} ${plan.totalMissed == 1 ? 'class' : 'classes'}.',
                style: body(15, color: c.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final i in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    i.subjectId == null
                        ? 'Overall'
                        : a.subjects
                              .firstWhere((s) => s.id == i.subjectId)
                              .code,
                    overflow: TextOverflow.ellipsis,
                    style: display(17, color: c.text),
                  ),
                ),
                Text(
                  '${i.before.percentFloor}%',
                  style: body(15, color: c.muted),
                ),
                Icon(Icons.arrow_forward_rounded, size: 16, color: c.muted),
                Text(
                  ' ${i.after.percentFloor}%',
                  style: body(16, color: c.risk(i.after.risk), weight: 700),
                ),
                const Spacer(),
                Flexible(
                  flex: 3,
                  child: Text(
                    i.staysSafe
                        ? '−${i.missed}'
                        : i.extraNeeded == null
                        ? 'can’t recover'
                        : 'attend ${i.extraNeeded} extra',
                    textAlign: TextAlign.end,
                    style: body(
                      14,
                      color: i.staysSafe ? c.muted : c.danger,
                      weight: 600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.weekend, required this.onTap});
  final LongWeekend weekend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = context.read<AttendanceProvider>();
    String code(String id) =>
        a.subjects.where((s) => s.id == id).firstOrNull?.code ?? '?';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final cost = weekend.isFree
        ? 'No classes missed'
        : 'Skip ${weekend.skipDays.map((d) => days[d.weekday - 1]).join(' & ')} · '
              '${weekend.cost.entries.map((e) => '${code(e.key)} ${e.value}').join(', ')}';
    return Chunky(
      color: weekend.isFree ? Moment.lime : Moment.sun,
      radius: Radii.l,
      depth: 4,
      onTap: onTap,
      semanticLabel: '${weekend.length} days off. $cost. Open in planner',
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weekend.length} days off',
                  style: display(26, color: Moment.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${shortDate(weekend.start)} → ${shortDate(weekend.end)} · '
                  '${weekend.holidays.map((h) => h.name).join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(14, color: Moment.ink, weight: 500),
                ),
                const SizedBox(height: 6),
                Text(cost, style: body(14, color: Moment.ink, weight: 600)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 26),
        ],
      ),
    );
  }
}
