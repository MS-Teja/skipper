import 'package:animations/animations.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../models/settings.dart';
import '../../models/subject.dart';
import '../../models/timetable.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../services/demo_data.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../widgets/chunky.dart';
import '../../widgets/inputs.dart';
import '../../widgets/motion.dart';
import '../../widgets/target_slider.dart';
import '../../widgets/pickers.dart';
import '../subjects/subject_form_screen.dart';
import '../timetable/timetable_editor.dart';

/// Six steps: welcome → rule → subjects → timetable → starting numbers → finish.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _steps = 6;
  int _step = 0;
  bool _forward = true;
  Map<int, List<Slot>> _days = {};
  final _baselineForm = GlobalKey<FormState>();
  final _baselines = <String, (TextEditingController, TextEditingController)>{};
  final _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1200),
  );
  bool _finishing = false;

  @override
  void dispose() {
    _confetti.dispose();
    for (final (a, b) in _baselines.values) {
      a.dispose();
      b.dispose();
    }
    super.dispose();
  }

  void _go(int step) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  bool _canContinue(List<Subject> subjects) => switch (_step) {
    2 => subjects.isNotEmpty,
    3 => _days.values.any((s) => s.isNotEmpty),
    _ => true,
  };

  Future<void> _next() async {
    if (_step == 4 && !(_baselineForm.currentState?.validate() ?? true)) return;
    if (_step < _steps - 1) {
      _go(_step + 1);
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final timetable = context.read<TimetableProvider>();
    final settings = context.read<SettingsProvider>();
    final holidays = context.read<HolidayProvider>();
    final notifications = context.read<NotificationService>();
    final start = today();

    for (final s in timetable.subjects) {
      final (a, c) = _baselines[s.id] ?? (null, null);
      final attended = int.tryParse(a?.text.trim() ?? '') ?? 0;
      final held = int.tryParse(c?.text.trim() ?? '') ?? 0;
      if (held > 0) {
        await timetable.saveSubject(
          s.copyWith(baselineAttended: attended, baselineConducted: held),
        );
      }
    }
    await timetable.saveTimetable(_days, from: start);
    if (settings.settings.reminderEnabled) {
      await notifications.requestPermission();
    }
    if (!mounted) return;
    if (!Motion.reduced(context)) _confetti.play();
    HapticFeedback.heavyImpact();
    await Future.delayed(
      Duration(milliseconds: Motion.reduced(context) ? 0 : 900),
    );
    await settings.update(
      (s) => s.copyWith(onboarded: true, trackingStart: start),
    );
    holidays.fetch();
  }

  Future<void> _demo() async {
    final storage = context.read<StorageService>();
    final settings = context.read<SettingsProvider>();
    final timetable = context.read<TimetableProvider>();
    final holidays = context.read<HolidayProvider>();
    final attendance = context.read<AttendanceProvider>();
    await seedDemoSemester(storage, settings.settings);
    timetable.reload();
    holidays.reload();
    attendance.reload();
    await settings.update((_) => storage.loadSettings());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final subjects = context.watch<TimetableProvider>().subjects;
    final pages = [
      _Welcome(onStart: () => _go(1), onDemo: _demo),
      const _RuleStep(),
      _SubjectsStep(subjects: subjects),
      _TimetableStep(
        days: _days,
        subjects: subjects,
        onChanged: (d) => setState(() => _days = d),
      ),
      _BaselineStep(
        formKey: _baselineForm,
        subjects: subjects,
        controllers: _baselines,
      ),
      const _FinishStep(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                if (_step > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, Space.gutter, 0),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => _go(_step - 1),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        ),
                        const SizedBox(width: 4),
                        for (var i = 1; i < _steps; i++)
                          Expanded(
                            child: AnimatedContainer(
                              duration: Motion.d(context, Motion.medium),
                              curve: Motion.bounce,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              height: 6,
                              decoration: BoxDecoration(
                                color: i <= _step ? c.inverse : c.track,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: PageTransitionSwitcher(
                    duration: Motion.d(
                      context,
                      const Duration(milliseconds: 420),
                    ),
                    reverse: !_forward,
                    transitionBuilder: (child, a, b) => SharedAxisTransition(
                      animation: a,
                      secondaryAnimation: b,
                      transitionType: SharedAxisTransitionType.horizontal,
                      fillColor: c.bg,
                      child: child,
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: pages[_step],
                    ),
                  ),
                ),
                if (_step > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.gutter,
                      8,
                      Space.gutter,
                      16,
                    ),
                    child: Row(
                      children: [
                        if (_step == 4)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: TextButton(
                              onPressed: () => _go(5),
                              child: const Text('Fresh start'),
                            ),
                          ),
                        Expanded(
                          child: AnimatedOpacity(
                            opacity: _canContinue(subjects) ? 1 : 0.4,
                            duration: Motion.d(context, Motion.fast),
                            child: Chunky(
                              color: _step == _steps - 1
                                  ? Moment.lime
                                  : c.surface,
                              onTap: _canContinue(subjects) ? _next : null,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              child: Center(
                                child: Text(
                                  _step == _steps - 1 ? 'Let’s go' : 'Continue',
                                  style:
                                      display(
                                        19,
                                        color: Moment.ink,
                                        weight: 700,
                                      ).copyWith(
                                        color: _step == _steps - 1
                                            ? Moment.ink
                                            : c.text,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 40,
              colors: [Moment.lime, Moment.coral, Moment.sun, c.accent],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    this.subtitle,
    required this.children,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 24, Space.gutter, 24),
      children: [
        Text(title, style: display(36, color: c.text, height: 1.05)),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(subtitle!, style: body(16, color: c.muted, height: 1.4)),
        ],
        const SizedBox(height: 26),
        ...children,
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart, required this.onDemo});
  final VoidCallback onStart;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    // Fills the screen when it fits; scrolls on small phones with large text.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 40, Space.gutter, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 64),
          child: IntrinsicHeight(child: _content(context)),
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PopIn(
          child: Chunky(
            color: Moment.lime,
            radius: 999,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Text(
              'Smile and wave.',
              style: display(15, color: Moment.ink, weight: 700),
            ),
          ),
        ),
        const Spacer(),
        const SizedBox(height: 24),
        // Never breaks mid-word: shrinks to the width instead.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'Kowalski,\nanalysis.',
            style: display(64, color: c.text, height: 0.92),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Skipper runs the numbers on your attendance. Know exactly how many classes you can skip, and the moment you need to show up.',
          style: body(18, color: c.muted, height: 1.4),
        ),
        const Spacer(),
        const SizedBox(height: 24),
        Chunky(
          color: Moment.lime,
          onTap: onStart,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'Set up in a minute',
              style: display(20, color: Moment.ink, weight: 700),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: onDemo,
            child: const Text('Explore with a sample semester'),
          ),
        ),
      ],
    );
  }
}

class _RuleStep extends StatelessWidget {
  const _RuleStep();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sp = context.watch<SettingsProvider>();
    Widget option(AttendanceRule rule, String title, String text) {
      final selected = sp.rule == rule;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Pressable(
          onTap: () => sp.setRule(rule),
          child: AnimatedContainer(
            duration: Motion.d(context, Motion.medium),
            padding: const EdgeInsets.all(18),
            decoration: ShapeDecoration(
              color: selected ? c.inverse : c.surface,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(Radii.l),
                side: BorderSide(color: selected ? c.inverse : c.line),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: body(
                          17,
                          color: selected ? c.onInverse : c.text,
                          weight: 600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: body(
                          14,
                          color: selected
                              ? c.onInverse.withValues(alpha: 0.75)
                              : c.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: Motion.d(context, Motion.medium),
                  curve: Motion.pop,
                  child: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Moment.lime,
                    child: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Moment.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _StepScaffold(
      title: 'How does your college count?',
      children: [
        option(
          AttendanceRule.eachSubject,
          'Each subject separately',
          'You need the target in every subject.',
        ),
        option(
          AttendanceRule.overall,
          'Overall',
          'Only the total across all subjects matters.',
        ),
        const SizedBox(height: 16),
        const _TargetPicker(),
      ],
    );
  }
}

/// Target % with a live number while dragging; saved once on release.
class _TargetPicker extends StatefulWidget {
  const _TargetPicker();

  @override
  State<_TargetPicker> createState() => _TargetPickerState();
}

class _TargetPickerState extends State<_TargetPicker> {
  int? _dragging;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sp = context.watch<SettingsProvider>();
    final target = _dragging ?? sp.target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Target', style: body(17, color: c.text, weight: 600)),
            const Spacer(),
            Text('$target%', style: display(34, color: c.text)),
          ],
        ),
        TargetSlider(
          value: sp.target,
          onChanged: (v) => setState(() => _dragging = v),
          onChangeEnd: (v) {
            setState(() => _dragging = null);
            sp.setTarget(v);
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final t in [65, 70, 75, 80, 85])
              ChoiceChip(
                label: Text('$t%'),
                selected: target == t,
                onSelected: (_) {
                  HapticFeedback.selectionClick();
                  sp.setTarget(t);
                },
                showCheckmark: false,
              ),
          ],
        ),
      ],
    );
  }
}

class _SubjectsStep extends StatelessWidget {
  const _SubjectsStep({required this.subjects});
  final List<Subject> subjects;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = Theme.of(context).brightness;
    return _StepScaffold(
      title: 'What are you studying?',
      subtitle: 'Add every subject and lab on your timetable.',
      children: [
        if (subjects.isNotEmpty) ...[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in subjects)
                PopIn(
                  key: ValueKey(s.id),
                  child: Pressable(
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.subjectForm,
                      arguments: s.id,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: ShapeDecoration(
                        color: subjectColor(s.colorIndex).fill(b),
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(Radii.m),
                          side: BorderSide(
                            color: subjectColor(s.colorIndex).border(b),
                          ),
                        ),
                      ),
                      child: Text(s.code, style: display(20, color: c.text)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SubjectFormScreen()),
          ),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            subjects.isEmpty ? 'Add your first subject' : 'Add another',
          ),
        ),
      ],
    );
  }
}

