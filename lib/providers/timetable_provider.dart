import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/subject.dart';
import '../models/timetable.dart';
import '../services/storage_service.dart';
import '../utils/dates.dart';

/// Subjects and the (versioned) weekly timetable.
class TimetableProvider extends ChangeNotifier {
  /// Bumped on every change, so dependants can tell a real change from a
  /// rebuild.
  int revision = 0;

  @override
  void notifyListeners() {
    revision++;
    super.notifyListeners();
  }

  TimetableProvider(this._storage)
    : _subjects = _storage.loadSubjects(),
      _versions = _storage.loadTimetables();

  final StorageService _storage;
  List<Subject> _subjects;
  List<TimetableVersion> _versions;

  List<Subject> get subjects => List.unmodifiable(_subjects);
  List<TimetableVersion> get versions => List.unmodifiable(_versions);

  Subject? subjectById(String id) {
    for (final s in _subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The latest timetable (what the editor shows).
  TimetableVersion? get current => _versions.isEmpty ? null : _versions.last;

  bool isCodeTaken(String code, {String? exceptId}) => _subjects.any(
    (s) =>
        s.id != exceptId && s.code.toLowerCase() == code.trim().toLowerCase(),
  );

  /// The first palette colour no other subject uses.
  int nextColorIndex(int paletteSize) {
    final used = _subjects.map((s) => s.colorIndex).toSet();
    for (var i = 0; i < paletteSize; i++) {
      if (!used.contains(i)) return i;
    }
    return _subjects.length % paletteSize;
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

  Future<void> saveSubject(Subject s) async {
    final i = _subjects.indexWhere((x) => x.id == s.id);
    if (i == -1) {
      _subjects = [..._subjects, s];
      await _storage.saveSubjectOrder(_subjects.map((x) => x.id).toList());
    } else {
      _subjects = [..._subjects]..[i] = s;
    }
    notifyListeners();
    await _storage.saveSubject(s);
  }

  Future<void> deleteSubject(String id) async {
    _subjects = _subjects.where((s) => s.id != id).toList();
    _versions = [for (final v in _versions) v.withoutSubject(id)];
    notifyListeners();
    await _storage.deleteSubject(id);
    await _storage.saveSubjectOrder(_subjects.map((x) => x.id).toList());
    for (final v in _versions) {
      await _storage.saveTimetable(v);
    }
  }

  Future<void> reorderSubjects(int oldIndex, int newIndex) async {
    final list = [..._subjects];
    final s = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, s);
    _subjects = list;
    notifyListeners();
    await _storage.saveSubjectOrder(list.map((x) => x.id).toList());
  }

  /// Saves [days] as the timetable from [from] onwards. Versions starting on
  /// or after [from] are replaced; earlier ones are kept for history.
  Future<void> saveTimetable(
    Map<int, List<Slot>> days, {
    required DateTime from,
  }) async {
    final start = dayOnly(from);
    final dropped = _versions
        .where((v) => !v.effectiveFrom.isBefore(start))
        .toList();
    _versions = [
      ..._versions.where((v) => v.effectiveFrom.isBefore(start)),
      TimetableVersion(effectiveFrom: start, days: days),
    ];
    notifyListeners();
    for (final v in dropped) {
      await _storage.deleteTimetable(v.effectiveFrom);
    }
    await _storage.saveTimetable(_versions.last);
  }

  /// Reloads from storage (after "New semester").
  void reload() {
    _subjects = _storage.loadSubjects();
    _versions = _storage.loadTimetables();
    notifyListeners();
  }
}
