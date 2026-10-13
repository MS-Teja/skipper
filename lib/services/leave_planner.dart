import '../models/settings.dart';
import 'attendance_math.dart';
import 'schedule_engine.dart';

class LeaveImpact {
  const LeaveImpact({
    required this.subjectId,
    required this.before,
    required this.missed,
  });

  /// null for the overall row.
  final String? subjectId;
  final AttendanceStats before;
  final int missed;

  AttendanceStats get after => before.afterSkipping(missed);
  bool get staysSafe => after.isAtOrAboveTarget;

  /// Classes to attend (before or after the leave) to stay at target.
  int? get extraNeeded => after.toRecover;
}

class LeavePlan {
  const LeavePlan({
    required this.start,
    required this.end,
    required this.subjects,
    required this.overall,
    required this.rule,
  });

  final DateTime start;
  final DateTime end;
  final List<LeaveImpact> subjects;
  final LeaveImpact overall;
  final AttendanceRule rule;

  int get totalMissed => overall.missed;

  /// The rows the rule actually cares about.
  List<LeaveImpact> get judged =>
      rule == AttendanceRule.overall ? [overall] : subjects;

  bool get isSafe => judged.every((i) => i.staysSafe);

  List<LeaveImpact> get atRisk => judged.where((i) => !i.staysSafe).toList();
}

/// Prices a leave from [start] to [end] against current attendance.
///
/// Classes between now and the leave are ignored (not assumed attended),
/// so the verdict errs on the safe side.
LeavePlan planLeave({
  required ScheduleEngine engine,
  required DateTime start,
  required DateTime end,
  required Map<String, AttendanceStats> current,
  required AttendanceStats overall,
  required AttendanceRule rule,
}) {
  final missed = engine.periodsBetween(start, end);
  final subjects = [
    for (final e in current.entries)
      LeaveImpact(
        subjectId: e.key,
        before: e.value,
        missed: missed[e.key] ?? 0,
      ),
  ];
  return LeavePlan(
    start: start,
    end: end,
    subjects: subjects,
    overall: LeaveImpact(
      subjectId: null,
      before: overall,
      missed: missed.values.fold(0, (a, b) => a + b),
    ),
    rule: rule,
  );
}
