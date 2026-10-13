import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../models/settings.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/holiday_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../services/attendance_math.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/inputs.dart';
import '../../widgets/large_title.dart';
import '../../widgets/status.dart';
import '../../widgets/target_slider.dart';
import '../../widgets/pickers.dart';
import '../../widgets/dialogs.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.asTab = false});

  /// A tab in the home shell (no back button) rather than a pushed page.
  final bool asTab;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sp = context.watch<SettingsProvider>();
    final s = sp.settings;

    final page = LargeTitleScrollView(
      title: 'Settings',
      bottomPadding: asTab ? 120 : 48,
      leading: asTab ? null : const BackButton(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          sliver: SliverList.list(
            children: [
              const SectionLabel('ATTENDANCE RULE'),
              const _RuleCard(),
              const SizedBox(height: 26),
              const SectionLabel('CLASSES'),
              Group(
                children: [
                  _NavTile(
                    icon: Icons.view_week_outlined,
                    title: 'Timetable',
                    onTap: () => Navigator.pushNamed(context, Routes.timetable),
                  ),
                  _NavTile(
                    icon: Icons.beach_access_outlined,
                    title: 'Holidays',
                    onTap: () => Navigator.pushNamed(context, Routes.holidays),
                  ),
                  _NavTile(
                    icon: Icons.menu_book_outlined,
                    title: 'Breaks (exams, vacations)',
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.holidays,
                      arguments: 1,
                    ),
                  ),
                  SwitchRow(
                    secondary: Icon(Icons.weekend_outlined, color: c.text),
                    title: const Text('Classes on Sundays'),
                    value: s.sundayClasses,
                    onChanged: (v) =>
                        sp.update((x) => x.copyWith(sundayClasses: v)),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const SectionLabel('DAY-END REMINDER'),
              Group(
                children: [
                  SwitchRow(
                    secondary: Icon(
                      Icons.notifications_none_rounded,
                      color: c.text,
                    ),
                    title: const Text('Remind me'),
                    subtitle: const Text('Only on days with classes'),
                    value: s.reminderEnabled,
                    onChanged: (v) async {
                      if (v) {
                        await context
                            .read<NotificationService>()
                            .requestPermission();
                      }
                      await sp.update((x) => x.copyWith(reminderEnabled: v));
                    },
                  ),
                  if (s.reminderEnabled) ...[
                    ListTile(
                      leading: Icon(Icons.schedule_rounded, color: c.text),
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
                            (x) => x.copyWith(
                              reminderMinutes: t.hour * 60 + t.minute,
                            ),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: Icon(Icons.send_outlined, color: c.text),
                      title: const Text('Send a test'),
                      onTap: () async {
                        final n = context.read<NotificationService>();
                        await n.requestPermission();
                        await n.showTest();
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 26),
              const SectionLabel('APPEARANCE'),
              Group(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Row(
                      children: [
                        Icon(Icons.contrast_rounded, color: c.text),
                        const SizedBox(width: 16),
                        const Text('Theme'),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Segmented<ThemeMode>(
                                value: s.themeMode,
                                options: const [
                                  (ThemeMode.system, 'Auto'),
                                  (ThemeMode.light, 'Light'),
                                  (ThemeMode.dark, 'Dark'),
                                ],
                                onChanged: sp.setThemeMode,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
                    child: Row(
                      children: [
                        Icon(Icons.palette_outlined, color: c.text),
                        const SizedBox(width: 16),
                        const Expanded(child: Text('Accent')),
                        for (var i = 0; i < accentChoices.length; i++)
                          Semantics(
                            label: accentChoices[i].$1,
                            selected: i == s.accentIndex,
                            button: true,
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                sp.setAccent(i);
                              },
                              child: AnimatedScale(
                                scale: i == s.accentIndex ? 1.15 : 1,
                                duration: Motion.d(context, Motion.medium),
                                curve: Motion.pop,
                                child: Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? accentChoices[i].$3
                                        : accentChoices[i].$2,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: i == s.accentIndex
                                          ? c.text
                                          : Colors.transparent,
                                      width: 2.5,
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
              const SizedBox(height: 26),
              const SectionLabel('SEMESTER'),
              Group(
                children: [
                  ListTile(
                    leading: Icon(Icons.restart_alt_rounded, color: c.danger),
                    title: Text(
                      'Start a new semester',
                      style: body(16, color: c.danger, weight: 600),
                    ),
                    subtitle: const Text(
                      'Clears subjects, timetable and marks',
                    ),
                    onTap: () => _newSemester(context),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Center(
                child: Text(
                  'Skipper · Holidays via Google Calendar',
                  style: body(13, color: c.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return asTab ? page : Scaffold(body: page);
  }

  Future<void> _newSemester(BuildContext context) async {
    final ok = await confirm(
      context,
      title: 'Start a new semester?',
      message:
          'Subjects, timetable, marks and breaks are cleared. Your rule, target and theme stay.',
      confirmLabel: 'Start fresh',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await context.read<StorageService>().resetSemester();
    if (!context.mounted) return;
    context.read<TimetableProvider>().reload();
    context.read<HolidayProvider>().reload();
    context.read<AttendanceProvider>().reload();
    Navigator.of(context).popUntil((r) => r.isFirst);
    await context.read<SettingsProvider>().update(
      (s) => AppSettings(
        rule: s.rule,
        targetPercent: s.targetPercent,
        themeMode: s.themeMode,
        accentIndex: s.accentIndex,
        reminderEnabled: s.reminderEnabled,
        reminderMinutes: s.reminderMinutes,
        sundayClasses: s.sundayClasses,
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListTile(
      leading: Icon(icon, color: c.text),
      title: Text(title),
      trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
      onTap: onTap,
    );
  }
}

/// Rule + target, with a live preview of what changes.
class _RuleCard extends StatefulWidget {
  const _RuleCard();

  @override
  State<_RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<_RuleCard> {
  int? _dragging;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final sp = context.watch<SettingsProvider>();
    final a = context.watch<AttendanceProvider>();
    final target = _dragging ?? sp.target;

    String preview() {
      if (sp.rule == AttendanceRule.overall) {
        final o = a.overall;
        final s = AttendanceStats(
          attended: o.attended,
          conducted: o.conducted,
          target: target,
        );
        return s.hasClasses
            ? 'Overall at $target%: ${statusLabel(s).toLowerCase()}'
            : 'Applies once classes are marked';
      }
      var below = 0;
      for (final subject in a.subjects) {
        final st = a.statsFor(subject);
        final t = subject.targetOverride ?? target;
        if (st.hasClasses && 100 * st.attended < t * st.conducted) below++;
      }
      return below == 0
          ? 'At $target%: every subject is safe'
          : 'At $target%: ${plural(below, 'subject', 'subjects')} below';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
              const Text('Applies to'),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Segmented<AttendanceRule>(
                      value: sp.rule,
                      options: const [
                        (AttendanceRule.eachSubject, 'Each subject'),
                        (AttendanceRule.overall, 'Overall'),
                      ],
                      onChanged: sp.setRule,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Target'),
              const Spacer(),
              Text('$target%', style: display(26, color: c.text)),
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
          AnimatedSwitcher(
            duration: Motion.d(context, Motion.fast),
            child: Text(
              preview(),
              key: ValueKey(preview()),
              style: body(14, color: c.muted),
            ),
          ),
        ],
      ),
    );
  }
}
