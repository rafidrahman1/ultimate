import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/core/data_cache_service.dart';
import 'package:personal/core/period_range.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_settings_service.dart';
import 'package:personal/features/calendar/google_calendar_client.dart';

final calendarSummaryProvider =
    StateNotifierProvider<CalendarSummaryNotifier, CalendarSummary>((ref) {
      final notifier = CalendarSummaryNotifier(ref);
      unawaited(notifier.restoreFromCache());
      return notifier;
    });

class CalendarSummaryNotifier extends StateNotifier<CalendarSummary> {
  CalendarSummaryNotifier(this._ref)
    : super(const CalendarSummary(events: [])) {
    _client = GoogleCalendarClient(
      accountService: _ref.read(googleAccountServiceProvider),
    );
  }

  final Ref _ref;
  late final GoogleCalendarClient _client;
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
    await _persistGoogleConnectionFromSummary();
  }

  Future<void> persistGoogleConnection({
    required String email,
    String? photoUrl,
    String? displayName,
  }) {
    return _ref
        .read(calendarSettingsProvider.notifier)
        .saveConnection(
          email: email,
          photoUrl: photoUrl,
          displayName: displayName,
        );
  }

  Future<void> signOut() async {
    await _client.signOut();
    await _ref.read(calendarSettingsProvider.notifier).clearConnection();
    clear();
  }

  Future<void> _persistGoogleConnectionFromSummary() async {
    final email = state.accountEmail;
    if (email == null) return;
    await persistGoogleConnection(
      email: email,
      photoUrl: state.accountPhotoUrl,
      displayName: state.accountDisplayName,
    );
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
          accountDisplayName: result.accountDisplayName,
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
