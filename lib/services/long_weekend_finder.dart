import '../models/holiday.dart';
import '../utils/dates.dart';
import 'schedule_engine.dart';

/// A suggested run of days off around a holiday.
class LongWeekend {
  const LongWeekend({
    required this.start,
    required this.end,
    required this.skipDays,
    required this.cost,
    required this.holidays,
  });

  final DateTime start;
  final DateTime end;

  /// Working days the student would have to miss.
  final List<DateTime> skipDays;

  /// Periods missed per subject.
  final Map<String, int> cost;

  /// The holidays that make this run possible.
  final List<Holiday> holidays;

  int get length => end.difference(start).inDays + 1;
  int get periodsMissed => cost.values.fold(0, (a, b) => a + b);
  bool get isFree => skipDays.isEmpty;
}

/// Finds stretches where skipping 0–2 working days next to a holiday gives
/// 3 or more days off in a row. "Working day" = the timetable has classes.
class LongWeekendFinder {
  LongWeekendFinder(this.engine, {this.maxSkips = 2, this.minLength = 3});

  final ScheduleEngine engine;
  final int maxSkips;
  final int minLength;

  List<LongWeekend> find({required DateTime from, int days = 60}) {
    final first = dayOnly(from);
    final last = addDays(first, days);
    bool inRange(DateTime d) => !d.isBefore(first) && !d.isAfter(last);
    bool off(DateTime d) => engine.isOffDay(d);

    final found = <String, LongWeekend>{};
    for (final d in daysBetween(first, last)) {
      final h = engine.holidayOn(d);
      if (h == null || !off(d)) continue;

      // The natural run of off days around this holiday.
      var lo = d, hi = d;
      while (inRange(addDays(lo, -1)) && off(addDays(lo, -1))) {
        lo = addDays(lo, -1);
      }
      while (inRange(addDays(hi, 1)) && off(addDays(hi, 1))) {
        hi = addDays(hi, 1);
      }

      for (var left = 0; left <= maxSkips; left++) {
        for (var right = 0; left + right <= maxSkips; right++) {
          final l = _extend(lo, -1, left, inRange, off);
          final r = _extend(hi, 1, right, inRange, off);
          if (l == null || r == null) continue;
          final start = l.$1, end = r.$1;
          final skips = [...l.$2, ...r.$2]..sort();
          if (end.difference(start).inDays + 1 < minLength) continue;
          final key = '${dayKey(start)}_${dayKey(end)}';
          if (found.containsKey(key)) continue;
          final cost = <String, int>{};
          for (final s in skips) {
            for (final c in engine.classesOn(s)) {
              cost[c.subjectId] = (cost[c.subjectId] ?? 0) + c.periods;
            }
          }
          found[key] = LongWeekend(
            start: start,
            end: end,
            skipDays: skips,
            cost: cost,
            holidays: [
              for (final x in daysBetween(start, end))
                if (engine.holidayOn(x) != null) engine.holidayOn(x)!,
            ],
          );
        }
      }
    }

    final list = found.values.toList()
      ..sort((a, b) {
        // Best value first: most days off per period missed, then earliest.
        final va = a.length / (a.periodsMissed + 1);
        final vb = b.length / (b.periodsMissed + 1);
        final byValue = vb.compareTo(va);
        return byValue != 0 ? byValue : a.start.compareTo(b.start);
      });
    // Drop suggestions that are strictly worse than one covering them.
    return [
      for (final w in list)
        if (!list.any(
          (o) =>
              !identical(o, w) &&
              !o.start.isAfter(w.start) &&
              !o.end.isBefore(w.end) &&
              o.periodsMissed <= w.periodsMissed &&
              o.length > w.length,
        ))
          w,
    ];
  }

  /// From [edge], step in [dir] skipping exactly [skips] working days,
  /// absorbing every off day passed on the way. Returns the new edge and the
  /// skipped days, or null if it runs out of range first.
  (DateTime, List<DateTime>)? _extend(
    DateTime edge,
    int dir,
    int skips,
    bool Function(DateTime) inRange,
    bool Function(DateTime) off,
  ) {
    var cur = edge;
    final skipped = <DateTime>[];
    for (var i = 0; i < skips; i++) {
      final next = addDays(cur, dir);
      if (!inRange(next) || off(next)) return null;
      skipped.add(next);
      cur = next;
      while (inRange(addDays(cur, dir)) && off(addDays(cur, dir))) {
        cur = addDays(cur, dir);
      }
    }
    return (cur, skipped);
  }
}
