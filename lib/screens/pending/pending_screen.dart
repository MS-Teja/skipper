import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/day_record.dart';
import '../../providers/attendance_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/inputs.dart';
import '../../widgets/large_title.dart';
import '../../widgets/motion.dart';
import '../../widgets/states.dart';
import '../../widgets/swipe_mark.dart';
import '../home_shell.dart';

/// Past days with unmarked periods.
class PendingScreen extends StatelessWidget {
  const PendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = Theme.of(context).brightness;
    final a = context.watch<AttendanceProvider>();
    final days = a.pendingDays;

    return Scaffold(
      appBar: days.isEmpty ? AppBar(title: const Text('Not marked yet')) : null,
      body: days.isEmpty
          ? Center(
              child: PopIn(
                child: EmptyState(
                  art: Illustration.party,
                  title: 'All caught up',
                  message: 'Every past class is marked.',
                  action: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back'),
                  ),
                ),
              ),
            )
          : LargeTitleScrollView(
              title: 'Not marked yet',
              leading: const BackButton(),
              bottomPadding: 40,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  sliver: SliverList.builder(
                    itemCount: days.length,
                    itemBuilder: (context, i) {
                      final day = days[i];
                      final entries = a
                          .classesOn(day.date)
                          .where((e) => !e.fullyMarked)
                          .toList();
                      return StaggerIn(
                        key: ValueKey(day.date),
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SectionLabel(
                                relativeDay(day.date).toUpperCase(),
                                trailing: TextButton(
                                  onPressed: () => a.fillUnmarked(
                                    day.date,
                                    PeriodMark.present,
                                  ),
                                  child: const Text('All present'),
                                ),
                              ),
                              Group(
                                children: [
                                  for (final e in entries)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        2,
                                        8,
                                        2,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: subjectColor(
                                                e.subject.colorIndex,
                                              ).hue(b),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              e.subject.code,
                                              style: display(18, color: c.text),
                                            ),
                                          ),
                                          Wrap(
                                            children: [
                                              for (
                                                var p = 0;
                                                p < e.marks.length;
                                                p++
                                              )
                                                PeriodDot(
                                                  index: p,
                                                  mark: e.marks[p],
                                                  onTap: () => a.cycleMark(
                                                    day.date,
                                                    e,
                                                    p,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
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
