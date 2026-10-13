import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/day_record.dart';
import '../models/settings.dart';
import '../models/subject.dart';
import '../services/attendance_math.dart';
import '../services/schedule_engine.dart';
import '../services/storage_service.dart';
import '../utils/dates.dart';
import 'holiday_provider.dart';
import 'settings_provider.dart';
import 'timetable_provider.dart';

/// One subject's classes on a given day, ready for the UI.
class ClassEntry {
  const ClassEntry({
    required this.subject,
    required this.periods,
    required this.extraPeriods,
    required this.marks,
  });

  final Subject subject;
  final int periods;
  final int extraPeriods;
  final List<PeriodMark> marks;

  int get attended => marks.where((m) => m == PeriodMark.present).length;
  int get held => marks
      .where((m) => m == PeriodMark.present || m == PeriodMark.absent)
      .length;
  int get unmarked => marks.where((m) => m == PeriodMark.unmarked).length;
  bool get fullyMarked => unmarked == 0;
}

/// Marks, extra classes and every number derived from them.
///
/// Depends on settings, timetable and holidays through a
/// `ChangeNotifierProxyProvider3`, so stats recompute whenever any of them
/// changes.
class AttendanceProvider extends ChangeNotifier {
  AttendanceProvider(this._storage)
    : _records = _storage.loadRecords(),
      _extras = _storage.loadExtras();

  final StorageService _storage;
  Map<String, DayRecord> _records;
  List<ExtraClass> _extras;

  SettingsProvider? _settings;
  TimetableProvider? _timetable;
  HolidayProvider? _holidays;

  ScheduleEngine? _engine;
  Map<String, Tally>? _tally;
  DateTime? _tallyDay;

  /// Set when a mark lifts a subject (or the overall) back above target, so
  /// the UI can celebrate. Cleared by [consumeRecovery].
  String? recoveredLabel;

  /// What the schedule engine was built from, and what the stats read.
  Object? _engineInputs;
  Object? _statInputs;

  void updateDeps(SettingsProvider s, TimetableProvider t, HolidayProvider h) {
    _settings = s;
    _timetable = t;
    _holidays = h;
    // The proxy calls this whenever any dependency notifies, including for
    // theme or reminder tweaks. Only rebuild and notify on a real change.
    final x = s.settings;
    final engineInputs = (
      t.revision,
      h.revision,
      x.trackingStart,
      x.sundayClasses,
    );
    final statInputs = (engineInputs, x.rule, x.targetPercent);
    if (engineInputs != _engineInputs) {
      _engineInputs = engineInputs;
      _invalidate();
    }
    if (statInputs != _statInputs) {
      _statInputs = statInputs;
      // Proxy updates happen during build; notify afterwards.
      scheduleMicrotask(notifyListeners);
    }
  }

  void _invalidate() {
    _engine = null;
    _tally = null;
    _pending = null;
  }

  AppSettings get settings => _settings!.settings;
  AttendanceRule get rule => settings.rule;
  List<Subject> get subjects => _timetable?.subjects ?? const [];

  ScheduleEngine get engine => _engine ??= ScheduleEngine(
    versions: _timetable!.versions,
    holidays: _holidays!.holidays,
    breaks: _holidays!.breaks,
    extras: _extras,
    records: _records,
    trackingStart: settings.trackingStart,
    sundayClasses: settings.sundayClasses,
  );

  Map<String, Tally> get _tallies {
    final now = today();
    if (_tally == null || _tallyDay == null || !isSameDay(_tallyDay!, now)) {
      _tally = engine.tally(now);
      _tallyDay = now;
    }
    return _tally!;
  }

  int targetFor(Subject s) => rule == AttendanceRule.eachSubject
      ? (s.targetOverride ?? settings.targetPercent)
      : settings.targetPercent;

  AttendanceStats statsFor(Subject s) {
    final t = _tallies[s.id];
    return AttendanceStats(
      attended: s.baselineAttended + (t?.attended ?? 0),
      conducted: s.baselineConducted + (t?.conducted ?? 0),
      target: targetFor(s),
    );
  }

  Map<String, AttendanceStats> get allStats => {
    for (final s in subjects) s.id: statsFor(s),
  };

  AttendanceStats get overall {
    var a = 0, c = 0;
    for (final s in subjects) {
      final st = statsFor(s);
      a += st.attended;
      c += st.conducted;
    }
    return AttendanceStats(
      attended: a,
      conducted: c,
      target: settings.targetPercent,
    );
  }

  /// Subjects under their target (only meaningful in "each subject" mode).
  List<Subject> get atRisk => [
    for (final s in subjects)
      if (!statsFor(s).isAtOrAboveTarget) s,
  ];

