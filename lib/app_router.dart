import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'screens/attendance/detail_screen.dart';
import 'screens/holidays/holidays_screen.dart';
import 'screens/pending/pending_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/subjects/subject_form_screen.dart';
import 'screens/timetable/timetable_screen.dart';

/// Named routes. Arguments are passed through `RouteSettings.arguments`.
abstract final class Routes {
  /// Optional `String` subject id (edit) — null to create.
  static const subjectForm = '/subject';

  /// Optional `String` subject id — null for overall.
  static const detail = '/detail';
  static const timetable = '/timetable';
  static const holidays = '/holidays';
  static const settings = '/settings';
  static const pending = '/pending';
}

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  final arg = settings.arguments;
  final Widget? page = switch (settings.name) {
    Routes.subjectForm => SubjectFormScreen(subjectId: arg as String?),
    Routes.detail => DetailScreen(subjectId: arg as String?),
    Routes.timetable => const TimetableScreen(),
    Routes.holidays => HolidaysScreen(initialTab: arg as int? ?? 0),
    Routes.settings => const SettingsScreen(),
    Routes.pending => const PendingScreen(),
    _ => null,
  };
  if (page == null) return null;
  // Tasks rise as an iOS card sheet (the page behind scales back, drag down
  // to dismiss); everything else pushes from the right.
  if (settings.name == Routes.subjectForm) {
    return CupertinoSheetRoute(builder: (_) => page, settings: settings);
  }
  return MaterialPageRoute(builder: (_) => page, settings: settings);
}
