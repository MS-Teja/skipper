import '../utils/dates.dart';

/// One subject on one weekday, with how many periods it takes.
class Slot {
  const Slot({required this.subjectId, required this.periods})
    : assert(periods > 0);

  final String subjectId;
  final int periods;

  Slot withPeriods(int p) => Slot(subjectId: subjectId, periods: p);

  Map<String, dynamic> toJson() => {'subjectId': subjectId, 'periods': periods};

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
    subjectId: json['subjectId'] as String,
    periods: json['periods'] as int,
  );
}

/// The weekly timetable as it stood from [effectiveFrom] onwards.
///
/// Editing the timetable mid-semester creates a new version, so past days
/// keep the classes they actually had.
class TimetableVersion {
  const TimetableVersion({required this.effectiveFrom, required this.days});

  final DateTime effectiveFrom;

  /// Weekday (1 = Monday … 7 = Sunday) → ordered slots.
  final Map<int, List<Slot>> days;

  List<Slot> slotsFor(int weekday) => days[weekday] ?? const [];

  int periodsOn(int weekday) =>
      slotsFor(weekday).fold(0, (sum, s) => sum + s.periods);

  bool get isEmpty => days.values.every((s) => s.isEmpty);

  TimetableVersion copyWith({
    DateTime? effectiveFrom,
    Map<int, List<Slot>>? days,
  }) => TimetableVersion(
    effectiveFrom: effectiveFrom ?? this.effectiveFrom,
    days: days ?? this.days,
  );

  /// Drops a subject from every day (used when a subject is deleted).
  TimetableVersion withoutSubject(String subjectId) => copyWith(
    days: {
      for (final e in days.entries)
        e.key: e.value.where((s) => s.subjectId != subjectId).toList(),
    },
  );

  Map<String, dynamic> toJson() => {
    'effectiveFrom': dayKey(effectiveFrom),
    'days': {
      for (final e in days.entries)
        '${e.key}': [for (final s in e.value) s.toJson()],
    },
  };

  factory TimetableVersion.fromJson(Map<String, dynamic> json) =>
      TimetableVersion(
        effectiveFrom: parseDayKey(json['effectiveFrom'] as String),
        days: {
          for (final e in (json['days'] as Map).entries)
            int.parse(e.key as String): [
              for (final s in e.value as List)
                Slot.fromJson(Map<String, dynamic>.from(s as Map)),
            ],
        },
      );

  static TimetableVersion empty(DateTime from) =>
      TimetableVersion(effectiveFrom: dayOnly(from), days: const {});
}