  List<ClassEntry> classesOn(DateTime date) {
    final out = <ClassEntry>[];
    for (final c in engine.classesOn(date)) {
      final subject = _timetable!.subjectById(c.subjectId);
      if (subject == null) continue;
      out.add(
        ClassEntry(
          subject: subject,
          periods: c.periods,
          extraPeriods: c.extraPeriods,
          marks: engine.marksOn(date, c.subjectId, c.periods),
        ),
      );
    }
    return out;
  }

  OffReason? offReason(DateTime date) => engine.offReason(date);

  List<PendingDay>? _pending;
  DateTime? _pendingDay;

  /// Cached per engine and day; the nav badge and Today both read it.
  List<PendingDay> get pendingDays {
    final now = today();
    if (_pending == null || !isSameDay(_pendingDay!, now)) {
      _pending = engine.pendingDays(now);
      _pendingDay = now;
    }
    return _pending!;
  }

  int get pendingCount => pendingDays.fold(0, (sum, d) => sum + d.total);

  /// How one subject did on one day: (attended, held, unmarked, scheduled).
  (int, int, int, int) dayResult(DateTime date, String subjectId) {
    for (final c in engine.classesOn(date)) {
      if (c.subjectId != subjectId) continue;
      final marks = engine.marksOn(date, subjectId, c.periods);
      return (
        marks.where((m) => m == PeriodMark.present).length,
        marks
            .where((m) => m == PeriodMark.present || m == PeriodMark.absent)
            .length,
        marks.where((m) => m == PeriodMark.unmarked).length,
        c.periods,
      );
    }
    return (0, 0, 0, 0);
  }

  // ---- Mutations ----

  Future<void> setMarks(
    DateTime date,
    String subjectId,
    List<PeriodMark> marks,
  ) async {
    final subject = _timetable!.subjectById(subjectId);
    final before = subject == null ? null : statsFor(subject);
    final overallBefore = overall;

    final record = DayRecord(
      date: dayOnly(date),
      subjectId: subjectId,
      marks: marks,
    );
    if (marks.every((m) => m == PeriodMark.unmarked)) {
      _records = {..._records}..remove(record.key);
      unawaited(_storage.deleteRecord(record.key));
    } else {
      _records = {..._records, record.key: record};
      unawaited(_storage.saveRecord(record));
    }
    _invalidate();

    if (subject != null && before != null) {
      if (rule == AttendanceRule.eachSubject &&
          !before.isAtOrAboveTarget &&
          statsFor(subject).isAtOrAboveTarget) {
        recoveredLabel = subject.code;
      } else if (rule == AttendanceRule.overall &&
          !overallBefore.isAtOrAboveTarget &&
          overall.isAtOrAboveTarget) {
        recoveredLabel = 'Overall';
      }
    }
    notifyListeners();
  }

  String? consumeRecovery() {
    final r = recoveredLabel;
    recoveredLabel = null;
    return r;
  }

  Future<void> cycleMark(DateTime date, ClassEntry entry, int index) {
    final marks = [...entry.marks];
    marks[index] = marks[index].next;
    return setMarks(date, entry.subject.id, marks);
  }

  Future<void> markAll(DateTime date, ClassEntry entry, PeriodMark mark) =>
      setMarks(date, entry.subject.id, List.filled(entry.periods, mark));

  /// "All present" for every unmarked period on a day.
  Future<void> fillUnmarked(DateTime date, PeriodMark mark) async {
    for (final e in classesOn(date)) {
      if (e.fullyMarked) continue;
      await setMarks(date, e.subject.id, [
        for (final m in e.marks) m == PeriodMark.unmarked ? mark : m,
      ]);
    }
  }

  Future<void> addExtra(DateTime date, String subjectId, int periods) async {
    final x = ExtraClass(
      id: TimetableProvider.newId(),
      date: dayOnly(date),
      subjectId: subjectId,
      periods: periods,
    );
    _extras = [..._extras, x];
    _invalidate();
    notifyListeners();
    await _storage.saveExtra(x);
  }

  Future<void> removeExtrasOn(DateTime date, String subjectId) async {
    final gone = _extras
        .where((x) => isSameDay(x.date, date) && x.subjectId == subjectId)
        .toList();
    _extras = _extras.where((x) => !gone.contains(x)).toList();
    _invalidate();
    notifyListeners();
    for (final x in gone) {
      await _storage.deleteExtra(x.id);
    }
  }

  void reload() {
    _records = _storage.loadRecords();
    _extras = _storage.loadExtras();
    _invalidate();
    notifyListeners();
  }
}
