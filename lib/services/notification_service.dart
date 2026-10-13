import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../utils/dates.dart';

/// The day-end "mark today's attendance" reminder.
///
/// Instead of one repeating notification (which would fire on holidays too),
/// we schedule one-off notifications for the next 7 working days and redo the
/// schedule whenever data changes. Today's is skipped once everything is
/// marked.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Called when a reminder is tapped (opens Today).
  VoidCallback? onOpen;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'day_end',
      'Day-end reminder',
      channelDescription: 'A nudge to mark the day’s attendance',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => onOpen?.call(),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted =
        await ios?.requestPermissions(alert: true, sound: true, badge: false) ??
        await android?.requestNotificationsPermission() ??
        false;
    return granted;
  }

  /// [unmarkedOn] returns how many periods are scheduled-but-unmarked on a
  /// day (0 for off days). Days returning 0 get no reminder.
  Future<void> reschedule({
    required bool enabled,
    required int minutesAfterMidnight,
    required int Function(DateTime day) unmarkedOn,
    required int Function(DateTime day) periodsOn,
  }) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!enabled) return;
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < 7; i++) {
      final day = addDays(today(), i);
      final when = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        minutesAfterMidnight ~/ 60,
        minutesAfterMidnight % 60,
      );
      if (!when.isAfter(now)) continue;
      // Today: only if something is still unmarked. Future days: if they have classes.
      final count = i == 0 ? unmarkedOn(day) : periodsOn(day);
      if (count == 0) continue;
      await _plugin.zonedSchedule(
        id: i,
        title: 'How did today go?',
        body: count == 1
            ? '1 class to mark. Takes two seconds.'
            : '$count classes to mark. Takes two seconds.',
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Fires one right away (Settings → "Send a test").
  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 99,
      title: 'How did today go?',
      body: 'This is what your day-end reminder looks like.',
      notificationDetails: _details,
    );
  }
}
