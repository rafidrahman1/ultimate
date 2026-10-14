import 'package:health/health.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/period_range.dart';
import 'package:personal/features/health/analysis/sleep_prompt_builder.dart';
import 'package:personal/features/health/analysis/vitals_prompt_builder.dart';
import 'package:personal/features/health/data/health_service.dart';
import 'package:personal/features/health/data/vitals_models.dart';

part 'sleep_summary_models.dart';

typedef TimeInterval = ({DateTime start, DateTime end});

const _samsungHealthSourceFragments = [
  'com.sec.android.app.shealth',
  'com.samsung.android.app.shealth',
  'com.samsung.android.apps.health',
];

bool isSamsungHealthSource(String sourceName) {
  final lower = sourceName.toLowerCase();
  for (final fragment in _samsungHealthSourceFragments) {
    if (lower.contains(fragment)) return true;
  }
  return false;
}

/// One calendar wake-day in the analysis month (safely captures overnight sleep).
class DailySleepEntry {
  const DailySleepEntry({
    required this.wakeDate,
    this.session,
    this.napDuration = Duration.zero,
  });

  final DateTime wakeDate;
  final SleepSummary? session;

  /// Daytime sleep on this day outside the main night session.
  final Duration napDuration;

  bool get hasData => session != null;

  /// Night plus naps; what counts against the daily sleep target.
  Duration get totalSleep => (session?.duration ?? Duration.zero) + napDuration;
}

/// Monthly summary optimized for AI insight payloads.
class MonthlyHealthSummary {
  const MonthlyHealthSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.dailySleep,
    required this.dayCount,
    this.vitals,
  });

  final DateTime periodStart;
  final DateTime periodEnd;
  final List<DailySleepEntry> dailySleep;
  final int dayCount;

  /// Steps, heart rate, workouts, weight. Null until connected.
  final VitalsSummary? vitals;

  String get periodRangeLabel => formatPeriodRange(periodStart, periodEnd);

  int get sleepNightsTracked => dailySleep.where((d) => d.hasData).length;

  factory MonthlyHealthSummary.fromFetch(MonthlyHealthFetchResult fetch) {
    final dailySleep = _dailySleepForPeriod(
      fetch.points,
      fetch.periodStart,
      fetch.dayCount,
    );
    return MonthlyHealthSummary(
      periodStart: fetch.periodStart,
      periodEnd: fetch.periodEnd,
      dailySleep: dailySleep,
      dayCount: fetch.dayCount,
      vitals: fetch.vitals,
    );
  }

  int get sleepNightsMissing => dayCount - sleepNightsTracked;

  String toSleepPromptText({
    List<DailySleepEntry>? previousNights,
    bool includeDailyRecords = false,
  }) => buildSleepPromptText(
    this,
    previousNights: previousNights,
    includeDailyRecords: includeDailyRecords,
  );

  /// Full health block inserted into the monthly analysis prompt.
  ///
  /// Sleep first, then stages, then activity/heart/body from [vitals] with a
  /// comparison to [previousVitals]. Each part is omitted when it has no data.
  String toAnalysisPromptText({
    List<DailySleepEntry>? previousNights,
    VitalsSummary? previousVitals,
    bool includeDailyRecords = false,
  }) {
    final nights = dailySleep.where((d) => d.hasData).toList();
    final parts = [
      toSleepPromptText(
        previousNights: previousNights,
        includeDailyRecords: includeDailyRecords,
      ),
      buildSleepStagesText(nights, previousNights: previousNights),
      if (vitals != null)
        buildVitalsPromptText(
          vitals!,
          previous: previousVitals,
          nights: nights,
        ),
    ].where((part) => part.isNotEmpty);
    return parts.join('\n\n');
  }
}
