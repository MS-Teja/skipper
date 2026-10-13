import 'package:skipper/models/day_record.dart';
import 'package:skipper/models/holiday.dart';
import 'package:skipper/models/timetable.dart';
import 'package:skipper/services/long_weekend_finder.dart';
import 'package:skipper/services/schedule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

// October 2026: Mon 5, Tue 6, Wed 7, Thu 8, Fri 9, Sat 10, Sun 11.
DateTime oct(int day) => DateTime(2026, 10, day);

/// Mon: A×2 B×1 · Tue: A×1 C×3 (lab) · Wed: free · Thu: B×2 · Fri: A×1 B×1
/// Sat: C×1 only when [saturday] is true.
TimetableVersion week({DateTime? from, bool saturday = false}) =>
    TimetableVersion(
      effectiveFrom: from ?? oct(5),
      days: {
        1: const [
          Slot(subjectId: 'A', periods: 2),
          Slot(subjectId: 'B', periods: 1),
        ],
        2: const [
          Slot(subjectId: 'A', periods: 1),
          Slot(subjectId: 'C', periods: 3),
        ],
        4: const [Slot(subjectId: 'B', periods: 2)],
        5: const [
          Slot(subjectId: 'A', periods: 1),
          Slot(subjectId: 'B', periods: 1),
        ],
        if (saturday) 6: const [Slot(subjectId: 'C', periods: 1)],
      },
    );

Holiday holiday(DateTime d, [String name = 'Holiday']) =>
    Holiday(date: d, name: name, source: HolidaySource.manual);

ScheduleEngine engine({
  List<TimetableVersion>? versions,
  List<Holiday> holidays = const [],
  List<BreakPeriod> breaks = const [],
  List<ExtraClass> extras = const [],
  List<DayRecord> records = const [],
}) => ScheduleEngine(
  versions: versions ?? [week()],
  holidays: holidays,
  breaks: breaks,
  extras: extras,
  records: {for (final r in records) r.key: r},
  trackingStart: oct(5),
);

Map<String, int> periods(ScheduleEngine e, DateTime d) => {
  for (final c in e.classesOn(d)) c.subjectId: c.periods,
};

