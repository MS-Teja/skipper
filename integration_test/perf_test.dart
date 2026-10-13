import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:skipper/main.dart' as app;
import 'package:skipper/widgets/swipe_mark.dart';
import 'package:skipper/widgets/target_slider.dart';

/// A scripted tour of every interaction, for measuring frame times on a real
/// device (results land in build/perf.json):
///
/// flutter drive --profile --no-dds --dart-define=DEMO=true \
///   --driver=test_driver/perf_driver.dart \
///   --target=integration_test/perf_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  Future<void> wait(int ms) => Future.delayed(Duration(milliseconds: ms));

  testWidgets('smoothness tour', (tester) async {
    app.main();
    for (
      var i = 0;
      i < 40 && find.byKey(const ValueKey('tab-0')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await wait(2500);

    NavigatorState nav() =>
        tester.state<NavigatorState>(find.byType(Navigator).first);

    Future<void> tab(int i) async {
      await tester.tap(find.byKey(ValueKey('tab-$i')));
      await wait(700);
    }

    Future<void> tapText(String text) async {
      await tester.ensureVisible(find.text(text).first);
      await wait(300);
      await tester.tap(find.text(text).first);
      await wait(900);
    }

    Future<void> back() async {
      nav().pop();
      await wait(800);
    }

    Future<void> scroll() async {
      final list = find.byType(Scrollable).first;
      for (var k = 0; k < 2; k++) {
        await tester.timedDrag(
          list,
          const Offset(0, -420),
          const Duration(milliseconds: 260),
        );
        await wait(700);
        await tester.timedDrag(
          list,
          const Offset(0, 420),
          const Duration(milliseconds: 260),
        );
        await wait(700);
      }
    }

    Future<void> measure(String key, Future<void> Function() action) =>
        binding.watchPerformance(action, reportKey: key);

    // --- Today
    await measure('today_scroll', scroll);
    await measure('mark', () async {
      final dots = find.bySemanticsLabel(RegExp(r'^Period 1'));
      for (var k = 0; k < 6 && dots.evaluate().isNotEmpty; k++) {
        await tester.tap(dots.first);
        await wait(450);
      }
    });
    await measure('swipe_card', () async {
      for (final dx in [160.0, -160.0, 160.0]) {
        await tester.timedDrag(
          find.byType(SwipeToMark).first,
          Offset(dx, 0),
          const Duration(milliseconds: 300),
        );
        await wait(800);
      }
    });
    await measure('week_strip', () async {
      for (final day in ['Mon', 'Tue', 'Wed']) {
        final f = find.bySemanticsLabel(RegExp('^$day '));
        if (f.evaluate().isEmpty) continue;
        await tester.tap(f.first);
        await wait(600);
      }
    });
    await measure('sheets', () async {
      await tapText('Add extra class');
      await back();
      // Has an autofocused field, so the real keyboard comes up.
      await tapText('Mark holiday');
      await wait(600);
      await back();
    });
    await measure('pending', () async {
      await tapText('Review');
      await scroll();
      await back();
    });

    // --- Tabs
    await measure('tabs', () async {
      for (var k = 0; k < 2; k++) {
        await tab(1);
        await tab(2);
        await tab(3);
        await tab(0);
      }
    });
    await tab(2);
    await measure('planner_scroll', scroll);
    await tab(1);
    await measure('attendance_scroll', scroll);
    await measure('detail', () async {
      for (var k = 0; k < 2; k++) {
        await tapText('Operating Systems');
        await back();
      }
    });
    await measure('subject_form', () async {
      await tester.tap(find.byTooltip('Add subject').first);
      await wait(900);
      await tester.enterText(find.byType(TextFormField).first, 'Compilers');
      await wait(900);
      await back();
      await wait(400);
    });

    // --- Settings
    await tab(3);
    await measure('slider', () async {
      final slider = find.byType(TargetSlider).first;
      for (final dx in [-90.0, 140.0, -50.0]) {
        await tester.timedDrag(
          slider,
          Offset(dx, 0),
          const Duration(milliseconds: 500),
        );
        await wait(700);
      }
    });
    await measure('toggles', () async {
      for (var k = 0; k < 2; k++) {
        await tapText('Classes on Sundays');
      }
      await tapText('Dark');
      await wait(400);
      await tapText('Auto');
      await wait(400);
    });
    await measure('holidays', () async {
      await tapText('Holidays');
      await wait(600);
      await scroll();
      await back();
    });
    await measure('timetable', () async {
      await tapText('Timetable');
      for (final d in ['Tue', 'Wed', 'Thu', 'Mon']) {
        await tapText(d);
      }
      await tester.tap(find.byTooltip('More').first);
      await wait(500);
      await tester.tap(find.byTooltip('Fewer').first);
      await wait(500);
      await back();
      // A "discard changes?" dialog may appear.
      if (find.text('Discard').evaluate().isNotEmpty) {
        await tapText('Discard');
      }
    });
  });
}
