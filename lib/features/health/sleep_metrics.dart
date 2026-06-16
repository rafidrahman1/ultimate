import 'package:intl/intl.dart';

import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_anomaly.dart';
import 'package:personal/features/results/derived_metric_validation.dart';

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
      .map((cluster) => buildSleepClusterDetailText(cluster, nights))
      .toList();
}

class SleepClusterNightMetrics {
  const SleepClusterNightMetrics({
    required this.veryShortCount,
    required this.lateBedtimeCount,
  });

  final int veryShortCount;
  final int lateBedtimeCount;
}

SleepClusterNightMetrics computeSleepClusterNightMetrics(
  SleepCluster cluster,
  List<DailySleepEntry> nights,
) {
  const veryShortSleep = Duration(hours: 4);

  var veryShortCount = 0;
  var lateBedtimeCount = 0;

  for (final night in nights) {
    if (!night.hasData) continue;
    final wakeDate = _dateOnly(night.wakeDate);
    if (wakeDate.isBefore(cluster.start) || wakeDate.isAfter(cluster.end)) {
      continue;
    }
    if (!isSleepAnomalyNight(night)) continue;

    final session = night.session!;
    if (session.duration < veryShortSleep) veryShortCount++;
    if (_isLateClusterBedtime(session.startTime)) lateBedtimeCount++;
  }

  return SleepClusterNightMetrics(
    veryShortCount: veryShortCount,
    lateBedtimeCount: lateBedtimeCount,
  );
}

String buildSleepClusterDetailText(
  SleepCluster cluster,
  List<DailySleepEntry> nights,
) {
  final metrics = computeSleepClusterNightMetrics(cluster, nights);
  final severityScore = _sleepClusterSeverityScore(cluster, metrics);
  final severity = _sleepClusterSeverityLabel(severityScore);

  return '''
Sleep Cluster
${cluster.label}

Short sleep nights:
${cluster.shortCount}

Total days:
${cluster.spanDays}

Density:
${DerivedMetricValidation.formatValidatedClusterDensity(cluster.shortCount / cluster.spanDays * 100)}

Severity:
$severity ($severityScore)'''
      .trimRight();
}

String _sleepClusterSeverityLabel(int score) {
  if (score >= 22) return 'High';
  if (score >= 14) return 'Moderate';
  return 'Low';
}

int _sleepClusterSeverityScore(
  SleepCluster cluster,
  SleepClusterNightMetrics metrics,
) {
  final lengthScore = cluster.spanDays.clamp(0, 8);
  final shortScore = (cluster.shortCount * 2).clamp(0, 16);
  final veryShortScore = (metrics.veryShortCount * 3).clamp(0, 12);
  final lateScore = metrics.lateBedtimeCount.clamp(0, 6);
  return lengthScore + shortScore + veryShortScore + lateScore;
}

bool _isLateClusterBedtime(DateTime bedtime) {
  final hour = bedtime.hour;
  if (hour >= 18 || (hour >= 6 && hour < 18)) return false;
  return bedtime.hour * 60 + bedtime.minute > 2 * 60;
}

String formatDebtDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

class SleepConsistencyMetrics {
  const SleepConsistencyMetrics({
    required this.bedtimeStdDevMinutes,
    required this.wakeStdDevMinutes,
    required this.earliestBedtime,
    required this.latestBedtime,
    required this.earliestWake,
    required this.latestWake,
  });

  final double bedtimeStdDevMinutes;
  final double wakeStdDevMinutes;
  final DateTime earliestBedtime;
  final DateTime latestBedtime;
  final DateTime earliestWake;
  final DateTime latestWake;
}

class SleepRecoveryMetrics {
  const SleepRecoveryMetrics({
    required this.shortSleepNights,
    required this.recoveryNights,
    required this.recoveryRatePercent,
  });

  final int shortSleepNights;
  final int recoveryNights;
  final double? recoveryRatePercent;
}

SleepConsistencyMetrics? computeSleepConsistency(
  List<DailySleepEntry> nights,
) {
  final withData = nights.where((night) => night.hasData).toList();
  if (withData.length < 2) return null;

  final bedtimes = withData.map((night) => night.session!.startTime).toList();
  final wakes = withData.map((night) => night.session!.endTime).toList();

  return SleepConsistencyMetrics(
    bedtimeStdDevMinutes: circularStdDevClockMinutes(
      bedtimes.map(_clockMinutes),
    ),
    wakeStdDevMinutes: circularStdDevClockMinutes(
      wakes.map(_clockMinutes),
    ),
    earliestBedtime: bedtimes.reduce(
      (a, b) => _bedtimeMinutesForStats(a) <= _bedtimeMinutesForStats(b) ? a : b,
    ),
    latestBedtime: bedtimes.reduce(
      (a, b) => _bedtimeMinutesForStats(a) >= _bedtimeMinutesForStats(b) ? a : b,
    ),
    earliestWake: wakes.reduce((a, b) => _clockMinutes(a) <= _clockMinutes(b) ? a : b),
    latestWake: wakes.reduce((a, b) => _clockMinutes(a) >= _clockMinutes(b) ? a : b),
  );
}

SleepRecoveryMetrics computeSleepRecovery(List<DailySleepEntry> nights) {
  final sorted = nights.where((night) => night.hasData).toList()
    ..sort((a, b) => a.wakeDate.compareTo(b.wakeDate));

  var shortCount = 0;
  var recoveryCount = 0;

  for (var i = 0; i < sorted.length; i++) {
    final session = sorted[i].session!;
    if (session.duration >= sleepShortThreshold) continue;
    shortCount++;

    if (i + 1 < sorted.length) {
      final next = sorted[i + 1].session!;
      if (next.duration > sleepTargetDuration) {
        recoveryCount++;
      }
    }
  }

  return SleepRecoveryMetrics(
    shortSleepNights: shortCount,
    recoveryNights: recoveryCount,
    recoveryRatePercent:
        shortCount > 0 ? recoveryCount / shortCount * 100 : null,
  );
}

String buildSleepConsistencyText(List<DailySleepEntry> nights) {
  final consistency = computeSleepConsistency(nights);
  final recovery = computeSleepRecovery(nights);
  final sections = <String>[];

  if (consistency != null) {
    sections.add('''
Sleep Consistency:

- Bedtime standard deviation: ${DerivedMetricValidation.formatValidatedStdDevMinutes(consistency.bedtimeStdDevMinutes)}
- Wake time standard deviation: ${DerivedMetricValidation.formatValidatedStdDevMinutes(consistency.wakeStdDevMinutes)}

Sleep Variability:

- Earliest bedtime: ${formatTime(consistency.earliestBedtime)}
- Latest bedtime: ${formatTime(consistency.latestBedtime)}
- Earliest wake: ${formatTime(consistency.earliestWake)}
- Latest wake: ${formatTime(consistency.latestWake)}'''
        .trimRight());
  }

  final recoveryRate = DerivedMetricValidation.sanitizePercent(
    recovery.recoveryRatePercent,
  );
  sections.add('''
Sleep Recovery:

- Short sleep nights: ${recovery.shortSleepNights}
- Recovery nights (>7h after short sleep): ${recovery.recoveryNights}
- Recovery rate %: ${recoveryRate == null ? 'n/a' : '${recoveryRate.toStringAsFixed(1)}%'}'''
      .trimRight());

  return sections.join('\n\n');
}

int _clockMinutes(DateTime time) => time.hour * 60 + time.minute;

int _bedtimeMinutesForStats(DateTime bedtime) {
  final minutes = _clockMinutes(bedtime);
  return bedtime.hour < 6 ? minutes + 24 * 60 : minutes;
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
