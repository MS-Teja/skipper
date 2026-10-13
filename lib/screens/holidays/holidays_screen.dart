import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/holiday.dart';
import '../../providers/holiday_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/dates.dart';
import '../../widgets/chunky.dart';
import '../../widgets/inputs.dart';
import '../../widgets/motion.dart';
import '../../widgets/states.dart';
import '../../widgets/pickers.dart';
import '../home_shell.dart';
import '../today/day_sheets.dart';

const _months = [
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

class HolidaysScreen extends StatefulWidget {
  const HolidaysScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<HolidaysScreen> createState() => _HolidaysScreenState();
}

class _HolidaysScreenState extends State<HolidaysScreen> {
  late int _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    // First visit: fetch automatically (served from cache when possible).
    final h = context.read<HolidayProvider>();
    if (h.apiHolidays.isEmpty && h.fetchState == FetchState.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) h.fetch();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Holidays & breaks'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Segmented<int>(
              value: _tab,
              options: const [(0, 'Holidays'), (1, 'Breaks')],
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: Motion.d(context, Motion.medium),
        child: _tab == 0
            ? const _HolidaysTab(key: ValueKey(0))
            : const _BreaksTab(key: ValueKey(1)),
      ),
    );
  }
}

class _HolidaysTab extends StatefulWidget {
  const _HolidaysTab({super.key});

  @override
  State<_HolidaysTab> createState() => _HolidaysTabState();
}

class _HolidaysTabState extends State<_HolidaysTab> {
  bool _observances = false;

  Future<void> _addManual(BuildContext context) async {
    final d = await pickDate(
      context,
      first: addDays(today(), -365),
      last: addDays(today(), 365),
      initial: today(),
      title: 'Which day is off?',
      done: 'Next',
    );
    if (d != null && context.mounted) await showHolidaySheet(context, d);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final h = context.watch<HolidayProvider>();
    final settings = context.watch<SettingsProvider>();
    final from = addDays(settings.settings.trackingStart ?? today(), -7);
    final upcoming = h.holidays.where((x) => !x.date.isBefore(from)).toList();
    // Observances (festivals most colleges stay open for) hide behind a
    // toggle unless the student ticked one.
    final hidden = upcoming.where((x) => _isObservance(x) && !x.applied);
    final list = _observances
        ? upcoming
        : upcoming.where((x) => !hidden.contains(x)).toList();

    final children = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              'Tick the days your college is actually closed.',
              style: body(14, color: c.muted),
            ),
          ),
          const SizedBox(width: 10),
          RoundIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Refresh from the internet',
            onPressed: () => h.fetch(force: true),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ];

    if (h.fetchState == FetchState.loading) {
      children.add(
        Shimmer(
          child: Column(
            children: [
              for (var i = 0; i < 6; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const SkeletonBox(width: 24, height: 24, radius: 6),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(
                              width: 140.0 + (i * 23) % 80,
                              height: 14,
                            ),
                            const SizedBox(height: 8),
                            const SkeletonBox(width: 90, height: 11),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    } else if (h.fetchState == FetchState.error && h.apiHolidays.isEmpty) {
      children.add(
        EmptyState(
          art: Illustration.cloud,
          compact: true,
          title: 'Couldn’t fetch holidays',
          message: h.error?.message,
          action: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => h.fetch(force: true),
                child: const Text('Try again'),
              ),
              FilledButton(
                onPressed: () => _addManual(context),
                child: const Text('Add one by hand'),
              ),
            ],
          ),
        ),
      );
    } else if (list.isEmpty) {
      children.add(
        EmptyState(
          art: Illustration.calendar,
          compact: true,
          title: 'No holidays yet',
          message: 'Pull to refresh, or add your college’s holidays by hand.',
          action: FilledButton(
            onPressed: () => _addManual(context),
            child: const Text('Add a holiday'),
          ),
        ),
      );
    } else {
      if (h.fetchState == FetchState.error) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Showing saved holidays. ${h.error?.message ?? ''}',
              style: body(13, color: c.danger),
            ),
          ),
        );
      }
      int? month;
      final groups = <Widget>[];
      var rows = <Widget>[];
      void flush() {
        if (rows.isNotEmpty) {
          groups.add(Group(children: rows));
          rows = [];
        }
      }

      for (final x in list) {
        if (x.date.month != month) {
          flush();
          month = x.date.month;
          groups.add(
            Padding(
              padding: EdgeInsets.only(top: groups.isEmpty ? 0 : 20),
              child: SectionLabel(
                '${_months[x.date.month - 1].toUpperCase()} ${x.date.year}',
              ),
            ),
          );
        }
        rows.add(_HolidayRow(holiday: x));
      }
      flush();
      children.addAll(groups);
      children.add(const SizedBox(height: 16));
      children.add(
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => _addManual(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add a holiday'),
            ),
            if (_observances || hidden.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _observances = !_observances),
                child: Text(
                  _observances
                      ? 'Hide festivals'
                      : 'More festivals (${hidden.length})',
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => h.fetch(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Space.gutter, 12, Space.gutter, 40),
        children: children,
      ),
    );
  }
}

