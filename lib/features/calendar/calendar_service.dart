import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data_cache_service.dart';
import '../location/location_service.dart';
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
      await _ref.read(calendarSettingsProvider.notifier).saveConnectedEmail(email);
    }
  }

  Future<void> signOut() async {
    await _client.signOut();
    await _ref.read(calendarSettingsProvider.notifier).clearConnection();
    clear();
  }

  Future<void> _sync({required bool interactiveSignIn}) async {
    final location = _ref.read(locationSummaryProvider);
    final range = calendarSyncRange(location: location);
    final result = await _client.fetchPrimaryCalendarEvents(
      rangeStart: range.start,
      rangeEnd: range.end,
      interactiveSignIn: interactiveSignIn,
    );

    _commit(
      CalendarSummary(
        events: result.events,
        accountEmail: result.accountEmail,
        syncedAt: DateTime.now(),
        rangeStart: result.rangeStart,
        rangeEnd: result.rangeEnd,
      ),
    );
  }

  void clear() {
    state = const CalendarSummary(events: []);
    unawaited(DataCacheService.instance.clearCalendar());
  }
}
