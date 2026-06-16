import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_prompt_builder.dart';

enum PeriodTrendDirection {
  increasing,
  decreasing,
  stable,
  improving,
  worsening,
}

extension AnalysisPeriodComparison on AnalysisPeriod {
  /// Same calendar-day span in the immediately preceding month.
  AnalysisPeriod get previousComparablePeriod {
    final prevStart = DateTime(
      dataMonthStart.year,
      dataMonthStart.month - 1,
      dataMonthStart.day,
    );
    final prevEndDay = DateTime(
      dataMonthEnd.year,
      dataMonthEnd.month - 1,
      dataMonthEnd.day,
    );
    final prevEnd = DateTime(
      prevEndDay.year,
      prevEndDay.month,
      prevEndDay.day,
      23,
      59,
      59,
      999,
      999,
    );
    return AnalysisPeriod(
      dataMonthStart: prevStart,
      dataMonthEnd: prevEnd,
      checklistMonthStart: checklistMonthStart,
    );
  }
}

class PeriodComparison<T> {
  const PeriodComparison({
    required this.current,
    required this.previous,
    required this.hasPrevious,
  });

  final T current;
  final T? previous;
  final bool hasPrevious;

  double? get absoluteChange {
    if (!hasPrevious || previous is! num || current is! num) return null;
    return (current as num).toDouble() - (previous as num).toDouble();
  }

  double? get percentChange {
    if (!hasPrevious || previous is! num || current is! num) return null;
    final prev = (previous as num).toDouble();
    if (prev == 0) return null;
    return ((current as num).toDouble() - prev) / prev * 100;
  }
}

PeriodTrendDirection trendForHigherIsBetter({
  required double? absoluteChange,
  double stableThreshold = 0.01,
}) {
  if (absoluteChange == null) return PeriodTrendDirection.stable;
  if (absoluteChange.abs() < stableThreshold) return PeriodTrendDirection.stable;
  return absoluteChange > 0
      ? PeriodTrendDirection.improving
      : PeriodTrendDirection.worsening;
}

PeriodTrendDirection trendForLowerIsBetter({
  required double? absoluteChange,
  double stableThreshold = 0.01,
}) {
  if (absoluteChange == null) return PeriodTrendDirection.stable;
  if (absoluteChange.abs() < stableThreshold) return PeriodTrendDirection.stable;
  return absoluteChange < 0
      ? PeriodTrendDirection.improving
      : PeriodTrendDirection.worsening;
}

PeriodTrendDirection trendForIncrease({
  required double? absoluteChange,
  double stableThreshold = 0.01,
}) {
  if (absoluteChange == null) return PeriodTrendDirection.stable;
  if (absoluteChange.abs() < stableThreshold) return PeriodTrendDirection.stable;
  return absoluteChange > 0
      ? PeriodTrendDirection.increasing
      : PeriodTrendDirection.decreasing;
}

String formatTrendLabel(PeriodTrendDirection direction) {
  return switch (direction) {
    PeriodTrendDirection.increasing => 'Increasing',
    PeriodTrendDirection.decreasing => 'Declining',
    PeriodTrendDirection.stable => 'Stable',
    PeriodTrendDirection.improving => 'Improving',
    PeriodTrendDirection.worsening => 'Worse',
  };
}

String formatSignedDurationChange(Duration change) {
  final sign = change.isNegative ? '-' : '+';
  final abs = change.abs();
  final hours = abs.inHours;
  final minutes = abs.inMinutes.remainder(60);
  if (hours > 0) return '$sign${hours}h ${minutes}m';
  return '$sign${minutes}m';
}

String formatSignedMoneyChange(double change, {bool alwaysTwoDecimals = true}) {
  final sign = change >= 0 ? '+' : '-';
  final abs = change.abs();
  final formatted = alwaysTwoDecimals
      ? abs.toStringAsFixed(2)
      : (abs == abs.roundToDouble()
          ? abs.toStringAsFixed(0)
          : abs.toStringAsFixed(2));
  return '$sign$formatted';
}

String formatSignedPercentChange(double change) {
  final sign = change >= 0 ? '+' : '';
  final rounded = (change * 10).roundToDouble() / 10;
  return '$sign${rounded.toStringAsFixed(1)}%';
}

String formatSignedPercentagePointsChange(double change) {
  final sign = change >= 0 ? '+' : '';
  final rounded = (change * 10).roundToDouble() / 10;
  return '$sign${rounded.toStringAsFixed(1)} percentage points';
}

Duration? averageSleepDuration(List<DailySleepEntry> nights) {
  final withData = nights.where((night) => night.hasData).toList();
  if (withData.isEmpty) return null;
  final totalMinutes = withData
      .map((night) => night.session!.duration.inMinutes)
      .reduce((a, b) => a + b);
  return Duration(minutes: (totalMinutes / withData.length).round());
}

String? buildSleepTrendText({
  required List<DailySleepEntry> currentNights,
  required List<DailySleepEntry>? previousNights,
}) {
  final currentAvg = averageSleepDuration(currentNights);
  if (currentAvg == null) return null;

  final previousAvg = previousNights == null
      ? null
      : averageSleepDuration(previousNights);

  final buffer = StringBuffer('Sleep Trend:')
    ..writeln()
    ..writeln(
      '- Current average: ${formatDurationPadded(currentAvg)}',
    );

  if (previousAvg == null) {
    buffer.writeln('- Previous average: not available');
    return buffer.toString().trimRight();
  }

  final change = Duration(
    minutes: currentAvg.inMinutes - previousAvg.inMinutes,
  );
  final trend = trendForHigherIsBetter(
    absoluteChange: change.inMinutes.toDouble(),
    stableThreshold: 5,
  );

  buffer
    ..writeln(
      '- Previous average: ${formatDurationPadded(previousAvg)}',
    )
    ..writeln('- Change: ${formatSignedDurationChange(change)}')
    ..writeln('- Trend: ${formatTrendLabel(trend)}');

  return buffer.toString().trimRight();
}