bool _isObservance(Holiday h) =>
    h.source == HolidaySource.api &&
    !(h.type ?? '').toLowerCase().contains('public');

/// A light, iOS-style row: tick circle, name, date. Much cheaper to build
/// than a CheckboxListTile, which matters when a long list first appears.
class _HolidayRow extends StatelessWidget {
  const _HolidayRow({required this.holiday});
  final Holiday holiday;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final h = context.read<HolidayProvider>();
    final manual = holiday.source == HolidaySource.manual;
    final on = manual || holiday.applied;
    final subtitle = manual
        ? '${shortDate(holiday.date)} · added by you'
        : '${shortDate(holiday.date)}${_isObservance(holiday) ? ' · festival' : ''}';

    final text = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(holiday.name, style: body(16, color: c.text, weight: 500)),
          const SizedBox(height: 2),
          Text(subtitle, style: body(13, color: c.muted)),
        ],
      ),
    );

    if (manual) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(Icons.push_pin_rounded, size: 20, color: c.accent),
            ),
            const SizedBox(width: 14),
            text,
            IconButton(
              tooltip: 'Remove',
              icon: Icon(Icons.close_rounded, color: c.muted, size: 20),
              onPressed: () {
                HapticFeedback.lightImpact();
                h.removeHoliday(holiday);
              },
            ),
          ],
        ),
      );
    }
    return CheckRow(
      title: holiday.name,
      subtitle: subtitle,
      value: on,
      onChanged: (v) => h.setApplied(holiday, v),
    );
  }
}

class _BreaksTab extends StatelessWidget {
  const _BreaksTab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final h = context.watch<HolidayProvider>();
    final breaks = h.breaks;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.gutter, 16, Space.gutter, 40),
      children: [
        Text(
          'Exams, vacations, anything with no regular classes. Days in a break don’t count and never show up as unmarked.',
          style: body(14, color: c.muted, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (breaks.isEmpty)
          const EmptyState(
            art: Illustration.books,
            compact: true,
            title: 'No breaks yet',
            message: 'Add your mid-sems when the dates are out.',
          )
        else
          Group(
            children: [
              for (final b in breaks)
                ListTile(
                  title: Text(
                    b.label,
                    style: body(16, color: c.text, weight: 600),
                  ),
                  subtitle: Text(
                    '${shortDate(b.start)} → ${shortDate(b.end)} · ${b.lengthInDays} days',
                  ),
                  onTap: () => showBreakSheet(context, existing: b),
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                    onPressed: () => h.deleteBreak(b.id),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Chunky(
          color: Moment.lime,
          onTap: () => showBreakSheet(context),
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              'Add a break',
              style: display(18, color: Moment.ink, weight: 700),
            ),
          ),
        ),
      ],
    );
  }
}

/// Add or edit a break: label + date range, no overlaps.
Future<void> showBreakSheet(BuildContext context, {BreakPeriod? existing}) {
  final h = context.read<HolidayProvider>();
  final form = GlobalKey<FormState>();
  final shake = ShakeController();
  final label = TextEditingController(text: existing?.label ?? '');
  DateTimeRange? range = existing == null
      ? null
      : DateTimeRange(start: existing.start, end: existing.end);
  String? rangeError;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => StatefulBuilder(
      builder: (context, set) {
        final c = AppColors.of(context);
        Future<void> save() async {
          final valid = form.currentState!.validate();
          String? err;
          if (range == null) {
            err = 'Pick the dates';
          } else {
            final candidate = BreakPeriod(
              id: existing?.id ?? TimetableProvider.newId(),
              label: label.text.trim(),
              start: range!.start,
              end: range!.end,
            );
            if (h.breakOverlaps(candidate)) err = 'Overlaps another break';
            if (valid && err == null) {
              await h.saveBreak(candidate);
              if (context.mounted) Navigator.pop(context);
              return;
            }
          }
          set(() => rangeError = err);
          shake.shake();
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            MediaQuery.viewInsetsOf(context).bottom + Space.gutter,
          ),
          child: Form(
            key: form,
            child: Shake(
              controller: shake,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'New break' : 'Edit break',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: label,
                    autofocus: existing == null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Mid-sem exams',
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Give it a name';
                      if (t.length > 30) return 'Keep it under 30 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: rangeError != null ? c.danger : c.line,
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onPressed: () async {
                      final r = await pickDateRange(
                        context,
                        first: addDays(today(), -365),
                        last: addDays(today(), 365),
                        initial: range,
                        title: 'Break dates',
                      );
                      if (r != null) {
                        set(() {
                          range = r;
                          rangeError = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range_rounded),
                    label: Text(
                      range == null
                          ? 'Pick dates'
                          : '${shortDate(range!.start)} → ${shortDate(range!.end)}',
                    ),
                  ),
                  if (rangeError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 16),
                      child: Text(
                        rangeError!,
                        style: body(13, color: c.danger, weight: 500),
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: save,
                    child: const Text('Save break'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
