import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../models/timetable.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../home_shell.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/large_title.dart';
import '../../widgets/pickers.dart';
import 'timetable_editor.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late Map<int, List<Slot>> _days = Map.of(
    context.read<TimetableProvider>().current?.days ?? const {},
  );
  bool _dirty = false;

  Future<void> _save() async {
    final settings = context.read<SettingsProvider>().settings;
    final start = settings.trackingStart ?? today();
    var from = today().isBefore(start) ? start : today();
    if (today().isAfter(start)) {
      // Mid-semester change: past days keep the old timetable.
      final choice = await chooseAction(
        context,
        title: 'Use the new timetable from',
        actions: const [('Today', false), ('Pick a date…', true)],
      );
      if (choice == null || !mounted) return;
      final picked = choice
          ? await pickDate(
              context,
              first: start,
              last: addDays(today(), 365),
              initial: today(),
              title: 'New timetable from',
            )
          : today();
      if (picked == null) return;
      from = picked;
    }
    if (!mounted) return;
    await context.read<TimetableProvider>().saveTimetable(_days, from: from);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Timetable saved from ${relativeDay(from).toLowerCase()}',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = context.watch<TimetableProvider>().subjects;
    final sunday = context.watch<SettingsProvider>().settings.sundayClasses;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(
          context,
          title: 'Discard changes?',
          message: 'Your edits to the timetable won’t be saved.',
          cancelLabel: 'Keep editing',
          confirmLabel: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        body: LargeTitleScrollView(
          overline: 'Same every week',
          title: 'Timetable',
          leading: const BackButton(),
          bottomPadding: 40,
          trailing: TextButton(
            onPressed: _dirty ? _save : null,
            child: Text('Save', style: body(17, weight: 600)),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: SliverList.list(
                children: [
                  TimetableEditor(
                    days: _days,
                    subjects: subjects,
                    sunday: sunday,
                    onChanged: (d) => setState(() {
                      _days = d;
                      _dirty = true;
                    }),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, Routes.subjectForm),
                      child: const Text('New subject'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
