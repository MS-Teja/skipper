import 'dart:math';

import 'package:skipper/services/attendance_math.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ground truth: literally miss one class at a time until we drop below.
int bruteSkip(int a, int c, int t) {
  var k = 0;
  while (100 * a >= t * (c + k + 1)) {
    k++;
  }
  return k;
}

/// Ground truth: literally attend one class at a time until we reach target.
int? bruteRecover(int a, int c, int t) {
  if (t >= 100 && a < c) return null;
  var n = 0;
  while (100 * (a + n) < t * (c + n)) {
    n++;
  }
  return n;
}

void main() {
  group('hand-calculated cases', () {
    // attended, conducted, target, expected skip, expected recover
    final cases = <(int, int, int, int, int?)>[
      (32, 40, 75, 2, 0), // 32/42 = 76.2% ok, 32/43 = 74.4% not
      (27, 37, 75, 0, 3), // 30/40 = 75.0% ok, 29/39 = 74.4% not
      (30, 40, 75, 0, 0), // exactly on target
      (0, 1, 75, 0, 3), // 3/4 = 75%
      (15, 20, 80, 0, 5), // 20/25 = 80%, 19/24 = 79.2%
      (45, 50, 85, 2, 0), // 45/52 = 86.5%, 45/53 = 84.9%
      (154, 195, 75, 10, 0), // 154/205 = 75.1%, 154/206 = 74.8%
      (9, 10, 100, 0, null), // can never get back to 100%
      (0, 0, 75, 0, 0), // no classes yet
    ];
    for (final (a, c, t, skip, recover) in cases) {
      test('$a/$c at $t%', () {
        final s = AttendanceStats(attended: a, conducted: c, target: t);
        expect(s.canSkip, skip);
        expect(s.toRecover, recover);
      });
    }
  });

  test(
    'matches brute force for every case up to 120 classes, targets 50–100%',
    () {
      var checked = 0;
      for (var t = 50; t <= 100; t++) {
        for (var c = 0; c <= 120; c++) {
          for (var a = 0; a <= c; a++) {
            expect(
              skipsAllowed(a, c, t),
              bruteSkip(a, c, t),
              reason: 'skip $a/$c @$t',
            );
            expect(
              classesToRecover(a, c, t),
              bruteRecover(a, c, t),
              reason: 'recover $a/$c @$t',
            );
            checked++;
          }
        }
      }
      expect(checked, 376431);
    },
  );

  test(
    'simulated semesters: skipping/attending the suggested number works',
    () {
      final rng = Random(7);
      const targets = [65, 70, 75, 80, 85, 90];
      for (var trial = 0; trial < 2000; trial++) {
        final t = targets[rng.nextInt(targets.length)];
        final attended = List.filled(6, 0), conducted = List.filled(6, 0);
        // A random weekly timetable: subject index -> periods, per weekday.
        final week = List.generate(
          6,
          (_) => List.generate(
            2 + rng.nextInt(4),
            (_) => (rng.nextInt(6), 1 + rng.nextInt(3)),
          ),
        );
        final pAttend = 0.5 + rng.nextDouble() * 0.49;
        final days = 10 + rng.nextInt(110);
        for (var day = 0; day < days; day++) {
          if (rng.nextDouble() < 0.05) continue; // holiday
          for (final (subject, periods) in week[day % 6]) {
            for (var p = 0; p < periods; p++) {
              if (rng.nextDouble() < 0.03) continue; // cancelled period
              conducted[subject]++;
              if (rng.nextDouble() < pAttend) attended[subject]++;
            }
          }
        }
        final pools = [
          for (var i = 0; i < 6; i++) (attended[i], conducted[i]),
          (attended.reduce((x, y) => x + y), conducted.reduce((x, y) => x + y)),
        ];
        for (final (a, c) in pools) {
          if (c == 0) continue;
          final s = AttendanceStats(attended: a, conducted: c, target: t);
          if (s.isAtOrAboveTarget) {
            expect(s.afterSkipping(s.canSkip).isAtOrAboveTarget, isTrue);
            expect(s.afterSkipping(s.canSkip + 1).isAtOrAboveTarget, isFalse);
          } else {
            final n = s.toRecover!;
            expect(s.afterAttending(n).isAtOrAboveTarget, isTrue);
            expect(s.afterAttending(n - 1).isAtOrAboveTarget, isFalse);
          }
        }
      }
    },
  );

  test('display percent is rounded down, never up into safety', () {
    // 299/400 = 74.75% must not show as 75.
    final s = AttendanceStats(attended: 299, conducted: 400, target: 75);
    expect(s.percentFloor, 74);
    expect(s.percentOneDecimal, 74.7);
    expect(s.risk, Risk.danger);
  });

  test('risk levels', () {
    expect(
      const AttendanceStats(attended: 32, conducted: 40, target: 75).risk,
      Risk.safe,
    );
    expect(
      const AttendanceStats(attended: 30, conducted: 40, target: 75).risk,
      Risk.edge,
    );
    expect(
      const AttendanceStats(attended: 27, conducted: 37, target: 75).risk,
      Risk.danger,
    );
  });
}
