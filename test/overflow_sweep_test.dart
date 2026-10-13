import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skipper/app_router.dart';
import 'package:skipper/main.dart';
import 'package:skipper/providers/attendance_provider.dart';
import 'package:skipper/providers/settings_provider.dart';
import 'package:skipper/screens/holidays/holidays_screen.dart';
import 'package:skipper/screens/today/day_sheets.dart';
import 'package:skipper/services/demo_data.dart';
import 'package:skipper/services/holiday_api_service.dart';
import 'package:skipper/services/notification_service.dart';
import 'package:skipper/services/storage_service.dart';
import 'package:skipper/utils/dates.dart';
import 'package:skipper/widgets/pickers.dart';
import 'package:provider/provider.dart';

/// Renders every screen and sheet with the sample semester on small, normal
/// and wide phones, at normal and large text, with and without the keyboard
/// up, and fails on any layout overflow.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final storage = StorageService();

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('skipper_sweep');
    await storage.init(path: dir.path);
    await seedDemoSemester(storage, storage.loadSettings());
    // Real fonts: the default test font draws every glyph 1em wide, which
    // would report overflows that never happen on a phone.
    for (final (family, file) in [
      ('Geist', 'assets/fonts/Geist.ttf'),
      ('Bricolage', 'assets/fonts/BricolageGrotesque.ttf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(file))).load();
    }
  });

  const sizes = [
    ('small Android', Size(360, 640)),
    ('iPhone 16 Pro', Size(402, 874)),
    ('wide Android', Size(508, 1129)),
  ];
  const scales = [1.0, 1.3];

  for (final (name, size) in sizes) {
    for (final scale in scales) {
      testWidgets('no overflow: $name @ ${scale}x text', (tester) async {
        final problems = <String>[];
        var where = 'start';
        void collect() {
          for (Object? e; (e = tester.takeException()) != null;) {
            problems.add('[$where] ${e.toString().split('\n').first}');
          }
        }

        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = size * 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        Future<void> settle() async {
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 150));
            collect();
          }
        }

        Future<void> keyboard(bool up) async {
          tester.view.viewInsets = up
              ? const FakeViewPadding(bottom: 320 * 3)
              : FakeViewPadding.zero;
          await settle();
        }

        // Start from the main app even if an earlier case failed mid-way.
        await tester.runAsync(
          () => storage.saveSettings(
            storage.loadSettings().copyWith(onboarded: true),
          ),
        );
        await tester.pumpWidget(
          SkipperApp(
            storage: storage,
            notifications: _FakeNotifications(),
            api: HolidayApiService(
              client: MockClient((_) async => http.Response(_ics, 200)),
            ),
          ),
        );
        where = 'Today';
        await settle();

        final nav = navigatorKey.currentState!;
        BuildContext ctx() => nav.context;

        for (final (i, tab) in [
          (1, 'Attendance'),
          (2, 'Planner'),
          (0, 'Today'),
        ]) {
          where = tab;
          await tester.tap(find.byKey(ValueKey('tab-$i')));
          await settle();
        }

        for (final (route, arg, label) in [
          (Routes.detail, 'os', 'Detail'),
          (Routes.detail, null, 'Overall'),
          (Routes.settings, null, 'Settings'),
          (Routes.timetable, null, 'Timetable'),
          (Routes.holidays, 0, 'Holidays'),
          (Routes.holidays, 1, 'Breaks'),
          (Routes.pending, null, 'Pending'),
          (Routes.subjectForm, null, 'New subject'),
          (Routes.subjectForm, 'daa', 'Edit subject'),
        ]) {
          where = label;
          nav.pushNamed(route, arguments: arg);
          await settle();
          if (route == Routes.subjectForm) {
            where = '$label + keyboard';
            await keyboard(true);
            await keyboard(false);
          }
          nav.pop();
          await settle();
        }

        final day = today();
        final entry = ctx().read<AttendanceProvider>().classesOn(day);
        final sheets = <(String, void Function())>[
          ('Holiday sheet', () => showHolidaySheet(ctx(), day)),
          ('Extra class sheet', () => showExtraClassSheet(ctx(), day)),
          ('Break sheet', () => showBreakSheet(ctx())),
          (
            'Date picker',
            () => pickDate(
              ctx(),
              initial: day,
              first: day,
              last: addDays(day, 60),
            ),
          ),
          (
            'Range picker',
            () => pickDateRange(ctx(), first: day, last: addDays(day, 60)),
          ),
          (
            'Time picker',
            () =>
                pickTime(ctx(), initial: const TimeOfDay(hour: 18, minute: 0)),
          ),
          if (entry.isNotEmpty)
            ('Class sheet', () => showClassSheet(ctx(), day, entry.first)),
        ];
        for (final (label, open) in sheets) {
          where = label;
          open();
          await settle();
          where = '$label + keyboard';
          await keyboard(true);
          await keyboard(false);
          nav.pop();
          await settle();
        }

        // Onboarding, step by step (Hive writes need real async).
        final sp = ctx().read<SettingsProvider>();
        await tester.runAsync(
          () => sp.update((s) => s.copyWith(onboarded: false)),
        );
        where = 'Welcome';
        await settle();
        await tester.ensureVisible(find.text('Set up in a minute'));
        await settle();
        await tester.tap(find.text('Set up in a minute'));
        await settle();
        for (var step = 1; step <= 5; step++) {
          where = 'Onboarding step $step';
          await settle();
          if (step == 4) {
            where = 'Onboarding step $step + keyboard';
            await keyboard(true);
            await keyboard(false);
          }
          if (step < 5) {
            await tester.tap(find.text('Continue'));
            await settle();
          }
        }
        await tester.runAsync(
          () => sp.update((s) => s.copyWith(onboarded: true)),
        );
        await settle();

        await tester.pumpWidget(const SizedBox());
        expect(problems, isEmpty, reason: problems.toSet().join('\n'));
      });
    }
  }
}

class _FakeNotifications extends NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> reschedule({
    required bool enabled,
    required int minutesAfterMidnight,
    required int Function(DateTime day) unmarkedOn,
    required int Function(DateTime day) periodsOn,
  }) async {}

  @override
  Future<void> showTest() async {}
}

const _ics = '''BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART;VALUE=DATE:20261020
DESCRIPTION:Public holiday
SUMMARY:Dussehra
END:VEVENT
END:VCALENDAR
''';
