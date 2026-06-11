import 'package:intl/intl.dart';

import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_anomaly.dart';

const sleepTargetDuration = Duration(hours: 7);

class SleepCluster {
  const SleepCluster({
    required this.label,
    required this.start,
    required this.end,
    required this.shortCount,
    required this.spanDays,
    required this.isConsecutiveStreak,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final int shortCount;
  final int spanDays;
  final bool isConsecutiveStreak;

  String get rankingLabel => 'Sleep cluster $label';
}

class SleepDebtSummary {
  const SleepDebtSummary({
    required this.nightsBelowTarget,
    required this.estimatedDebt,
  });

  final int nightsBelowTarget;
  final Duration estimatedDebt;
}

SleepDebtSummary computeSleepDebt(List<DailySleepEntry> nights) {
  var debtMinutes = 0;
  var belowTarget = 0;
  final targetMinutes = sleepTargetDuration.inMinutes;

  for (final night in nights) {
    if (!night.hasData) continue;
    final actualMinutes = night.session!.duration.inMinutes;
    if (actualMinutes < targetMinutes) {
      belowTarget++;
      debtMinutes += targetMinutes - actualMinutes;
    }
  }

  return SleepDebtSummary(
    nightsBelowTarget: belowTarget,
    estimatedDebt: Duration(minutes: debtMinutes),
  );
}

String buildSleepDebtText(List<DailySleepEntry> nights) {
  final nightsWithData = nights.where((night) => night.hasData).toList();
  if (nightsWithData.isEmpty) return '';

  final debt = computeSleepDebt(nightsWithData);
  final targetHours = sleepTargetDuration.inHours;

  return '''
Sleep Debt

Target: ${targetHours}h
Nights below target: ${debt.nightsBelowTarget}
Estimated sleep debt: ${formatDebtDuration(debt.estimatedDebt)}'''
      .trimRight();
}

List<SleepCluster> detectSleepClusters(List<DailySleepEntry> nights) {
  final shortNights = nights
      .where(
        (night) =>
            night.hasData && night.session!.duration < sleepShortThreshold,
      )
      .toList()
    ..sort((a, b) => a.wakeDate.compareTo(b.wakeDate));

  if (shortNights.length < 2) return const [];

  final clusters = <SleepCluster>[];

  for (final streak in _consecutiveShortSleepStreaks(shortNights)) {
    clusters.add(
      SleepCluster(
        label: _formatDateRange(streak.start, streak.end),
        start: streak.start,
        end: streak.end,
        shortCount: streak.length,
        spanDays: streak.length,
        isConsecutiveStreak: true,
      ),
    );
  }

  for (final window in _denseShortSleepWindows(shortNights)) {
    clusters.add(
      SleepCluster(
        label: _formatDateRange(window.start, window.end),
        start: window.start,
        end: window.end,
        shortCount: window.shortCount,
        spanDays: window.spanDays,
        isConsecutiveStreak: false,
      ),
    );
  }

  final seen = <String>{};
  final unique = <SleepCluster>[];
  for (final cluster in clusters) {
    final key = '${cluster.label}|${cluster.shortCount}|${cluster.spanDays}';
    if (seen.add(key)) {
      unique.add(cluster);
    }
  }

  unique.sort((a, b) => a.start.compareTo(b.start));
  return unique;
}

List<String> sleepClusterPromptLines(List<DailySleepEntry> nights) {
  return detectSleepClusters(nights)
      .map(
        (cluster) => cluster.isConsecutiveStreak
            ? '${cluster.label}: ${cluster.shortCount} consecutive short sleep nights'
            : '${cluster.label}: ${cluster.shortCount} short sleep nights in ${cluster.spanDays} days',
      )
      .toList();
}

String formatDebtDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

List<_DateRange> _consecutiveShortSleepStreaks(
  List<DailySleepEntry> shortNights,
) {
  if (shortNights.isEmpty) return const [];

  final streaks = <_DateRange>[];
  var streakStart = _dateOnly(shortNights.first.wakeDate);
  var streakEnd = streakStart;
  var streakLength = 1;

  for (var i = 1; i < shortNights.length; i++) {
    final current = _dateOnly(shortNights[i].wakeDate);
    final previous = _dateOnly(shortNights[i - 1].wakeDate);
    if (current.difference(previous).inDays == 1) {
      streakEnd = current;
      streakLength++;
      continue;
    }

    if (streakLength >= 2) {
      streaks.add(
        _DateRange(start: streakStart, end: streakEnd, length: streakLength),
      );
    }
    streakStart = current;
    streakEnd = current;
    streakLength = 1;
  }

  if (streakLength >= 2) {
    streaks.add(
      _DateRange(start: streakStart, end: streakEnd, length: streakLength),
    );
  }

  return streaks;
}

List<_DenseWindow> _denseShortSleepWindows(List<DailySleepEntry> shortNights) {
  if (shortNights.length < 5) return const [];

  final windows = <_DenseWindow>[];
  final shortDates = shortNights.map((night) => _dateOnly(night.wakeDate)).toSet();

  for (var i = 0; i < shortNights.length; i++) {
    for (var j = i + 4; j < shortNights.length; j++) {
      final start = _dateOnly(shortNights[i].wakeDate);
      final end = _dateOnly(shortNights[j].wakeDate);
      final spanDays = end.difference(start).inDays + 1;
      if (spanDays < 5) continue;

      var shortCount = 0;
      for (var offset = 0; offset < spanDays; offset++) {
        if (shortDates.contains(start.add(Duration(days: offset)))) {
          shortCount++;
        }
      }

      if (shortCount < spanDays &&
          shortCount >= spanDays - 1 &&
          shortCount >= 5) {
        windows.add(
          _DenseWindow(
            start: start,
            end: end,
            spanDays: spanDays,
            shortCount: shortCount,
          ),
        );
      }
    }
  }

  windows.sort((a, b) {
    final spanCompare = b.spanDays.compareTo(a.spanDays);
    if (spanCompare != 0) return spanCompare;
    return a.start.compareTo(b.start);
  });

  final kept = <_DenseWindow>[];
  for (final window in windows) {
    final dominated = kept.any(
      (other) =>
          !other.start.isAfter(window.start) &&
          !other.end.isBefore(window.end) &&
          other.shortCount >= window.shortCount,
    );
    if (!dominated) {
      kept.add(window);
    }
  }

  kept.sort((a, b) => a.start.compareTo(b.start));
  return kept;
}

String formatWakeDateShort(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

String _formatDateRange(DateTime start, DateTime end) {
  if (start.month == end.month && start.year == end.year) {
    return '${start.day}–${end.day} ${DateFormat('MMM').format(start)}';
  }
  return '${formatWakeDateShort(start)} – ${formatWakeDateShort(end)}';
}

DateTime _dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

class _DateRange {
  const _DateRange({
    required this.start,
    required this.end,
    required this.length,
  });

  final DateTime start;
  final DateTime end;
  final int length;
}

class _DenseWindow {
  const _DenseWindow({
    required this.start,
    required this.end,
    required this.spanDays,
    required this.shortCount,
  });

  final DateTime start;
  final DateTime end;
  final int spanDays;
  final int shortCount;
}
