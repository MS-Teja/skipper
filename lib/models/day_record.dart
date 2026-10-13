import '../utils/dates.dart';

/// The state of a single period.
enum PeriodMark {
  unmarked,
  present,
  absent,

  /// The period didn't happen (teacher absent, cancelled). Doesn't count.
  cancelled;

  /// Tap cycle on a period dot: unmarked → present → absent → unmarked.
  PeriodMark get next => switch (this) {
    PeriodMark.unmarked => PeriodMark.present,
    PeriodMark.present => PeriodMark.absent,
    PeriodMark.absent => PeriodMark.unmarked,
    PeriodMark.cancelled => PeriodMark.unmarked,
  };
}

/// What happened to one subject on one date, period by period.
class DayRecord {
  const DayRecord({
    required this.date,
    required this.subjectId,
    required this.marks,
  });

  final DateTime date;
  final String subjectId;
  final List<PeriodMark> marks;

  String get key => keyFor(date, subjectId);

  static String keyFor(DateTime date, String subjectId) =>
      '${dayKey(date)}|$subjectId';

  /// Marks resized to [periods]: missing periods are unmarked.
  List<PeriodMark> marksFor(int periods) => [
    for (var i = 0; i < periods; i++)
      i < marks.length ? marks[i] : PeriodMark.unmarked,
  ];

  Map<String, dynamic> toJson() => {
    'date': dayKey(date),
    'subjectId': subjectId,
    'marks': [for (final m in marks) m.index],
  };

  factory DayRecord.fromJson(Map<String, dynamic> json) => DayRecord(
    date: parseDayKey(json['date'] as String),
    subjectId: json['subjectId'] as String,
    marks: [for (final i in json['marks'] as List) PeriodMark.values[i as int]],
  );
}

/// A make-up class on a specific date that isn't in the timetable.
class ExtraClass {
  const ExtraClass({
    required this.id,
    required this.date,
    required this.subjectId,
    required this.periods,
  });

  final String id;
  final DateTime date;
  final String subjectId;
  final int periods;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': dayKey(date),
    'subjectId': subjectId,
    'periods': periods,
  };

  factory ExtraClass.fromJson(Map<String, dynamic> json) => ExtraClass(
    id: json['id'] as String,
    date: parseDayKey(json['date'] as String),
    subjectId: json['subjectId'] as String,
    periods: json['periods'] as int,
  );
}
