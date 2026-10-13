import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/day_record.dart';
import '../models/holiday.dart';
import '../models/settings.dart';
import '../models/subject.dart';
import '../models/timetable.dart';
import '../utils/dates.dart';

/// Local persistence. Every value is stored as a JSON string in a Hive box,
/// so models only need `toJson` / `fromJson` (no code generation).
class StorageService {
  late Box<String> _settings;
  late Box<String> _subjects;
  late Box<String> _timetables;
  late Box<String> _records;
  late Box<String> _extras;
  late Box<String> _holidays;
  late Box<String> _breaks;
  late Box<String> _cache;

  /// Opens the boxes. Pass [path] in tests to avoid platform channels.
  Future<void> init({String? path}) async {
    if (path != null) {
      Hive.init(path);
    } else {
      await Hive.initFlutter();
    }
    _settings = await Hive.openBox<String>('settings');
    _subjects = await Hive.openBox<String>('subjects');
    _timetables = await Hive.openBox<String>('timetables');
    _records = await Hive.openBox<String>('records');
    _extras = await Hive.openBox<String>('extras');
    _holidays = await Hive.openBox<String>('holidays');
    _breaks = await Hive.openBox<String>('breaks');
    _cache = await Hive.openBox<String>('cache');
  }

  static Map<String, dynamic> _decode(String s) =>
      Map<String, dynamic>.from(jsonDecode(s) as Map);

  static List<T> _all<T>(Box<String> box, T Function(Map<String, dynamic>) f) =>
      [for (final v in box.values) f(_decode(v))];

  // Settings
  AppSettings loadSettings() {
    final raw = _settings.get('app');
    return raw == null
        ? const AppSettings()
        : AppSettings.fromJson(_decode(raw));
  }

  Future<void> saveSettings(AppSettings s) =>
      _settings.put('app', jsonEncode(s.toJson()));

  // Subjects (keyed by id, ordered by `order` list in settings box)
  List<Subject> loadSubjects() {
    final subjects = {
      for (final s in _all(_subjects, Subject.fromJson)) s.id: s,
    };
    final order = (jsonDecode(_settings.get('subjectOrder') ?? '[]') as List)
        .cast<String>();
    return [
      for (final id in order)
        if (subjects.containsKey(id)) subjects.remove(id)!,
      ...subjects.values,
    ];
  }

  Future<void> saveSubject(Subject s) =>
      _subjects.put(s.id, jsonEncode(s.toJson()));
  Future<void> deleteSubject(String id) => _subjects.delete(id);
  Future<void> saveSubjectOrder(List<String> ids) =>
      _settings.put('subjectOrder', jsonEncode(ids));

  // Timetable versions (keyed by effective date)
  List<TimetableVersion> loadTimetables() =>
      _all(_timetables, TimetableVersion.fromJson)
        ..sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

  Future<void> saveTimetable(TimetableVersion v) =>
      _timetables.put(dayKey(v.effectiveFrom), jsonEncode(v.toJson()));

  Future<void> deleteTimetable(DateTime effectiveFrom) =>
      _timetables.delete(dayKey(effectiveFrom));

  // Day records
  Map<String, DayRecord> loadRecords() => {
    for (final r in _all(_records, DayRecord.fromJson)) r.key: r,
  };

  Future<void> saveRecord(DayRecord r) =>
      _records.put(r.key, jsonEncode(r.toJson()));
  Future<void> deleteRecord(String key) => _records.delete(key);

  // Extra classes
  List<ExtraClass> loadExtras() => _all(_extras, ExtraClass.fromJson);
  Future<void> saveExtra(ExtraClass x) =>
      _extras.put(x.id, jsonEncode(x.toJson()));
  Future<void> deleteExtra(String id) => _extras.delete(id);

  // Holidays and breaks
  List<Holiday> loadHolidays() => _all(_holidays, Holiday.fromJson);
  Future<void> saveHoliday(Holiday h) =>
      _holidays.put(h.key, jsonEncode(h.toJson()));
  Future<void> deleteHoliday(String key) => _holidays.delete(key);

  List<BreakPeriod> loadBreaks() => _all(_breaks, BreakPeriod.fromJson);
  Future<void> saveBreak(BreakPeriod b) =>
      _breaks.put(b.id, jsonEncode(b.toJson()));
  Future<void> deleteBreak(String id) => _breaks.delete(id);

  // Raw API cache
  String? cached(String key) => _cache.get(key);
  Future<void> putCache(String key, String value) => _cache.put(key, value);

  /// "New semester": wipe everything except theme/rule preferences.
  Future<void> resetSemester() async {
    await Future.wait([
      _subjects.clear(),
      _timetables.clear(),
      _records.clear(),
      _extras.clear(),
      _breaks.clear(),
      _settings.delete('subjectOrder'),
    ]);
    // Keep API holidays (they're per year, still valid); drop manual ones.
    final manual = loadHolidays().where(
      (h) => h.source == HolidaySource.manual,
    );
    for (final h in manual) {
      await _holidays.delete(h.key);
    }
  }
}
