import 'dart:io';

import 'package:skipper/providers/settings_provider.dart';
import 'package:skipper/providers/timetable_provider.dart';
import 'package:skipper/screens/subjects/subject_form_screen.dart';
import 'package:skipper/services/storage_service.dart';
import 'package:skipper/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // Hive needs real async I/O, so open it outside the widget test's fake zone.
  final storage = StorageService();
  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('skipper_test');
    await storage.init(path: dir.path);
  });

  group('SubjectValidators', () {
    test('name', () {
      expect(SubjectValidators.name(''), isNotNull);
      expect(SubjectValidators.name(' A '), isNotNull);
      expect(SubjectValidators.name('Operating Systems'), isNull);
      expect(SubjectValidators.name('x' * 41), isNotNull);
    });

    test('code: required, short, alphanumeric, unique', () {
      bool none(String _) => false;
      expect(SubjectValidators.code('', isTaken: none), isNotNull);
      expect(SubjectValidators.code('TOOLONG', isTaken: none), isNotNull);
      expect(SubjectValidators.code('O\$!', isTaken: none), isNotNull);
      expect(SubjectValidators.code('OS LAB', isTaken: none), isNull);
      expect(
        SubjectValidators.code('DBMS', isTaken: (c) => c == 'DBMS'),
        contains('already'),
      );
    });

    test('attended can’t exceed held', () {
      expect(SubjectValidators.attendedVsConducted('18', '22'), isNull);
      expect(SubjectValidators.attendedVsConducted('23', '22'), isNotNull);
      expect(SubjectValidators.attendedVsConducted('', ''), isNull);
      expect(SubjectValidators.count('abc'), isNotNull);
      expect(SubjectValidators.count('1000'), isNotNull);
    });

    test('code suggestion from the name', () {
      expect(
        SubjectValidators.suggestCode('Database Management Systems'),
        'DMS',
      );
      expect(
        SubjectValidators.suggestCode('Design and Analysis of Algorithms'),
        'DAA',
      );
      expect(SubjectValidators.suggestCode('Physics'), 'PHYS');
    });
  });

  testWidgets('form shows errors and refuses to save invalid input', (
    tester,
  ) async {
    // A blinking cursor would keep pumpAndSettle waiting forever.
    EditableText.debugDeterministicCursor = true;
    tester.view.physicalSize = const Size(1290, 2796); // iPhone-sized
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(() => EditableText.debugDeterministicCursor = false);
    final timetable = TimetableProvider(storage);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
          ChangeNotifierProvider.value(value: timetable),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light, 0),
          home: const SubjectFormScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // Attended more than held.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Attended'),
      '30',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Held'), '20');
    await tester.ensureVisible(find.text('Add subject'));
    await tester.tap(find.text('Add subject'));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Enter the subject name'), findsOneWidget);
    expect(find.text('Can’t attend more than were held'), findsOneWidget);
    expect(timetable.subjects, isEmpty);

    // Typing a name suggests a code, then it saves.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Subject name'),
      'Operating Systems',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Attended'),
      '18',
    );
    await tester.pump(const Duration(seconds: 1));
    final codeField = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Short code'),
        matching: find.byType(EditableText),
      ),
    );
    expect(codeField.controller.text, 'OS');
    await tester.ensureVisible(find.text('Add subject'));
    await tester.tap(find.text('Add subject'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(timetable.subjects.single.code, 'OS');
    expect(timetable.subjects.single.baselineAttended, 18);
    expect(timetable.subjects.single.baselineConducted, 20);
  });
}
