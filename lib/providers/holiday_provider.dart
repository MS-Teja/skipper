import 'package:flutter/foundation.dart';

import '../models/holiday.dart';
import '../services/holiday_api_service.dart';
import '../services/storage_service.dart';
import '../utils/dates.dart';

enum FetchState { idle, loading, done, error }

/// Holidays (from the API and added by hand) and breaks.
class HolidayProvider extends ChangeNotifier {
  /// Bumped on every change, so dependants can tell a real change from a
  /// rebuild.
  int revision = 0;

  @override
  void notifyListeners() {
    revision++;
    super.notifyListeners();
  }

  HolidayProvider(this._storage, this._api)
    : _holidays = _storage.loadHolidays(),
      _breaks = _storage.loadBreaks();

  final StorageService _storage;
  final HolidayApiService _api;
  List<Holiday> _holidays;
  List<BreakPeriod> _breaks;

  FetchState fetchState = FetchState.idle;
  HolidayApiException? error;

  List<Holiday> get holidays =>
      [..._holidays]..sort((a, b) => a.date.compareTo(b.date));
  List<Holiday> get apiHolidays =>
      holidays.where((h) => h.source == HolidaySource.api).toList();
  List<Holiday> get manualHolidays =>
      holidays.where((h) => h.source == HolidaySource.manual).toList();
  List<BreakPeriod> get breaks =>
      [..._breaks]..sort((a, b) => a.start.compareTo(b.start));

  Holiday? manualHolidayOn(DateTime d) {
    for (final h in _holidays) {
      if (h.source == HolidaySource.manual && isSameDay(h.date, d)) return h;
    }
    return null;
  }

  /// Fetches the current and next year's holidays. Uses the cache unless
  /// [force] is set; keeps the student's ticks on refresh.
  Future<void> fetch({bool force = false}) async {
    fetchState = FetchState.loading;
    error = null;
    notifyListeners();
    final year = DateTime.now().year;
    try {
      const cacheKey = 'google_holidays_IN';
      var body = force ? null : _storage.cached(cacheKey);
      if (body == null) {
        body = await _api.fetchRaw();
        await _storage.putCache(cacheKey, body);
      }
      final fetched = HolidayApiService.parse(body, years: {year, year + 1});
      final previous = {for (final h in apiHolidays) h.key: h};
      for (final h in previous.values) {
        await _storage.deleteHoliday(h.key);
      }
      final merged = [
        for (final h in fetched)
          h.copyWith(applied: previous[h.key]?.applied ?? _defaultApplied(h)),
      ];
      _holidays = [...manualHolidays, ...merged];
      for (final h in merged) {
        await _storage.saveHoliday(h);
      }
      fetchState = FetchState.done;
    } on HolidayApiException catch (e) {
      error = e;
      fetchState = FetchState.error;
    }
    notifyListeners();
  }

  /// Public holidays start ticked; observances don't.
  static bool _defaultApplied(Holiday h) =>
      (h.type ?? '').toLowerCase().contains('public');

  Future<void> setApplied(Holiday h, bool applied) async {
    final updated = h.copyWith(applied: applied);
    _holidays = [for (final x in _holidays) x.key == h.key ? updated : x];
    notifyListeners();
    await _storage.saveHoliday(updated);
  }

  Future<void> addManualHoliday(DateTime date, String name) async {
    final h = Holiday(
      date: dayOnly(date),
      name: name,
      source: HolidaySource.manual,
    );
    _holidays = [..._holidays.where((x) => x.key != h.key), h];
    notifyListeners();
    await _storage.saveHoliday(h);
  }

  Future<void> removeHoliday(Holiday h) async {
    _holidays = _holidays.where((x) => x.key != h.key).toList();
    notifyListeners();
    await _storage.deleteHoliday(h.key);
  }

  bool breakOverlaps(BreakPeriod b) =>
      _breaks.any((x) => x.id != b.id && x.overlaps(b));

  Future<void> saveBreak(BreakPeriod b) async {
    _breaks = [..._breaks.where((x) => x.id != b.id), b];
    notifyListeners();
    await _storage.saveBreak(b);
  }

  Future<void> deleteBreak(String id) async {
    _breaks = _breaks.where((x) => x.id != id).toList();
    notifyListeners();
    await _storage.deleteBreak(id);
  }

  void reload() {
    _holidays = _storage.loadHolidays();
    _breaks = _storage.loadBreaks();
    notifyListeners();
  }
}
