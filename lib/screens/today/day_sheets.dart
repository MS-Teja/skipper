import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../models/day_record.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/inputs.dart';
import '../home_shell.dart';

Future<void> _sheet(
  BuildContext context,
  Widget Function(BuildContext) builder,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  // Scrolls when the keyboard (or large text) leaves too little room.
  builder: (context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.gutter,
      ),
      child: builder(context),
    ),
  ),
);

/// Long-press menu on a class card.
Future<void> showClassSheet(
  BuildContext context,
  DateTime day,
  ClassEntry entry,
) {
  final a = context.read<AttendanceProvider>();
  return _sheet(context, (context) {
    final c = AppColors.of(context);
    Widget action(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: color ?? c.text),
      title: Text(label, style: body(16, color: color ?? c.text, weight: 500)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(entry.subject.name, style: Theme.of(context).textTheme.titleLarge),
        Text(relativeDay(day), style: body(14, color: c.muted)),
        const SizedBox(height: 8),
        action(
          Icons.check_circle_outline_rounded,
          'All present',
          () => a.markAll(day, entry, PeriodMark.present),
        ),
        action(
          Icons.cancel_outlined,
          'All absent',
          () => a.markAll(day, entry, PeriodMark.absent),
        ),
        action(
          Icons.block_rounded,
          'Didn’t happen (doesn’t count)',
          () => a.markAll(day, entry, PeriodMark.cancelled),
        ),
        action(
          Icons.restart_alt_rounded,
          'Clear',
          () => a.markAll(day, entry, PeriodMark.unmarked),
        ),
        if (entry.extraPeriods > 0)
          action(
            Icons.remove_circle_outline_rounded,
            'Remove extra class',
            () => a.removeExtrasOn(day, entry.subject.id),
            color: c.danger,
          ),
        action(
          Icons.insights_rounded,
          'Open ${entry.subject.code}',
          () => Navigator.pushNamed(
            context,
            Routes.detail,
            arguments: entry.subject.id,
          ),
        ),
      ],
    );
  });
}

/// Marks the whole day as a holiday (a manual holiday).
Future<void> showHolidaySheet(BuildContext context, DateTime day) {
  final holidays = context.read<HolidayProvider>();
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: 'Holiday');
  return _sheet(context, (context) {
    return Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'No classes ${relativeDay(day).toLowerCase() == 'today' ? 'today' : 'on ${shortDate(day)}'}?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Every class that day stops counting.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What’s the occasion?',
            ),
            validator: (v) {
              final t = v?.trim() ?? '';
              if (t.isEmpty) return 'Give it a name';
              if (t.length > 40) return 'Keep it under 40 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              holidays.addManualHoliday(day, name.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Mark as holiday'),
          ),
        ],
      ),
    );
  });
}

/// Adds a make-up class on a date.
Future<void> showExtraClassSheet(BuildContext context, DateTime day) {
  final a = context.read<AttendanceProvider>();
  final subjects = a.subjects;
  String? picked = subjects.isEmpty ? null : subjects.first.id;
  var periods = 1;
  return _sheet(context, (context) {
    return StatefulBuilder(
      builder: (context, set) {
        final c = AppColors.of(context);
        final b = Theme.of(context).brightness;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Extra class · ${relativeDay(day)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (subjects.isEmpty)
              Text('Add a subject first.', style: body(15, color: c.muted))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in subjects)
                    ChoiceChip(
                      label: Text(s.code),
                      selected: picked == s.id,
                      onSelected: (_) => set(() => picked = s.id),
                      showCheckmark: false,
                      labelStyle: body(
                        15,
                        color: picked == s.id ? Moment.ink : c.text,
                        weight: 600,
                      ),
                      backgroundColor: c.surface,
                      selectedColor: subjectColor(
                        s.colorIndex,
                      ).hue(b).withValues(alpha: 0.35),
                      side: BorderSide(
                        color: picked == s.id
                            ? subjectColor(s.colorIndex).hue(b)
                            : c.line,
                      ),
                      shape: RoundedSuperellipseBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Periods', style: body(16, color: c.text, weight: 500)),
                const Spacer(),
                CountStepper(
                  value: periods,
                  min: 1,
                  max: 6,
                  label: 'Periods',
                  onChanged: (v) => set(() => periods = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: picked == null
                  ? null
                  : () {
                      a.addExtra(day, picked!, periods);
                      Navigator.pop(context);
                    },
              child: const Text('Add class'),
            ),
          ],
        );
      },
    );
  });
}
