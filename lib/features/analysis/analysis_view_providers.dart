import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/game_activity/game_activity_service.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';

final expensesForAnalysisProvider = Provider<ExpensesSummary>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  return ref.watch(expensesSummaryProvider).forAnalysisPeriod(period);
});

final locationForAnalysisProvider = Provider<LocationSummary>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  return ref.watch(locationSummaryProvider).forAnalysisPeriod(period);
});

final gameActivityForAnalysisProvider = Provider<GameActivitySummary>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  return ref.watch(gameActivitySummaryProvider).forAnalysisPeriod(period);
});

final calendarForAnalysisProvider = Provider<CalendarSummary>((ref) {
  final period = ref.watch(analysisPeriodProvider);
  return ref.watch(calendarSummaryProvider).forAnalysisPeriod(period);
});
