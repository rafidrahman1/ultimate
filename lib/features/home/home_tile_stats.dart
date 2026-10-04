import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/home_features.dart';

/// Headline number plus a short caption for one Home tile.
class HomeTileStat {
  const HomeTileStat(this.value, this.caption, {this.series});

  final String value;
  final String caption;

  /// Per-day values across the analysis month for the tile's sparkline;
  /// null when there are too few points to draw a trend.
  final List<double>? series;

  String get spoken => '$value $caption';
}

/// Headline stat per Home tile, or null when that source has no data for the
/// analysis month.
typedef HomeTileStats = Map<HomeFeatureId, HomeTileStat?>;

/// Whether health data is still being read (tile shows a loading state).
final homeHealthLoadingProvider = Provider<bool>(
  (ref) => ref.watch(monthlyHealthDataProvider).isLoading,
);

/// Buckets [entries] by day of [monthStart]'s month into a list covering the
/// month so far (or the whole month when it is over). Null when fewer than
/// two days have a value.
List<double>? dailySeries(
  Iterable<({DateTime date, double value})> entries,
  DateTime monthStart,
) {
  final now = DateTime.now();
  final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  final isCurrent =
      now.year == monthStart.year && now.month == monthStart.month;
  final days = isCurrent ? now.day : daysInMonth;

  final buckets = List<double>.filled(days, 0);
  for (final entry in entries) {
    final date = entry.date;
    if (date.year != monthStart.year || date.month != monthStart.month) {
      continue;
    }
    if (date.day > days) continue;
    buckets[date.day - 1] += entry.value;
  }
  return buckets.where((v) => v > 0).length < 2 ? null : buckets;
}

final homeTileStatsProvider = Provider<HomeTileStats>((ref) {
  final monthStart = ref.watch(selectedAnalysisMonthProvider);
  final healthFetch = ref.watch(monthlyHealthDataProvider).valueOrNull;
  final expenses = ref.watch(expensesForAnalysisProvider);
  final location = ref.watch(locationForAnalysisProvider);
  final gameActivity = ref.watch(gameActivityForAnalysisProvider);
  final calendar = ref.watch(calendarForAnalysisProvider);

  HomeTileStat? health;
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
      health = HomeTileStat(
        '${avgHours.toStringAsFixed(1)} h',
        'avg sleep',
        series: dailySeries([
          for (final night in nights)
            (
              date: night.wakeDate,
              value: night.session!.duration.inMinutes / 60,
            ),
        ], monthStart),
      );
    } else {
      health = const HomeTileStat('—', 'no sleep tracked');
    }
  }

  HomeTileStat? spending;
  if (expenses.transactions.isNotEmpty) {
    final amount = NumberFormat.decimalPattern().format(
      expenses.totalRealExpenses.round(),
    );
    spending = HomeTileStat(
      '${currencyPrefix(expenses.currency)}$amount',
      'spent',
      series: dailySeries([
        for (final t in expenses.transactions)
          if (t.isRealExpense) (date: t.date, value: t.amount.abs()),
      ], monthStart),
    );
  }

  HomeTileStat? mobility;
  if (location.activities.isNotEmpty) {
    final motorcycleKm = location.periodMotorcycleDistanceMeters / 1000;
    final distanceSeries = dailySeries([
      for (final a in location.activities)
        (date: a.startTime, value: a.distanceMeters / 1000),
    ], monthStart);
    mobility = motorcycleKm > 0
        ? HomeTileStat(
            '${motorcycleKm.round()} km',
            'by motorcycle',
            series: distanceSeries,
          )
        : HomeTileStat(
            '${(location.periodTotalDistanceMeters / 1000).round()} km',
            'travelled',
            series: distanceSeries,
          );
  }

  HomeTileStat? gaming;
  if (gameActivity.sessions.isNotEmpty) {
    final hours = gameActivity.totalPlayTime.inMinutes / 60;
    gaming = HomeTileStat(
      '${hours.toStringAsFixed(1)} h',
      'played',
      series: dailySeries([
        for (final s in gameActivity.sessions)
          (date: s.sessionDate, value: s.timePlayed.inMinutes / 60),
      ], monthStart),
    );
  }

  HomeTileStat? events;
  if (calendar.events.isNotEmpty) {
    final count = calendar.events.length;
    events = HomeTileStat(
      '$count',
      count == 1 ? 'event' : 'events',
      series: dailySeries([
        for (final e in calendar.events) (date: e.start.toLocal(), value: 1.0),
      ], monthStart),
    );
  }

  final loaded = [
    health,
    spending,
    mobility,
    gaming,
    events,
  ].where((stat) => stat != null).length;

  return {
    HomeFeatureId.dashboard: loaded == 0
        ? null
        : HomeTileStat('$loaded of 5', 'sources'),
    HomeFeatureId.health: health,
    HomeFeatureId.expenses: spending,
    HomeFeatureId.location: mobility,
    HomeFeatureId.gameActivity: gaming,
    HomeFeatureId.calendar: events,
  };
});
