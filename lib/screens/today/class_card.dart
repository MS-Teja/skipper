import 'package:flutter/material.dart';

import '../../models/settings.dart';
import '../../providers/attendance_provider.dart';
import '../../services/attendance_math.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/chunky.dart';
import '../../widgets/status.dart';
import '../../widgets/swipe_mark.dart';

/// Today's card for one subject: code and % on top, period dots and the
/// verdict below. Tinted with the subject's colour.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.entry,
    required this.stats,
    required this.rule,
    required this.onDot,
    required this.onLongPress,
    this.enabled = true,
  });

  final ClassEntry entry;
  final AttendanceStats stats;
  final AttendanceRule rule;
  final ValueChanged<int> onDot;
  final VoidCallback onLongPress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = Theme.of(context).brightness;
    final color = subjectColor(entry.subject.colorIndex);

    return Semantics(
      label:
          '${entry.subject.name}, ${percentText(stats)}, ${statusLabel(stats)}. '
          'Swipe right for present, left for absent. Long press for more.',
      child: GestureDetector(
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: Motion.d(context, Motion.medium),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          decoration: ShapeDecoration(
            color: color.fill(b),
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(Radii.l),
              side: BorderSide(color: color.border(b)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.subject.code,
                            style: display(26, color: c.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.extraPeriods > 0) ...[
                          const SizedBox(width: 8),
                          Pill(
                            '+${entry.extraPeriods} extra',
                            background: c.surface,
                            foreground: c.muted,
                            dense: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(percentText(stats), style: display(28, color: c.text)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Transform.translate(
                      offset: const Offset(-7, 0),
                      child: Wrap(
                        children: [
                          for (var i = 0; i < entry.marks.length; i++)
                            PeriodDot(
                              index: i,
                              mark: entry.marks[i],
                              enabled: enabled,
                              onTap: () => onDot(i),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (rule == AttendanceRule.eachSubject)
                    StatusPill(stats)
                  else
                    Text(
                      '${stats.attended}/${stats.conducted}',
                      style: body(14, color: c.muted, weight: 500),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
