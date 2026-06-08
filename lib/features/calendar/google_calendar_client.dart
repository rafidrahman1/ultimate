import 'dart:async';
import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;

import 'package:personal/core/period_range.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_event.dart';

const calendarReadonlyScope = gcal.CalendarApi.calendarReadonlyScope;
const _calendarScopes = googleCalendarScopes;

/// Google public holiday calendars for Bangladesh (official first).
const bangladeshHolidayCalendarIds = [
  'en.bd.official#holiday@group.v.calendar.google.com',
  'en.bd#holiday@group.v.calendar.google.com',
];

class GoogleCalendarClient {
  GoogleCalendarClient({GoogleAccountService? accountService})
    : _accountService = accountService ?? GoogleAccountService();

  final GoogleAccountService _accountService;

  Future<void> signOut() => _accountService.signOut();

  Future<CalendarSyncResult> fetchPrimaryCalendarEvents({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    bool interactiveSignIn = false,
  }) async {
    final account = await _accountService.resolveSessionAccount(
      interactive: interactiveSignIn,
    );
    if (account == null) {
      throw const FormatException(
        'Google account not connected. Open Google account settings and sign in.',
      );
    }

    var authorization = await account.authorizationClient.authorizationForScopes(
      _calendarScopes,
    );

    if (authorization == null && interactiveSignIn) {
      authorization = await account.authorizationClient.authorizeScopes(
        _calendarScopes,
      );
    }

    if (authorization == null) {
      throw const FormatException(
        'Calendar access was not granted. Connect again and allow calendar read access.',
      );
    }

    final client = authorization.authClient(scopes: _calendarScopes);
    try {
      final api = gcal.CalendarApi(client);
      final personal = await _listEvents(
        api,
        calendarId: 'primary',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
      final holidays = await _fetchBangladeshHolidays(
        api,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );

      final displayName = await _resolveDisplayName(
        account,
        interactiveSignIn: interactiveSignIn,
      );

      return CalendarSyncResult(
        events: mergeCalendarEvents(personal, holidays),
        accountEmail: account.email,
        accountDisplayName: displayName,
        accountPhotoUrl: account.photoUrl,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    } finally {
      client.close();
    }
  }

  Future<List<CalendarEvent>> _fetchBangladeshHolidays(
    gcal.CalendarApi api, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    for (final calendarId in bangladeshHolidayCalendarIds) {
      try {
        final events = await _listEvents(
          api,
          calendarId: calendarId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          isHoliday: true,
        );
        if (events.isNotEmpty) return events;
      } on gcal.DetailedApiRequestError catch (e) {
        if (e.status == 404) continue;
        rethrow;
      }
    }
    return const [];
  }

  Future<String?> _resolveDisplayName(
    GoogleSignInAccount account, {
    required bool interactiveSignIn,
  }) async {
    final direct = account.displayName?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final fromIdToken = _nameFromIdToken(account.authentication.idToken);
    if (fromIdToken != null && fromIdToken.isNotEmpty) return fromIdToken;

    return _fetchUserInfoName(
      account,
      interactiveSignIn: interactiveSignIn,
    );
  }

  Future<String?> _fetchUserInfoName(
    GoogleSignInAccount account, {
    required bool interactiveSignIn,
  }) async {
    try {
      var authorization = await account.authorizationClient.authorizationForScopes(
        googleProfileScopes,
      );
      if (authorization == null && interactiveSignIn) {
        authorization = await account.authorizationClient.authorizeScopes(
          googleProfileScopes,
        );
      }
      if (authorization == null) return null;

      final response = await http.get(
        Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
        headers: {'Authorization': 'Bearer ${authorization.accessToken}'},
      );
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['name'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  Future<List<CalendarEvent>> _listEvents(
    gcal.CalendarApi api, {
    required String calendarId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    bool isHoliday = false,
  }) async {
    final response = await api.events.list(
      calendarId,
      timeMin: rangeStart.toUtc(),
      timeMax: rangeEnd.toUtc(),
      singleEvents: true,
      orderBy: 'startTime',
      maxResults: 250,
    );

    return (response.items ?? [])
        .map((event) => _mapEvent(event, isHoliday: isHoliday))
        .whereType<CalendarEvent>()
        .toList();
  }
}

/// Merges personal and holiday events, deduping same title on the same day.
List<CalendarEvent> mergeCalendarEvents(
  List<CalendarEvent> personal,
  List<CalendarEvent> holidays,
) {
  final merged = [...personal, ...holidays];
  merged.sort((a, b) => a.start.compareTo(b.start));

  final seen = <String>{};
  final unique = <CalendarEvent>[];
  for (final event in merged) {
    final key =
        '${_dayKey(event.start)}|${event.title.trim().toLowerCase()}';
    if (seen.add(key)) {
      unique.add(event);
      continue;
    }
    // Prefer the personal copy over a duplicate holiday entry.
    final index = unique.indexWhere(
      (e) =>
          _dayKey(e.start) == _dayKey(event.start) &&
          e.title.trim().toLowerCase() == event.title.trim().toLowerCase(),
    );
    if (index >= 0 && unique[index].isHoliday && !event.isHoliday) {
      unique[index] = event;
    }
  }
  return unique;
}

String _dayKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month}-${local.day}';
}

class CalendarSyncResult {
  const CalendarSyncResult({
    required this.events,
    required this.accountEmail,
    this.accountDisplayName,
    this.accountPhotoUrl,
    required this.rangeStart,
    required this.rangeEnd,
  });

  final List<CalendarEvent> events;
  final String accountEmail;
  final String? accountDisplayName;
  final String? accountPhotoUrl;
  final DateTime rangeStart;
  final DateTime rangeEnd;
}

CalendarEvent? _mapEvent(gcal.Event event, {bool isHoliday = false}) {
  final title = event.summary?.trim();
  if (title == null || title.isEmpty) return null;

  final start = _parseEventDateTime(event.start);
  final end = _parseEventDateTime(event.end);
  if (start == null || end == null) return null;

  final location = event.location?.trim();

  return CalendarEvent(
    title: title,
    start: start,
    end: end,
    allDay: event.start?.dateTime == null,
    location: location == null || location.isEmpty ? null : location,
    isHoliday: isHoliday,
  );
}

DateTime? _parseEventDateTime(gcal.EventDateTime? value) {
  if (value == null) return null;
  if (value.dateTime != null) return value.dateTime!.toLocal();

  final date = value.date;
  if (date == null) return null;

  return DateTime(date.year, date.month, date.day);
}

String? _nameFromIdToken(String? idToken) {
  if (idToken == null || idToken.isEmpty) return null;

  final parts = idToken.split('.');
  if (parts.length < 2) return null;

  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded) as Map<String, dynamic>;
    return (payload['name'] as String?)?.trim();
  } catch (_) {
    return null;
  }
}

/// Sync range: selected analysis month plus the following month.
({DateTime start, DateTime end}) calendarSyncRange({
  required DateTime analysisMonthStart,
}) {
  return monthAndNextMonthRange(analysisMonthStart);
}
