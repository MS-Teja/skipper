import 'dart:math';

import '../models/day_record.dart';
import '../models/holiday.dart';
import '../models/settings.dart';
import '../models/subject.dart';
import '../models/timetable.dart';
import '../utils/dates.dart';
import 'storage_service.dart';

/// Seeds a realistic sample semester (for demos and screenshots).
///
/// Six weeks of history, OS slipping below 75%, a lab with partial
/// attendance, a holiday, and a couple of unmarked days.
Future<void> seedDemoSemester(StorageService storage, AppSettings base) async {
  await storage.resetSemester();
  final start = addDays(startOfWeek(today()), -7 * 6);
  const subjects = [
    Subject(
      id: 'dbms',
      name: 'Database Management Systems',
      code: 'DBMS',
      colorIndex: 0,
    ),
    Subject(id: 'os', name: 'Operating Systems', code: 'OS', colorIndex: 1),
    Subject(id: 'cn', name: 'Computer Networks', code: 'CN', colorIndex: 2),
    Subject(
      id: 'oslab',
      name: 'Operating Systems Lab',
      code: 'OS LAB',
      colorIndex: 3,
    ),
    Subject(
      id: 'daa',
      name: 'Design & Analysis of Algorithms',
      code: 'DAA',
      colorIndex: 4,
    ),
    Subject(id: 'se', name: 'Software Engineering', code: 'SE', colorIndex: 5),
  ];
  for (final s in subjects) {
    await storage.saveSubject(s);
  }
  await storage.saveSubjectOrder([for (final s in subjects) s.id]);

  // Wednesday afternoons free, Saturday half day.
  final days = <int, List<Slot>>{
    1: const [
      Slot(subjectId: 'dbms', periods: 1),
      Slot(subjectId: 'os', periods: 2),
      Slot(subjectId: 'cn', periods: 1),
    ],
    2: const [
      Slot(subjectId: 'daa', periods: 1),
      Slot(subjectId: 'oslab', periods: 3),
      Slot(subjectId: 'se', periods: 1),
    ],
    3: const [
      Slot(subjectId: 'dbms', periods: 1),
      Slot(subjectId: 'cn', periods: 1),
    ],
    4: const [
      Slot(subjectId: 'os', periods: 1),
      Slot(subjectId: 'daa', periods: 1),
      Slot(subjectId: 'se', periods: 1),
      Slot(subjectId: 'dbms', periods: 1),
    ],
    5: const [
      Slot(subjectId: 'cn', periods: 1),
      Slot(subjectId: 'daa', periods: 2),
      Slot(subjectId: 'os', periods: 1),
    ],
    6: const [
      Slot(subjectId: 'se', periods: 1),
      Slot(subjectId: 'dbms', periods: 1),
    ],
  };
  await storage.saveTimetable(
    TimetableVersion(effectiveFrom: start, days: days),
  );

  final holiday = addDays(start, 7 * 2 + 4); // a Friday, two weeks in
  await storage.saveHoliday(
    Holiday(
      date: holiday,
      name: 'Festival holiday',
      source: HolidaySource.manual,
    ),
  );
  // An upcoming Friday off, so the long-weekend finder has something to find.
  await storage.saveHoliday(
    Holiday(
      date: addDays(startOfWeek(today()), 7 + 4),
      name: 'College fest',
      source: HolidaySource.manual,
    ),
  );

  // How reliably the student attends each subject.
  const attendRate = {
    'dbms': 0.8,
    'os': 0.66,
    'cn': 0.84,
    'oslab': 0.8,
    'daa': 0.72,
    'se': 0.9,
  };
  final rng = Random(42);
  final yesterday = addDays(today(), -1);
  for (final d in daysBetween(start, today())) {
    if (isSameDay(d, holiday)) continue;
    final slots = days[d.weekday] ?? const [];
    final skipDay =
        d.isAfter(addDays(today(), -3)) &&
        !isSameDay(d, yesterday); // leave a gap to mark
    for (final s in slots) {
      if (isSameDay(d, today())) {
        if (s.subjectId != 'dbms' && s.subjectId != 'os') {
          continue; // part of today marked
        }
      } else if (skipDay) {
        continue;
      }
      final marks = [
        for (var p = 0; p < s.periods; p++)
          rng.nextDouble() < attendRate[s.subjectId]!
              ? PeriodMark.present
              : PeriodMark.absent,
      ];
      if (isSameDay(d, today()) && s.periods > 1) {
        marks[marks.length - 1] = PeriodMark.unmarked;
      }
      await storage.saveRecord(
        DayRecord(date: d, subjectId: s.subjectId, marks: marks),
      );
    }
  }

  await storage.saveSettings(
    base.copyWith(onboarded: true, trackingStart: start),
  );
}
