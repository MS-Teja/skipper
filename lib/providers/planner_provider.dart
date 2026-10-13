import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/leave_planner.dart';
import '../services/long_weekend_finder.dart';
import '../utils/dates.dart';
import 'attendance_provider.dart';

/// The leave planner's selected range and the long-weekend suggestions.
class PlannerProvider extends ChangeNotifier {
  AttendanceProvider? _attendance;
  DateTime? _start;
  DateTime? _end;
  List<LongWeekend>? _weekends;

  void updateDeps(AttendanceProvider a) {
    _attendance = a;
    _weekends = null;
    scheduleMicrotask(notifyListeners);
  }

  DateTime? get start => _start;
  DateTime? get end => _end;
  bool get hasRange => _start != null && _end != null;

  void setRange(DateTime start, DateTime end) {
    _start = dayOnly(start);
    _end = dayOnly(end);
    notifyListeners();
  }

  void clear() {
    _start = _end = null;
    notifyListeners();
  }

  LeavePlan? get plan {
    final a = _attendance;
    if (a == null || !hasRange) return null;
    return planLeave(
      engine: a.engine,
      start: _start!,
      end: _end!,
      current: a.allStats,
      overall: a.overall,
      rule: a.rule,
    );
  }

  List<LongWeekend> get longWeekends {
    final a = _attendance;
    if (a == null) return const [];
    return _weekends ??= LongWeekendFinder(
      a.engine,
    ).find(from: addDays(today(), 1), days: 60);
  }

  /// Opens a long-weekend suggestion in the leave planner.
  void planWeekend(LongWeekend w) {
    if (w.skipDays.isEmpty) {
      setRange(w.start, w.end);
    } else {
      setRange(w.skipDays.first, w.skipDays.last);
    }
  }
}
