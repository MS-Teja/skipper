import '../utils/dates.dart';

enum HolidaySource { api, manual }

/// A day with no classes. API holidays start un-applied until the student
/// ticks the ones their college observes; manual ones are always applied.
class Holiday {
  const Holiday({
    required this.date,
    required this.name,
    required this.source,
    this.applied = true,
    this.type,
  });

  final DateTime date;
  final String name;
  final HolidaySource source;
  final bool applied;

  /// API classification, e.g. "National holiday", "Gazetted Holiday".
  final String? type;

  String get key => '${dayKey(date)}|${source.name}|$name';

  Holiday copyWith({bool? applied}) => Holiday(
    date: date,
    name: name,
    source: source,
    applied: applied ?? this.applied,
    type: type,
  );

  Map<String, dynamic> toJson() => {
    'date': dayKey(date),
    'name': name,
    'source': source.name,
    'applied': applied,
    'type': type,
  };

  factory Holiday.fromJson(Map<String, dynamic> json) => Holiday(
    date: parseDayKey(json['date'] as String),
    name: json['name'] as String,
    source: HolidaySource.values.byName(json['source'] as String),
    applied: json['applied'] as bool? ?? true,
    type: json['type'] as String?,
  );
}

/// A stretch with no classes, e.g. mid-semester exams or a vacation.
class BreakPeriod {
  const BreakPeriod({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
  });

  final String id;
  final String label;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime d) => !d.isBefore(start) && !d.isAfter(end);

  bool overlaps(BreakPeriod other) =>
      !end.isBefore(other.start) && !other.end.isBefore(start);

  int get lengthInDays => end.difference(start).inDays + 1;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'start': dayKey(start),
    'end': dayKey(end),
  };

  factory BreakPeriod.fromJson(Map<String, dynamic> json) => BreakPeriod(
    id: json['id'] as String,
    label: json['label'] as String,
    start: parseDayKey(json['start'] as String),
    end: parseDayKey(json['end'] as String),
  );
}
