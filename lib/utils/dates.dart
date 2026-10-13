/// Date helpers. The app only cares about calendar days, never times, so every
/// date is normalised to local midnight and stored as a `yyyy-MM-dd` key.
library;

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime today() => dayOnly(DateTime.now());

/// Adds whole calendar days (safe across DST changes, unlike `Duration`).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String key) {
  final parts = key.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Inclusive list of days from [start] to [end].
Iterable<DateTime> daysBetween(DateTime start, DateTime end) sync* {
  var d = dayOnly(start);
  final last = dayOnly(end);
  while (!d.isAfter(last)) {
    yield d;
    d = addDays(d, 1);
  }
}

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) => addDays(dayOnly(d), -(d.weekday - 1));
