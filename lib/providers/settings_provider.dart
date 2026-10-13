import 'package:flutter/material.dart';

import '../models/settings.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) : _settings = _storage.loadSettings();

  final StorageService _storage;
  AppSettings _settings;

  AppSettings get settings => _settings;
  AttendanceRule get rule => _settings.rule;
  int get target => _settings.targetPercent;
  ThemeMode get themeMode => _settings.themeMode;

  Future<void> update(AppSettings Function(AppSettings s) change) async {
    _settings = change(_settings);
    notifyListeners();
    await _storage.saveSettings(_settings);
  }

  Future<void> setRule(AttendanceRule r) => update((s) => s.copyWith(rule: r));
  Future<void> setTarget(int t) =>
      update((s) => s.copyWith(targetPercent: t.clamp(50, 100)));
  Future<void> setThemeMode(ThemeMode m) =>
      update((s) => s.copyWith(themeMode: m));
  Future<void> setAccent(int i) => update((s) => s.copyWith(accentIndex: i));
}
