import 'package:flutter/material.dart';

import '../utils/dates.dart';

/// Whether the 75% (or whatever target) rule is applied to each subject
/// separately or to the total across all subjects.
enum AttendanceRule { eachSubject, overall }

class AppSettings {
  const AppSettings({
    this.onboarded = false,
    this.rule = AttendanceRule.eachSubject,
    this.targetPercent = 75,
    this.themeMode = ThemeMode.system,
    this.accentIndex = 0,
    this.reminderEnabled = true,
    this.reminderMinutes = 18 * 60,
    this.trackingStart,
    this.sundayClasses = false,
  });

  final bool onboarded;
  final AttendanceRule rule;

  /// Whole percent, 50–100.
  final int targetPercent;
  final ThemeMode themeMode;
  final int accentIndex;
  final bool reminderEnabled;

  /// Minutes after midnight for the day-end reminder.
  final int reminderMinutes;

  /// First day the app tracks; earlier attendance lives in subject baselines.
  final DateTime? trackingStart;

  final bool sundayClasses;

  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderMinutes ~/ 60, minute: reminderMinutes % 60);

  AppSettings copyWith({
    bool? onboarded,
    AttendanceRule? rule,
    int? targetPercent,
    ThemeMode? themeMode,
    int? accentIndex,
    bool? reminderEnabled,
    int? reminderMinutes,
    DateTime? trackingStart,
    bool? sundayClasses,
  }) => AppSettings(
    onboarded: onboarded ?? this.onboarded,
    rule: rule ?? this.rule,
    targetPercent: targetPercent ?? this.targetPercent,
    themeMode: themeMode ?? this.themeMode,
    accentIndex: accentIndex ?? this.accentIndex,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    trackingStart: trackingStart ?? this.trackingStart,
    sundayClasses: sundayClasses ?? this.sundayClasses,
  );

  Map<String, dynamic> toJson() => {
    'onboarded': onboarded,
    'rule': rule.name,
    'targetPercent': targetPercent,
    'themeMode': themeMode.name,
    'accentIndex': accentIndex,
    'reminderEnabled': reminderEnabled,
    'reminderMinutes': reminderMinutes,
    'trackingStart': trackingStart == null ? null : dayKey(trackingStart!),
    'sundayClasses': sundayClasses,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    onboarded: json['onboarded'] as bool? ?? false,
    rule: AttendanceRule.values.byName(
      json['rule'] as String? ?? 'eachSubject',
    ),
    targetPercent: json['targetPercent'] as int? ?? 75,
    themeMode: ThemeMode.values.byName(
      json['themeMode'] as String? ?? 'system',
    ),
    accentIndex: json['accentIndex'] as int? ?? 0,
    reminderEnabled: json['reminderEnabled'] as bool? ?? true,
    reminderMinutes: json['reminderMinutes'] as int? ?? 18 * 60,
    trackingStart: json['trackingStart'] == null
        ? null
        : parseDayKey(json['trackingStart'] as String),
    sundayClasses: json['sundayClasses'] as bool? ?? false,
  );
}
