import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/subject.dart';
import '../../models/timetable.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/inputs.dart';
import '../../widgets/motion.dart';
import '../../widgets/status.dart';

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLong = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Weekly timetable without timings: per day, subjects × periods.
/// Tap a subject chip to add it, use −/+ for periods (0 removes it).
class TimetableEditor extends StatefulWidget {
  const TimetableEditor({
    super.key,
    required this.days,
    required this.subjects,
    required this.onChanged,
    this.sunday = false,
  });

  final Map<int, List<Slot>> days;
  final List<Subject> subjects;
  final ValueChanged<Map<int, List<Slot>>> onChanged;
  final bool sunday;

  @override
  State<TimetableEditor> createState() => _TimetableEditorState();
}

class _TimetableEditorState extends State<TimetableEditor> {
  int _day = DateTime.monday;

  List<Slot> get _slots => widget.days[_day] ?? const [];

  void _set(int day, List<Slot> slots) {
    widget.onChanged({...widget.days, day: slots});
  }

  void _add(Subject s) {
    HapticFeedback.lightImpact();
    _set(_day, [..._slots, Slot(subjectId: s.id, periods: 1)]);
  }

  void _setPeriods(int index, int periods) {
    final next = [..._slots];
    if (periods == 0) {
      next.removeAt(index);
    } else {
      next[index] = next[index].withPeriods(periods);
    }
    _set(_day, next);
  }

  Future<void> _copy() async {
    final days = widget.sunday ? 7 : 6;
    final picked = <int>{};
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.gutter,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle('Copy ${weekdayLong[_day - 1]} to'),
              Group(
                children: [
                  for (var d = 1; d <= days; d++)
                    if (d != _day)
                      CheckRow(
                        title: weekdayLong[d - 1],
                        subtitle: _periods(d) == 0
                            ? 'Off day'
                            : '${_periods(d)} periods now · will be replaced',
                        value: picked.contains(d),
                        onChanged: (v) =>
                            set(() => v ? picked.add(d) : picked.remove(d)),
                      ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: picked.isEmpty
                    ? null
                    : () => Navigator.pop(context, true),
                child: Text(
                  picked.isEmpty
                      ? 'Copy'
                      : 'Copy to ${plural(picked.length, 'day', 'days')}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    HapticFeedback.mediumImpact();
    widget.onChanged({
      ...widget.days,
      for (final d in picked) d: [..._slots],
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final b = Theme.of(context).brightness;
    final days = widget.sunday ? 7 : 6;
    final used = _slots.map((s) => s.subjectId).toSet();
    final available = widget.subjects
        .where((s) => !used.contains(s.id))
        .toList();
    Subject? byId(String id) =>
        widget.subjects.where((s) => s.id == id).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Same shape as Today's week strip: day, then a circle with how many
        // periods that day has (filled when selected).
        Row(
          children: [
            for (var d = 1; d <= days; d++)
              Expanded(
                child: Semantics(
                  selected: d == _day,
                  button: true,
                  label: '${weekdayLong[d - 1]}, ${_periods(d)} periods',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (d == _day) return;
                      HapticFeedback.selectionClick();
                      setState(() => _day = d);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekdayShort[d - 1],
                            style: body(12, color: c.muted, weight: 500),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: Motion.d(context, Motion.medium),
                            curve: Motion.spring,
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: d == _day
                                  ? c.inverse
                                  : (_periods(d) == 0
                                        ? Colors.transparent
                                        : c.surface),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: d == _day ? c.inverse : c.line,
                              ),
                            ),
                            child: Text(
                              _periods(d) == 0 ? '–' : '${_periods(d)}',
                              style: body(
                                16,
                                color: d == _day ? c.onInverse : c.text,
                                weight: d == _day ? 700 : 500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 26),
        SectionTitle(
          weekdayLong[_day - 1],
          trailing: _slots.isEmpty
              ? null
              : TextButton(onPressed: _copy, child: const Text('Copy to…')),
        ),
        AnimatedSize(
          duration: Motion.d(context, Motion.medium),
          curve: Motion.spring,
          alignment: Alignment.topCenter,
          child: _slots.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 22,
                    horizontal: 16,
                  ),
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(Radii.l),
                      side: BorderSide(color: c.line),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'No classes',
                        style: body(16, color: c.text, weight: 600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Counts as an off day.',
                        textAlign: TextAlign.center,
                        style: body(14, color: c.muted),
                      ),
                    ],
                  ),
                )
              : Group(
                  children: [
                    for (var i = 0; i < _slots.length; i++)
                      Builder(
                        builder: (context) {
                          final s = byId(_slots[i].subjectId);
                          if (s == null) return const SizedBox.shrink();
                          return Padding(
                            key: ValueKey('${_day}_${s.id}'),
                            padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: subjectColor(s.colorIndex).hue(b),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.code,
                                        style: display(18, color: c.text),
                                      ),
                                      Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: body(13, color: c.muted),
                                      ),
                                    ],
                                  ),
                                ),
                                CountStepper(
                                  value: _slots[i].periods,
                                  min: 0,
                                  max: 8,
                                  label: '${s.code} periods',
                                  onChanged: (v) => _setPeriods(i, v),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
        ),
        if (available.isNotEmpty) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Add to ${weekdayLong[_day - 1]}',
              style: body(14, color: c.muted, weight: 500),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in available)
                PopIn(
                  key: ValueKey('chip${s.id}$_day'),
                  rotate: 0,
                  child: Pressable(
                    onTap: () => _add(s),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                      decoration: ShapeDecoration(
                        color: subjectColor(s.colorIndex).fill(b),
                        shape: RoundedSuperellipseBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: subjectColor(s.colorIndex).border(b),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, size: 18, color: c.text),
                          const SizedBox(width: 4),
                          Text(
                            s.code,
                            style: body(15, color: c.text, weight: 600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  int _periods(int day) =>
      (widget.days[day] ?? const []).fold(0, (n, s) => n + s.periods);
}