class _TimetableStep extends StatelessWidget {
  const _TimetableStep({
    required this.days,
    required this.subjects,
    required this.onChanged,
  });
  final Map<int, List<Slot>> days;
  final List<Subject> subjects;
  final ValueChanged<Map<int, List<Slot>>> onChanged;

  @override
  Widget build(BuildContext context) {
    final sunday = context.watch<SettingsProvider>().settings.sundayClasses;
    return _StepScaffold(
      title: 'Your week',
      subtitle:
          'For each day, add the subjects and how many periods. Labs are just more periods.',
      children: [
        TimetableEditor(
          days: days,
          subjects: subjects,
          sunday: sunday,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _BaselineStep extends StatelessWidget {
  const _BaselineStep({
    required this.formKey,
    required this.subjects,
    required this.controllers,
  });
  final GlobalKey<FormState> formKey;
  final List<Subject> subjects;
  final Map<String, (TextEditingController, TextEditingController)> controllers;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Form(
      key: formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: _StepScaffold(
        title: 'Already mid-semester?',
        subtitle:
            'Copy your numbers from the college portal so the maths starts right. Skip if the semester just began.',
        children: [
          for (final s in subjects)
            Builder(
              builder: (context) {
                final (a, h) = controllers.putIfAbsent(
                  s.id,
                  () => (TextEditingController(), TextEditingController()),
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 82,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            s.code,
                            overflow: TextOverflow.ellipsis,
                            style: display(20, color: c.text),
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: a,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Attended',
                          ),
                          validator: (v) =>
                              SubjectValidators.count(v) ??
                              SubjectValidators.attendedVsConducted(v, h.text),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: h,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(labelText: 'Held'),
                          validator: SubjectValidators.count,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FinishStep extends StatelessWidget {
  const _FinishStep();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sp = context.watch<SettingsProvider>();
    final s = sp.settings;
    return _StepScaffold(
      title: 'Last bits',
      subtitle: 'The reminder only pings on days with classes.',
      children: [
        Group(
          children: [
            SwitchRow(
              title: const Text('Day-end reminder'),
              value: s.reminderEnabled,
              onChanged: (v) =>
                  sp.update((x) => x.copyWith(reminderEnabled: v)),
            ),
            if (s.reminderEnabled)
              ListTile(
                title: const Text('Time'),
                trailing: Text(
                  s.reminderTime.format(context),
                  style: body(16, color: c.accent, weight: 600),
                ),
                onTap: () async {
                  final t = await pickTime(
                    context,
                    initial: s.reminderTime,
                    title: 'Remind me at',
                  );
                  if (t != null) {
                    await sp.update(
                      (x) =>
                          x.copyWith(reminderMinutes: t.hour * 60 + t.minute),
                    );
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}
