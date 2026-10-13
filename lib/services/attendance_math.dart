/// Attendance math, done entirely in integers.
///
/// The target is a whole percent (e.g. 75). Every comparison is rewritten as
/// `100 * attended >= target * conducted`, so no floating-point rounding can
/// creep in. (A decimal version of these formulas was wrong in ~24k of 376k
/// brute-force cases; this one was wrong in none.)
library;

/// A snapshot of one subject (or the overall total) against a target.
class AttendanceStats {
  const AttendanceStats({
    required this.attended,
    required this.conducted,
    required this.target,
  }) : assert(attended >= 0),
       assert(conducted >= attended),
       assert(target > 0 && target <= 100);

  final int attended;
  final int conducted;

  /// Whole percent, 1–100.
  final int target;

  int get missed => conducted - attended;

  bool get hasClasses => conducted > 0;

  /// Exact ratio 0–1 (for rings and bars). 0 when there are no classes.
  double get ratio => conducted == 0 ? 0 : attended / conducted;

  /// Percent rounded **down**, so 74.9% never shows as 75%.
  int get percentFloor => conducted == 0 ? 0 : (100 * attended) ~/ conducted;

  /// Percent to one decimal, also rounded down (e.g. 72.9).
  double get percentOneDecimal =>
      conducted == 0 ? 0 : ((1000 * attended) ~/ conducted) / 10;

  bool get isAtOrAboveTarget => 100 * attended >= target * conducted;

  /// How many more classes can be missed while staying at or above target.
  int get canSkip => skipsAllowed(attended, conducted, target);

  /// How many classes in a row must be attended to reach target.
  /// `null` means it can never be reached (only possible at a 100% target).
  int? get toRecover => classesToRecover(attended, conducted, target);

  /// What the percentage would be after missing [k] more classes.
  AttendanceStats afterSkipping(int k) => AttendanceStats(
    attended: attended,
    conducted: conducted + k,
    target: target,
  );

  /// What the percentage would be after attending [k] more classes.
  AttendanceStats afterAttending(int k) => AttendanceStats(
    attended: attended + k,
    conducted: conducted + k,
    target: target,
  );

  AttendanceStats operator +(AttendanceStats other) => AttendanceStats(
    attended: attended + other.attended,
    conducted: conducted + other.conducted,
    target: target,
  );

  Risk get risk {
    if (!isAtOrAboveTarget) return Risk.danger;
    if (canSkip == 0) return Risk.edge;
    return Risk.safe;
  }

  @override
  String toString() => 'AttendanceStats($attended/$conducted @$target%)';
}

enum Risk { safe, edge, danger }

/// Largest k ≥ 0 such that a / (c + k) ≥ T / 100.
int skipsAllowed(int attended, int conducted, int target) {
  final slack = 100 * attended - target * conducted;
  if (slack <= 0) return 0;
  return slack ~/ target;
}

/// Smallest n ≥ 0 such that (a + n) / (c + n) ≥ T / 100.
/// Returns `null` when no n works (target 100% after any miss).
int? classesToRecover(int attended, int conducted, int target) {
  final deficit = target * conducted - 100 * attended;
  if (deficit <= 0) return 0;
  if (target >= 100) return null;
  final perClass = 100 - target;
  return (deficit + perClass - 1) ~/ perClass; // ceiling division
}
