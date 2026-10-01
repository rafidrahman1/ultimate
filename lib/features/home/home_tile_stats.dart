import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/home_features.dart';

/// One-line headline stat per Home tile, or null when that source has no
/// data for the analysis month.
typedef HomeTileStats = Map<HomeFeatureId, String?>;

final homeTileStatsProvider = Provider<HomeTileStats>((ref) {
  final healthFetch = ref.watch(monthlyHealthDataProvider).valueOrNull;
  final expenses = ref.watch(expensesForAnalysisProvider);
  final location = ref.watch(locationForAnalysisProvider);
  final gameActivity = ref.watch(gameActivityForAnalysisProvider);
  final calendar = ref.watch(calendarForAnalysisProvider);

  String? health;
  if (healthFetch != null && healthFetch.hasData) {
    final nights = MonthlyHealthSummary.fromFetch(
      healthFetch,
    ).dailySleep.where((night) => night.hasData).toList();
    if (nights.isNotEmpty) {
      final totalMinutes = nights.fold<int>(
        0,
        (sum, night) => sum + night.session!.duration.inMinutes,
      );
      final avgHours = totalMinutes / nights.length / 60;
      health = '${avgHours.toStringAsFixed(1)} h avg sleep';
    } else {
      health = 'No sleep tracked';
    }
  }

  String? spending;
  if (expenses.transactions.isNotEmpty) {
    final amount = NumberFormat.decimalPattern().format(
      expenses.totalRealExpenses.round(),
    );
    spending = '${currencyPrefix(expenses.currency)}$amount spent';
  }

  String? mobility;
  if (location.activities.isNotEmpty) {
    final motorcycleKm = location.periodMotorcycleDistanceMeters / 1000;
    mobility = motorcycleKm > 0
        ? '${motorcycleKm.round()} km by motorcycle'
        : '${(location.periodTotalDistanceMeters / 1000).round()} km travelled';
  }

  String? gaming;
  if (gameActivity.sessions.isNotEmpty) {
    final hours = gameActivity.totalPlayTime.inMinutes / 60;
    gaming = '${hours.toStringAsFixed(1)} h played';
  }

  String? events;
  if (calendar.events.isNotEmpty) {
    final count = calendar.events.length;
    events = '$count ${count == 1 ? 'event' : 'events'}';
  }

  final loaded = [
    health,
    spending,
    mobility,
    gaming,
    events,
  ].where((stat) => stat != null).length;

  return {
    HomeFeatureId.dashboard: loaded == 0 ? null : '$loaded of 5 sources',
    HomeFeatureId.health: health,
    HomeFeatureId.expenses: spending,
    HomeFeatureId.location: mobility,
    HomeFeatureId.gameActivity: gaming,
    HomeFeatureId.calendar: events,
  };
});
