import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis_month_settings_service.dart';
import '../../core/data_cache_service.dart';
import '../../core/period_range.dart';
import 'calendar_event.dart';
import 'calendar_settings_service.dart';
import 'google_calendar_client.dart';

final calendarSummaryProvider =
    StateNotifierProvider<CalendarSummaryNotifier, CalendarSummary>((ref) {
  final notifier = CalendarSummaryNotifier(ref);
  unawaited(notifier.restoreFromCache());
  return notifier;
});

class CalendarSummaryNotifier extends StateNotifier<CalendarSummary> {
  CalendarSummaryNotifier(this._ref) : super(const CalendarSummary(events: []));

  final Ref _ref;
  final GoogleCalendarClient _client = GoogleCalendarClient();
  bool _cacheRestored = false;

  Future<void> restoreFromCache() async {
    if (_cacheRestored) return;
    _cacheRestored = true;
    final cached = await DataCacheService.instance.loadCalendar();
    if (cached != null && cached.events.isNotEmpty) {
      state = cached;
    }
  }

  void _commit(CalendarSummary summary) {
    state = summary;
    if (summary.events.isNotEmpty) {
      unawaited(DataCacheService.instance.saveCalendar(summary));
    }
  }

  Future<void> loadAuto({bool interactiveSignIn = false}) async {
    await _sync(interactiveSignIn: interactiveSignIn);
  }

  Future<void> connectAndSync() async {
    await loadAuto(interactiveSignIn: true);
    final email = state.accountEmail;
    if (email != null) {
      await _ref
          .read(calendarSettingsProvider.notifier)
          .saveConnection(email: email, photoUrl: state.accountPhotoUrl);
    }
  }

  Future<void> signOut() async {
    await _client.signOut();
    await _ref.read(calendarSettingsProvider.notifier).clearConnection();
    clear();
  }

  Future<void> _sync({required bool interactiveSignIn}) async {
    final monthStart = _ref.read(selectedAnalysisMonthProvider);
    final range = monthAndNextMonthRange(monthStart);
    try {
      final result = await _client.fetchPrimaryCalendarEvents(
        rangeStart: range.start,
        rangeEnd: range.end,
        interactiveSignIn: interactiveSignIn,
      );

      _commit(
        CalendarSummary(
          events: result.events,
          accountEmail: result.accountEmail,
          accountPhotoUrl: result.accountPhotoUrl,
          syncedAt: DateTime.now(),
          rangeStart: result.rangeStart,
          rangeEnd: result.rangeEnd,
        ),
      );
    } on FormatException {
      if (!interactiveSignIn && state.events.isNotEmpty) {
        // Keep cached events when background sync has no in-app session.
        return;
      }
      rethrow;
    }
  }

  void clear() {
    state = const CalendarSummary(events: []);
    unawaited(DataCacheService.instance.clearCalendar());
  }
}
