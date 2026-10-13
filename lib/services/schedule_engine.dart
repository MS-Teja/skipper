import '../models/day_record.dart';
import '../models/holiday.dart';
import '../models/timetable.dart';
import '../utils/dates.dart';

/// Why a day has no classes.
enum OffReason { beforeTracking, holiday, breakPeriod, noTimetable, sunday }

/// One subject's classes on one date.
class ScheduledClass {
  const ScheduledClass({
    required this.subjectId,
    required this.periods,
    this.extraPeriods = 0,
  });

  final String subjectId;

  /// Total periods that day, timetable + extra classes.
  final int periods;

  /// How many of [periods] came from "+ Extra class".
  final int extraPeriods;
}

/// Running totals for one subject.
class Tally {
  int attended = 0;
  int conducted = 0;
  int pending = 0;
}

/// Unmarked classes on one past day.
class PendingDay {
  const PendingDay(this.date, this.unmarkedBySubject);
  final DateTime date;
  final Map<String, int> unmarkedBySubject;
  int get total => unmarkedBySubject.values.fold(0, (a, b) => a + b);
}

/// The single source of truth for "which classes happen on which day".
///
/// Today, Pending, the leave planner, the long-weekend finder and the
/// reminder all go through [classesOn], so they always agree.
class ScheduleEngine {
  ScheduleEngine({
    required List<TimetableVersion> versions,
    required Iterable<Holiday> holidays,
    required this.breaks,
    required Iterable<ExtraClass> extras,
    required this.records,
    required this.trackingStart,
    this.sundayClasses = false,
  }) : versions = [...versions]
         ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom)),
       _holidays = {
         for (final h in holidays)
           if (h.applied) dayKey(h.date): h,
       },
       _extras = _groupExtras(extras);

  final List<TimetableVersion> versions;
  final List<BreakPeriod> breaks;
  final Map<String, DayRecord> records;
  final DateTime? trackingStart;
  final bool sundayClasses;
  final Map<String, Holiday> _holidays;
  final Map<String, List<ExtraClass>> _extras;

  static Map<String, List<ExtraClass>> _groupExtras(Iterable<ExtraClass> xs) {
    final map = <String, List<ExtraClass>>{};
    for (final x in xs) {
      (map[dayKey(x.date)] ??= []).add(x);
    }
    return map;
  }

  /// The timetable in force on [date], or null if none had started yet.
  TimetableVersion? versionOn(DateTime date) {
    TimetableVersion? found;
    for (final v in versions) {
      if (v.effectiveFrom.isAfter(date)) break;
      found = v;
    }
    return found;
  }

  Holiday? holidayOn(DateTime date) => _holidays[dayKey(date)];

  BreakPeriod? breakOn(DateTime date) {
    for (final b in breaks) {
      if (b.contains(date)) return b;
    }
    return null;
  }

  List<ExtraClass> extrasOn(DateTime date) => _extras[dayKey(date)] ?? const [];

  /// Why the timetable gives no classes on [date] (extra classes aside),
  /// or null if it's a normal working day.
  OffReason? offReason(DateTime date) {
    final d = dayOnly(date);
    if (trackingStart != null && d.isBefore(trackingStart!)) {
      return OffReason.beforeTracking;
    }
    if (holidayOn(d) != null) return OffReason.holiday;
    if (breakOn(d) != null) return OffReason.breakPeriod;
    if (d.weekday == DateTime.sunday && !sundayClasses) return OffReason.sunday;
    final v = versionOn(d);
    if (v == null || v.periodsOn(d.weekday) == 0) return OffReason.noTimetable;
    return null;
  }

  /// Classes on [date]: the timetable (unless it's an off day) plus any
  /// extra classes, which count even on holidays (make-up classes).
  List<ScheduledClass> classesOn(DateTime date) {
    final d = dayOnly(date);
    if (trackingStart != null && d.isBefore(trackingStart!)) return const [];
    final periods = <String, int>{};
    final extra = <String, int>{};
    if (offReason(d) == null) {
      for (final s in versionOn(d)!.slotsFor(d.weekday)) {
        periods[s.subjectId] = (periods[s.subjectId] ?? 0) + s.periods;
      }
    }
    for (final x in extrasOn(d)) {
      periods[x.subjectId] = (periods[x.subjectId] ?? 0) + x.periods;
      extra[x.subjectId] = (extra[x.subjectId] ?? 0) + x.periods;
    }
    return [
      for (final e in periods.entries)
        ScheduledClass(
          subjectId: e.key,
          periods: e.value,
          extraPeriods: extra[e.key] ?? 0,
        ),
    ];
  }

  bool isOffDay(DateTime date) => classesOn(date).isEmpty;

  /// Marks for [subjectId] on [date], sized to the scheduled periods.
  List<PeriodMark> marksOn(DateTime date, String subjectId, int periods) {
    final r = records[DayRecord.keyFor(date, subjectId)];
    return r == null
        ? List.filled(periods, PeriodMark.unmarked)
        : r.marksFor(periods);
  }

  /// Attended / conducted / pending per subject, from tracking start to
  /// [upTo] inclusive. Baselines are added by the caller.
  Map<String, Tally> tally(DateTime upTo) {
    final result = <String, Tally>{};
    final start = trackingStart;
    if (start == null) return result;
    for (final d in daysBetween(start, upTo)) {
      for (final c in classesOn(d)) {
        final t = result[c.subjectId] ??= Tally();
        for (final m in marksOn(d, c.subjectId, c.periods)) {
          switch (m) {
            case PeriodMark.present:
              t.attended++;
              t.conducted++;
            case PeriodMark.absent:
              t.conducted++;
            case PeriodMark.unmarked:
              t.pending++;
            case PeriodMark.cancelled:
              break;
          }
        }
      }
    }
    return result;
  }

  /// Days before [before] that still have unmarked periods, newest first.
  List<PendingDay> pendingDays(DateTime before) {
    final start = trackingStart;
    if (start == null) return const [];
    final out = <PendingDay>[];
    for (final d in daysBetween(start, addDays(before, -1))) {
      final unmarked = <String, int>{};
      for (final c in classesOn(d)) {
        final n = marksOn(
          d,
          c.subjectId,
          c.periods,
        ).where((m) => m == PeriodMark.unmarked).length;
        if (n > 0) unmarked[c.subjectId] = n;
      }
      if (unmarked.isNotEmpty) out.add(PendingDay(d, unmarked));
    }
    return out.reversed.toList();
  }

  /// Scheduled periods per subject between [start] and [end] inclusive
  /// (used by the leave planner to price a leave).
  Map<String, int> periodsBetween(DateTime start, DateTime end) {
    final out = <String, int>{};
    for (final d in daysBetween(start, end)) {
      for (final c in classesOn(d)) {
        out[c.subjectId] = (out[c.subjectId] ?? 0) + c.periods;
      }
    }
    return out;
  }
}
