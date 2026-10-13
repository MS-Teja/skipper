import 'package:flutter/material.dart';

import '../services/attendance_math.dart';
import 'chunky.dart';

/// The one-line verdict for a subject or the overall total.
String statusLabel(AttendanceStats s, {bool long = false}) {
  if (!s.hasClasses) return long ? 'No classes yet' : 'New';
  final need = s.toRecover;
  if (need == null) {
    return long ? "Can't reach ${s.target}% any more" : 'Out of reach';
  }
  if (need > 0) {
    return long
        ? 'Attend the next ${plural(need, 'class', 'classes')} to get back to ${s.target}%.'
        : 'Attend $need';
  }
  if (s.canSkip == 0) {
    return long
        ? 'Exactly on ${s.target}%. Don’t skip the next one.'
        : 'No skips';
  }
  return long
      ? 'You can skip ${plural(s.canSkip, 'class', 'classes')} and stay above ${s.target}%.'
      : 'Skip ${s.canSkip}';
}

/// The mid-length verdict for list rows, e.g. "Attend the next 9".
String statusLine(AttendanceStats s) {
  if (!s.hasClasses) return 'No classes yet';
  final need = s.toRecover;
  if (need == null) return 'Can’t reach ${s.target}% now';
  if (need > 0) return 'Attend the next $need';
  if (s.canSkip == 0) return 'No skips left';
  return 'Can skip ${s.canSkip}';
}

String percentText(AttendanceStats s) =>
    s.hasClasses ? '${s.percentFloor}%' : '–';

String plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// Status pill in the moment palette.
class StatusPill extends StatelessWidget {
  const StatusPill(this.stats, {super.key, this.dense = false});
  final AttendanceStats stats;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final danger = stats.hasClasses && !stats.isAtOrAboveTarget;
    final edge = stats.hasClasses && !danger && stats.canSkip == 0;
    final (bg, fg) = pillColors(context, danger: danger, edge: edge);
    return Pill(
      statusLabel(stats),
      background: bg,
      foreground: fg,
      dense: dense,
    );
  }
}