void main() {
  group('ScheduleEngine', () {
    test('follows the weekly timetable, labs count each period', () {
      final e = engine();
      expect(periods(e, oct(5)), {'A': 2, 'B': 1});
      expect(periods(e, oct(6)), {'A': 1, 'C': 3});
    });

    test('a weekday with no classes is an off day', () {
      final e = engine();
      expect(e.classesOn(oct(7)), isEmpty);
      expect(e.offReason(oct(7)), OffReason.noTimetable);
    });

    test('Saturday off unless the timetable has Saturday classes', () {
      expect(engine().offReason(oct(10)), OffReason.noTimetable);
      expect(periods(engine(versions: [week(saturday: true)]), oct(10)), {
        'C': 1,
      });
    });

    test('Sunday is off', () {
      expect(engine().offReason(oct(11)), OffReason.sunday);
    });

    test('holidays and breaks remove classes', () {
      final e = engine(
        holidays: [holiday(oct(8), 'Dussehra')],
        breaks: [
          BreakPeriod(id: 'b', label: 'Mid-sems', start: oct(12), end: oct(17)),
        ],
      );
      expect(e.offReason(oct(8)), OffReason.holiday);
      expect(e.classesOn(oct(8)), isEmpty);
      for (var d = 12; d <= 17; d++) {
        expect(e.classesOn(oct(d)), isEmpty, reason: 'Oct $d is in the break');
      }
      expect(periods(e, oct(19)), {'A': 2, 'B': 1});
    });

    test('un-applied API holidays do not remove classes', () {
      final e = engine(
        holidays: [
          Holiday(
            date: oct(8),
            name: 'Optional',
            source: HolidaySource.api,
            applied: false,
          ),
        ],
      );
      expect(periods(e, oct(8)), {'B': 2});
    });

    test('extra classes add periods, even on an off day', () {
      final e = engine(
        extras: [
          ExtraClass(id: 'x', date: oct(7), subjectId: 'C', periods: 2),
          ExtraClass(id: 'y', date: oct(5), subjectId: 'A', periods: 1),
        ],
      );
      expect(periods(e, oct(7)), {'C': 2});
      expect(periods(e, oct(5)), {'A': 3, 'B': 1});
    });

    test('a timetable change mid-semester leaves past days unchanged', () {
      final changed = TimetableVersion(
        effectiveFrom: oct(19),
        days: {
          1: const [Slot(subjectId: 'C', periods: 1)],
        },
      );
      final e = engine(versions: [week(), changed]);
      expect(periods(e, oct(12)), {'A': 2, 'B': 1}); // before the change
      expect(periods(e, oct(19)), {'C': 1}); // after the change
      expect(e.classesOn(oct(20)), isEmpty); // Tuesday dropped in new version
    });

    test(
      'tally counts present, absent and partial periods; unmarked is pending',
      () {
        final e = engine(
          records: [
            DayRecord(
              date: oct(5),
              subjectId: 'A',
              marks: const [PeriodMark.present, PeriodMark.absent],
            ),
            DayRecord(
              date: oct(5),
              subjectId: 'B',
              marks: const [PeriodMark.cancelled],
            ),
            DayRecord(
              date: oct(6),
              subjectId: 'C',
              marks: const [
                PeriodMark.present,
                PeriodMark.absent,
                PeriodMark.unmarked,
              ],
            ),
          ],
        );
        final t = e.tally(oct(6));
        expect(
          (t['A']!.attended, t['A']!.conducted, t['A']!.pending),
          (1, 2, 1),
        ); // Tue A unmarked
        expect(
          (t['B']!.attended, t['B']!.conducted, t['B']!.pending),
          (0, 0, 0),
        ); // cancelled
        expect(
          (t['C']!.attended, t['C']!.conducted, t['C']!.pending),
          (1, 2, 1),
        );
      },
    );

    test('pending lists past days with unmarked periods, newest first', () {
      final e = engine(
        records: [
          DayRecord(
            date: oct(5),
            subjectId: 'A',
            marks: const [PeriodMark.present, PeriodMark.present],
          ),
        ],
      );
      final p = e.pendingDays(oct(7));
      expect(p.map((d) => d.date), [oct(6), oct(5)]);
      expect(p.last.unmarkedBySubject, {'B': 1});
      expect(p.first.total, 4);
    });

    test('a break never produces pending days', () {
      final e = engine(
        breaks: [
          BreakPeriod(id: 'b', label: 'Exams', start: oct(5), end: oct(9)),
        ],
      );
      expect(e.pendingDays(oct(10)), isEmpty);
    });

    test('periodsBetween prices a leave from the timetable', () {
      final e = engine(holidays: [holiday(oct(8))]);
      // Mon–Fri with Thursday a holiday and Wednesday free.
      expect(e.periodsBetween(oct(5), oct(9)), {'A': 4, 'B': 2, 'C': 3});
    });
  });

  group('LongWeekendFinder', () {
    test('free Wednesday + Thursday holiday: skip Friday for Wed→Sun', () {
      final e = engine(holidays: [holiday(oct(8), 'Dussehra')]);
      final best = LongWeekendFinder(e).find(from: oct(5), days: 14).first;
      expect((best.start, best.end), (oct(7), oct(11)));
      expect(best.length, 5);
      expect(best.skipDays, [oct(9)]);
      expect(best.cost, {'A': 1, 'B': 1});
    });

    test('Tuesday holiday: skip Monday, and the free Wednesday joins too', () {
      final e = engine(holidays: [holiday(oct(13))]);
      final found = LongWeekendFinder(e).find(from: oct(5), days: 14);
      final w = found.firstWhere(
        (w) => w.skipDays.length == 1 && w.skipDays.first == oct(12),
      );
      // Sat 10, Sun 11 off · Mon 12 skipped · Tue 13 holiday · Wed 14 free.
      expect((w.start, w.end), (oct(10), oct(14)));
      expect(w.length, 5);
      expect(w.cost, {'A': 2, 'B': 1});
    });

    test('Saturday with classes is a working day', () {
      final e = engine(
        versions: [week(saturday: true)],
        holidays: [holiday(oct(9))], // Friday
      );
      final found = LongWeekendFinder(e).find(from: oct(5), days: 14);
      final w = found.firstWhere((w) => w.skipDays.contains(oct(10)));
      expect((w.start, w.end), (oct(9), oct(11)));
      expect(w.cost, {'C': 1});
    });

    test('a holiday already next to a weekend is a free long weekend', () {
      final e = engine(holidays: [holiday(oct(9))]); // Fri, Sat+Sun off
      final found = LongWeekendFinder(e).find(from: oct(5), days: 14);
      final free = found.firstWhere((w) => w.isFree);
      expect((free.start, free.end), (oct(9), oct(11)));
      expect(free.periodsMissed, 0);
    });

    test('never suggests skipping more than two working days', () {
      final e = engine(holidays: [holiday(oct(8))]);
      for (final w in LongWeekendFinder(e).find(from: oct(5), days: 30)) {
        expect(w.skipDays.length, lessThanOrEqualTo(2));
        for (final s in w.skipDays) {
          expect(
            e.isOffDay(s),
            isFalse,
            reason: 'skip days must be working days',
          );
        }
      }
    });
  });
}
