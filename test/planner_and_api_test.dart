import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:skipper/models/settings.dart';
import 'package:skipper/models/timetable.dart';
import 'package:skipper/services/attendance_math.dart';
import 'package:skipper/services/holiday_api_service.dart';
import 'package:skipper/services/leave_planner.dart';
import 'package:skipper/services/schedule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime oct(int day) => DateTime(2026, 10, day);

void main() {
  group('Leave planner', () {
    final engine = ScheduleEngine(
      versions: [
        TimetableVersion(
          effectiveFrom: oct(1),
          days: {
            1: const [
              Slot(subjectId: 'OS', periods: 2),
              Slot(subjectId: 'DBMS', periods: 1),
            ],
            2: const [Slot(subjectId: 'OS', periods: 2)],
            3: const [Slot(subjectId: 'DBMS', periods: 2)],
            4: const [Slot(subjectId: 'OS', periods: 1)],
            5: const [Slot(subjectId: 'DBMS', periods: 1)],
          },
        ),
      ],
      holidays: const [],
      breaks: const [],
      extras: const [],
      records: const {},
      trackingStart: oct(1),
    );
    final current = {
      'OS': const AttendanceStats(
        attended: 30,
        conducted: 37,
        target: 75,
      ), // 81%
      'DBMS': const AttendanceStats(
        attended: 32,
        conducted: 40,
        target: 75,
      ), // 80%
    };
    const overall = AttendanceStats(attended: 62, conducted: 77, target: 75);

    test('prices a Mon–Tue leave from the timetable', () {
      final plan = planLeave(
        engine: engine,
        start: oct(12),
        end: oct(13),
        current: current,
        overall: overall,
        rule: AttendanceRule.eachSubject,
      );
      final os = plan.subjects.firstWhere((i) => i.subjectId == 'OS');
      final dbms = plan.subjects.firstWhere((i) => i.subjectId == 'DBMS');
      expect(os.missed, 4); // Mon 2 + Tue 2
      expect(dbms.missed, 1); // Mon 1
      expect(os.after.percentFloor, 73); // 30/41
      expect(os.staysSafe, isFalse);
      expect(os.extraNeeded, 3); // 33/44 = 75%
      expect(dbms.staysSafe, isTrue); // 32/41 = 78%
      expect(plan.isSafe, isFalse);
      expect(plan.atRisk.single.subjectId, 'OS');
    });

    test('overall rule judges only the total', () {
      final plan = planLeave(
        engine: engine,
        start: oct(12),
        end: oct(13),
        current: current,
        overall: overall,
        rule: AttendanceRule.overall,
      );
      expect(plan.overall.missed, 5);
      expect(plan.overall.after.percentFloor, 75); // 62/82 = 75.6%
      expect(plan.isSafe, isTrue);
    });

    test('a weekend costs nothing', () {
      final plan = planLeave(
        engine: engine,
        start: oct(10),
        end: oct(11),
        current: current,
        overall: overall,
        rule: AttendanceRule.eachSubject,
      );
      expect(plan.totalMissed, 0);
      expect(plan.isSafe, isTrue);
    });
  });

  group('Holiday feed parsing', () {
    // Trimmed from the real feed: CRLF endings, a folded DESCRIPTION line,
    // an escaped comma, a duplicate and an event outside the years asked for.
    const body =
        'BEGIN:VCALENDAR\r\n'
        'X-WR-CALNAME:Holidays in India\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20261002\r\n'
        'DESCRIPTION:Public holiday\r\n'
        'SUMMARY:Mahatma Gandhi Jayanti\r\n'
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20261020\r\n'
        'DESCRIPTION:Observance\\nTo hide observances\\, go to Google Calendar Setting\r\n'
        ' s > Holidays in India\r\n'
        'SUMMARY:Maha Navami\\, Durga Puja\r\n'
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20261002\r\n'
        'DESCRIPTION:Public holiday\r\n'
        'SUMMARY:Mahatma Gandhi Jayanti\r\n'
        'END:VEVENT\r\n'
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20211002\r\n'
        'DESCRIPTION:Public holiday\r\n'
        'SUMMARY:Mahatma Gandhi Jayanti\r\n'
        'END:VEVENT\r\n'
        'END:VCALENDAR\r\n';

    test('keeps events in the asked years, de-duplicated and sorted', () {
      final list = HolidayApiService.parse(body, years: {2026, 2027});
      expect(list.map((h) => h.date), [oct(2), oct(20)]);
      expect(list.first.applied, isFalse); // the provider decides defaults
    });

    test('unfolds lines and unescapes text', () {
      final list = HolidayApiService.parse(body, years: {2026});
      expect(list.first.type, 'Public holiday');
      expect(list.last.name, 'Maha Navami, Durga Puja');
      expect(list.last.type, 'Observance');
    });

    test('a body that is not iCal raises badData', () {
      expect(
        () => HolidayApiService.parse('<html>oops</html>', years: {2026}),
        throwsA(
          isA<HolidayApiException>().having(
            (e) => e.kind,
            'kind',
            HolidayApiError.badData,
          ),
        ),
      );
    });

    test('fetchRaw returns the body on 200 and maps errors', () async {
      final ok = HolidayApiService(
        client: MockClient((req) async {
          expect(req.url, HolidayApiService.uri);
          return http.Response(body, 200);
        }),
      );
      expect(await ok.fetchRaw(), body);

      final down = HolidayApiService(
        client: MockClient((_) async => http.Response('', 503)),
      );
      await expectLater(
        down.fetchRaw(),
        throwsA(
          isA<HolidayApiException>().having(
            (e) => e.kind,
            'kind',
            HolidayApiError.server,
          ),
        ),
      );

      final offline = HolidayApiService(
        client: MockClient((_) => throw http.ClientException('no network')),
      );
      await expectLater(
        offline.fetchRaw(),
        throwsA(
          isA<HolidayApiException>().having(
            (e) => e.kind,
            'kind',
            HolidayApiError.offline,
          ),
        ),
      );
    });
  });
}
