import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../utils/dates.dart';

/// iOS-style wheel pickers in a sheet: Cancel · title · Done, then the wheel.
/// They replace Material's full-screen date, time and range dialogs.

Future<T?> _wheelSheet<T>(
  BuildContext context, {
  required String title,
  required String done,
  required T Function() result,
  required Widget Function(BuildContext, StateSetter) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    // Sized to content (the default caps sheets at 9/16 of the screen),
    // scrolling on small phones with large text.
    isScrollControlled: true,
    builder: (context) {
      final c = AppColors.of(context);
      final dark = Theme.of(context).brightness == Brightness.dark;
      return CupertinoTheme(
        data: CupertinoThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          primaryColor: c.accent,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: body(21, color: c.text),
          ),
        ),
        child: StatefulBuilder(
          builder: (context, set) => SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: body(16, color: c.accent)),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(16, color: c.text, weight: 600),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context, result());
                        },
                        child: Text(
                          done,
                          style: body(16, color: c.accent, weight: 700),
                        ),
                      ),
                    ],
                  ),
                  builder(context, set),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _wheel(Widget picker) => SizedBox(height: 216, child: picker);

/// A single date.
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String title = 'Pick a date',
  String done = 'Done',
}) {
  first = dayOnly(first);
  last = dayOnly(last);
  var value = _clamp(dayOnly(initial), first, last);
  return _wheelSheet(
    context,
    title: title,
    done: done,
    result: () => value,
    builder: (context, _) => _wheel(
      CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: value,
        minimumDate: first,
        maximumDate: last,
        onDateTimeChanged: (d) => value = dayOnly(d),
      ),
    ),
  );
}

/// A time of day (respects the phone's 24-hour setting).
Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required TimeOfDay initial,
  String title = 'Time',
}) {
  final now = DateTime.now();
  var value = DateTime(
    now.year,
    now.month,
    now.day,
    initial.hour,
    initial.minute,
  );
  return _wheelSheet(
    context,
    title: title,
    done: 'Done',
    result: () => TimeOfDay(hour: value.hour, minute: value.minute),
    builder: (context, _) => _wheel(
      CupertinoDatePicker(
        mode: CupertinoDatePickerMode.time,
        initialDateTime: value,
        minuteInterval: 1,
        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
        onDateTimeChanged: (d) => value = d,
      ),
    ),
  );
}

/// A start and end date, edited one at a time on the same wheel (like the
/// iOS Calendar event editor). The end never falls before the start.
Future<DateTimeRange?> pickDateRange(
  BuildContext context, {
  required DateTime first,
  required DateTime last,
  DateTimeRange? initial,
  String title = 'Dates',
  String done = 'Done',
}) {
  first = dayOnly(first);
  last = dayOnly(last);
  var start = _clamp(dayOnly(initial?.start ?? today()), first, last);
  var end = _clamp(dayOnly(initial?.end ?? start), start, last);
  var editing = 0;
  return _wheelSheet(
    context,
    title: title,
    done: done,
    result: () => DateTimeRange(start: start, end: end),
    builder: (context, set) {
      final c = AppColors.of(context);
      Widget row(int i, String label, DateTime d) {
        final on = editing == i;
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (on) return;
              HapticFeedback.selectionClick();
              set(() => editing = i);
            },
            child: AnimatedContainer(
              duration: Motion.d(context, Motion.fast),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: ShapeDecoration(
                color: on ? c.accent.withValues(alpha: 0.12) : c.track,
                shape: RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.circular(Radii.m),
                ),
              ),
              child: Column(
                children: [
                  Text(label, style: body(13, color: c.muted, weight: 500)),
                  const SizedBox(height: 2),
                  Text(
                    _short(d),
                    style: body(17, color: on ? c.accent : c.text, weight: 600),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [row(0, 'Starts', start), row(1, 'Ends', end)],
            ),
          ),
          _wheel(
            CupertinoDatePicker(
              // A fresh wheel per field, starting at that field's date.
              key: ValueKey(editing),
              mode: CupertinoDatePickerMode.date,
              initialDateTime: editing == 0 ? start : end,
              minimumDate: editing == 0 ? first : start,
              maximumDate: last,
              onDateTimeChanged: (d) => set(() {
                d = dayOnly(d);
                if (editing == 0) {
                  start = d;
                  if (end.isBefore(start)) end = start;
                } else {
                  end = d;
                }
              }),
            ),
          ),
        ],
      );
    },
  );
}

DateTime _clamp(DateTime d, DateTime lo, DateTime hi) =>
    d.isBefore(lo) ? lo : (d.isAfter(hi) ? hi : d);

String _short(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${days[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
}
