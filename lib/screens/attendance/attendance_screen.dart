import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../models/settings.dart';
import '../../models/subject.dart';
import '../../providers/attendance_provider.dart';
import '../../services/attendance_math.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/chunky.dart';
import '../../widgets/inputs.dart';
import '../../widgets/large_title.dart';
import '../../widgets/motion.dart';
import '../../widgets/ring.dart';
import '../../widgets/states.dart';
import '../../widgets/status.dart';

enum _Sort { risk, az }

/// Overall attendance plus every subject, sorted by risk.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  _Sort _sort = _Sort.risk;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final a = context.watch<AttendanceProvider>();
    final stats = a.allStats;
    final subjects = [...a.subjects];
    if (_sort == _Sort.risk) {
      // Furthest below target first; subjects with no classes last.
      double key(Subject s) {
        final st = stats[s.id]!;
        return st.hasClasses ? st.ratio - st.target / 100 : 9;
      }

      subjects.sort((x, y) => key(x).compareTo(key(y)));
    } else {
      subjects.sort(
        (x, y) => x.name.toLowerCase().compareTo(y.name.toLowerCase()),
      );
    }
    final allSafe =
        a.rule == AttendanceRule.eachSubject &&
        subjects.isNotEmpty &&
        a.atRisk.isEmpty;

    return LargeTitleScrollView(
      title: 'Attendance',
      trailing: RoundIconButton(
        icon: Icons.add_rounded,
        tooltip: 'Add subject',
        onPressed: () => Navigator.pushNamed(context, Routes.subjectForm),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.list(
            children: [
              if (subjects.isEmpty)
                EmptyState(
                  art: Illustration.books,
                  title: 'No subjects yet',
                  message:
                      'Add the subjects on your timetable to start tracking.',
                  action: FilledButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.subjectForm),
                    child: const Text('Add a subject'),
                  ),
                )
              else ...[
                StaggerIn(
                  index: 0,
                  child: _OverallCard(stats: a.overall, rule: a.rule),
                ),
                const SizedBox(height: 28),
                SectionTitle(
                  'Subjects',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (allSafe) ...[
                        PopIn(
                          child: Pill(
                            'All safe',
                            background: Moment.lime,
                            foreground: Moment.ink,
                            dense: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Segmented<_Sort>(
                        value: _sort,
                        options: const [
                          (_Sort.risk, 'By risk'),
                          (_Sort.az, 'A–Z'),
                        ],
                        onChanged: (v) => setState(() => _sort = v),
                      ),
                    ],
                  ),
                ),
                // Clip with the native superellipse clip: a squircle-shaped Material clip
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
                        for (var i = 0; i < subjects.length; i++) ...[
                          if (i > 0)
                            Divider(height: 1, indent: 66, color: c.line),
                          StaggerIn(
                            key: ValueKey(subjects[i].id),
                            index: i + 1,
                            child: _SubjectRow(
                              subject: subjects[i],
                              stats: stats[subjects[i].id]!,
                              rule: a.rule,
                              index: i,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.stats, required this.rule});
  final AttendanceStats stats;
  final AttendanceRule rule;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Pressable(
      onTap: () => Navigator.pushNamed(context, Routes.detail),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: ShapeDecoration(
          color: c.surface,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(Radii.xl),
            side: BorderSide(color: c.line),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall', style: body(15, color: c.muted, weight: 500)),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: stats.hasClasses
                        ? RollingNumber(
                            stats.percentFloor,
                            style: display(60, color: c.text, height: 0.9),
                            suffix: '%',
                            suffixStyle: display(26, color: c.muted),
                          )
                        : Text(
                            '–',
                            style: display(60, color: c.text, height: 0.9),
                          ),
                  ),
                  const SizedBox(height: 10),
                  if (rule == AttendanceRule.overall)
                    StatusPill(stats)
                  else
                    Text(
                      '${stats.attended} of ${stats.conducted} classes',
                      style: body(14, color: c.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AttendanceRing(
              ratio: stats.ratio,
              color: c.risk(stats.risk),
              track: c.track,
              size: 96,
              stroke: 11,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ring, name over a one-line verdict, then the % and a chevron.
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.subject,
    required this.stats,
    required this.rule,
    required this.index,
  });
  final Subject subject;
  final AttendanceStats stats;
  final AttendanceRule rule;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = Theme.of(context).brightness;
    final eachSubject = rule == AttendanceRule.eachSubject;
    final atRisk = eachSubject && stats.hasClasses && !stats.isAtOrAboveTarget;
    return InkWell(
      onTap: () =>
          Navigator.pushNamed(context, Routes.detail, arguments: subject.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
        child: Row(
          children: [
            AttendanceRing(
              ratio: stats.ratio,
              color: eachSubject
                  ? c.risk(stats.risk)
                  : subjectColor(subject.colorIndex).hue(b),
              track: c.track,
              size: 36,
              stroke: 5,
              delay: Duration(milliseconds: 50 * index),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(16, color: c.text, weight: 600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    eachSubject
                        ? statusLine(stats)
                        : '${stats.attended} of ${stats.conducted} classes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(
                      14,
                      color: atRisk ? c.danger : c.muted,
                      weight: atRisk ? 600 : 400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(percentText(stats), style: display(21, color: c.text)),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded, color: c.muted, size: 22),
          ],
        ),
      ),
    );
  }
}
