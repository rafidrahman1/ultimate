import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/calendar/data/calendar_service.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/expenses/data/expenses_service.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/location/data/location_insights_providers.dart';
import 'package:personal/features/location/data/location_service.dart';
import 'package:personal/features/location/data/timeline_activity.dart';

final expensesForAnalysisProvider = Provider<ExpensesSummary>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  return ref.watch(expensesHistoryProvider).forAnalysisPeriod(period);
});

final locationForAnalysisProvider = Provider<LocationSummary>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  final names = ref.watch(placeNamesProvider);
  return ref
      .watch(locationSummaryProvider)
      .forAnalysisPeriod(period, placeNames: names);
});

final gameActivityForAnalysisProvider = Provider<GameActivitySummary>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  return ref.watch(gameActivitySummaryProvider).forAnalysisPeriod(period);
});

final calendarForAnalysisProvider = Provider<CalendarSummary>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  return ref.watch(calendarSummaryProvider).forAnalysisPeriod(period);
});

/// Wider than [calendarForAnalysisProvider] — matches the Google Calendar sync range.
final calendarForDisplayProvider = Provider<CalendarSummary>((ref) {
  final monthStart = ref.watch(selectedAnalysisMonthProvider);
  return ref.watch(calendarSummaryProvider).forSyncedDisplayRange(monthStart);
});
