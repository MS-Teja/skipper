import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/holiday.dart';

enum HolidayApiError { offline, server, badData }

class HolidayApiException implements Exception {
  const HolidayApiException(this.kind, [this.detail]);
  final HolidayApiError kind;
  final String? detail;

  String get message => switch (kind) {
    HolidayApiError.offline =>
      'You seem to be offline. Check your connection and try again.',
    HolidayApiError.server =>
      'The holiday service is having trouble. Try again in a bit.',
    HolidayApiError.badData =>
      'Got an unexpected response from the holiday service.',
  };

  @override
  String toString() => 'HolidayApiException($kind, $detail)';
}

/// Fetches Indian public holidays from Google's public holiday calendar.
/// No API key needed; the response is an iCalendar (RFC 5545) feed.
///
/// `GET https://calendar.google.com/calendar/ical/en.indian%23holiday%40group.v.calendar.google.com/public/basic.ics`
class HolidayApiService {
  HolidayApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static final uri = Uri.parse(
    'https://calendar.google.com/calendar/ical/'
    'en.indian%23holiday%40group.v.calendar.google.com/public/basic.ics',
  );

  /// Raw feed body (cached by the caller).
  Future<String> fetchRaw() async {
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(const Duration(seconds: 12));
    } on SocketException catch (e) {
      throw HolidayApiException(HolidayApiError.offline, e.message);
    } on TimeoutException {
      throw const HolidayApiException(HolidayApiError.offline, 'timeout');
    } on http.ClientException catch (e) {
      throw HolidayApiException(HolidayApiError.offline, e.message);
    }
    if (res.statusCode != 200) {
      throw HolidayApiException(
        HolidayApiError.server,
        'HTTP ${res.statusCode}',
      );
    }
    return res.body;
  }

  /// Parses the feed, keeping events in [years]. The first line of each
  /// event's description is its type: "Public holiday" or "Observance".
  static List<Holiday> parse(String body, {required Set<int> years}) {
    if (!body.trimLeft().startsWith('BEGIN:VCALENDAR')) {
      throw const HolidayApiException(HolidayApiError.badData, 'not iCal');
    }
    // Long lines are folded onto the next line with a leading space.
    final lines = body
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\n[ \t]'), '')
        .split('\n');

    final out = <String, Holiday>{};
    Map<String, String>? event;
    for (final line in lines) {
      if (line == 'BEGIN:VEVENT') {
        event = {};
      } else if (line == 'END:VEVENT') {
        final h = _toHoliday(event!);
        if (h != null && years.contains(h.date.year)) {
          out.putIfAbsent(h.key, () => h);
        }
        event = null;
      } else if (event != null) {
        final colon = line.indexOf(':');
        if (colon <= 0) continue;
        // "DTSTART;VALUE=DATE" → "DTSTART"
        final name = line.substring(0, colon).split(';').first;
        event[name] = line.substring(colon + 1);
      }
    }
    return out.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  static Holiday? _toHoliday(Map<String, String> e) {
    final start = e['DTSTART'];
    final name = e['SUMMARY'];
    if (start == null || name == null || start.length < 8) return null;
    final y = int.tryParse(start.substring(0, 4));
    final m = int.tryParse(start.substring(4, 6));
    final d = int.tryParse(start.substring(6, 8));
    if (y == null || m == null || d == null) return null;
    final type = _unescape(e['DESCRIPTION'] ?? '').split('\n').first.trim();
    return Holiday(
      date: DateTime(y, m, d),
      name: _unescape(name).trim(),
      source: HolidaySource.api,
      applied: false,
      type: type.isEmpty ? null : type,
    );
  }

  static String _unescape(String s) => s.replaceAllMapped(
    RegExp(r'\\([\\;,nN])'),
    (m) => switch (m[1]) {
      'n' || 'N' => '\n',
      final c => c!,
    },
  );
}
