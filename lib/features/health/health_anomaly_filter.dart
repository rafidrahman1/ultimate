import 'health_summary.dart';

/// Detects notable sleep outliers for AI analysis prompts.
/// Steps are summarized as a period average only (see [HealthAnomalyReport.toPromptText]).
class HealthAnomalyFilter {
  const HealthAnomalyFilter({
    this.minSleepNightsForStats = 5,
    this.shortSleep = const Duration(hours: 6),
    this.veryShortSleep = const Duration(hours: 4),
    this.lateBedtimeAfterHour = 2,
    this.lateBedtimeAfterMinute = 0,
    this.earlyWakeBeforeHour = 6,
    this.iqrMultiplier = 1.5,
  });

  final int minSleepNightsForStats;
  final Duration shortSleep;
  final Duration veryShortSleep;
  final int lateBedtimeAfterHour;
  final int lateBedtimeAfterMinute;
  final int earlyWakeBeforeHour;
  final double iqrMultiplier;

  HealthAnomalyReport analyze(MonthlyHealthSummary summary) {
    final sleepNights = summary.dailySleep.where((d) => d.hasData).toList();
    return HealthAnomalyReport(sleepAnomalies: _sleepAnomalies(sleepNights));
  }

  List<SleepAnomaly> _sleepAnomalies(List<DailySleepEntry> nights) {
    if (nights.isEmpty) return const [];

    final durationMinutes = nights
        .map((n) => n.session!.duration.inMinutes.toDouble())
        .toList();
    final durationLowerFence = _lowerFence(durationMinutes);

    final results = <SleepAnomaly>[];
    for (final night in nights) {
      final session = night.session!;
      final reasons = <String>[];

      if (session.duration < veryShortSleep) {
        reasons.add('very short sleep (<${veryShortSleep.inHours}h)');
      } else if (session.duration < shortSleep) {
        reasons.add('short sleep (<${shortSleep.inHours}h)');
      }

      if (_isLateBedtime(session.startTime)) {
        reasons.add(
          'late bedtime (after '
          '${lateBedtimeAfterHour.toString().padLeft(2, '0')}:'
          '${lateBedtimeAfterMinute.toString().padLeft(2, '0')})',
        );
      }

      if (session.endTime.hour < earlyWakeBeforeHour) {
        reasons.add('early wake (before '
            '${earlyWakeBeforeHour.toString().padLeft(2, '0')}:00)');
      }

      if (durationLowerFence != null &&
          nights.length >= minSleepNightsForStats &&
          session.duration.inMinutes < durationLowerFence) {
        reasons.add('well below usual duration');
      }

      if (reasons.isNotEmpty) {
        results.add(SleepAnomaly(entry: night, reasons: reasons));
      }
    }

    results.sort((a, b) => a.entry.wakeDate.compareTo(b.entry.wakeDate));
    return results;
  }

  /// True when bedtime falls in early morning (after [lateBedtimeAfterHour]).
  /// Evening bedtimes (18:00–23:59) are not treated as delayed sleep.
  bool _isLateBedtime(DateTime bedtime) {
    final hour = bedtime.hour;
    if (hour >= 18 || (hour >= 6 && hour < 18)) return false;

    final afterMinutes = lateBedtimeAfterHour * 60 + lateBedtimeAfterMinute;
    final bedtimeMinutes = hour * 60 + bedtime.minute;
    return bedtimeMinutes > afterMinutes;
  }

  double? _lowerFence(List<double> values) {
    if (values.length < minSleepNightsForStats) return null;
    final sorted = [...values]..sort();
    final q1 = _percentile(sorted, 0.25);
    final q3 = _percentile(sorted, 0.75);
    final iqr = q3 - q1;
    if (iqr <= 0) return null;
    return q1 - iqrMultiplier * iqr;
  }

  double _percentile(List<double> sorted, double p) {
    assert(sorted.isNotEmpty);
    if (sorted.length == 1) return sorted.first;
    final index = p * (sorted.length - 1);
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sorted[lower];
    final weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }
}

class HealthAnomalyReport {
  const HealthAnomalyReport({required this.sleepAnomalies});

  final List<SleepAnomaly> sleepAnomalies;

  bool get hasSleepAnomalies => sleepAnomalies.isNotEmpty;

  String toPromptText({
    required int dayCount,
    required double avgStepsPerDay,
  }) {
    final buffer = StringBuffer()
      ..writeln(
        'Steps: ${avgStepsPerDay.round()} avg per day ($dayCount days)',
      );

    if (!hasSleepAnomalies) {
      buffer.writeln('Sleep anomalies: none detected');
      return buffer.toString().trimRight();
    }

    buffer.writeln('Sleep anomalies (by wake day):');
    for (final anomaly in sleepAnomalies) {
      final s = anomaly.entry.session!;
      final reasonText = anomaly.reasons.join('; ');
      buffer.writeln(
        '- ${formatWakeDate(anomaly.entry.wakeDate)}: '
        '${formatDuration(s.duration)}, '
        'bedtime ${formatTime(s.startTime)}, '
        'wake ${formatTime(s.endTime)} ($reasonText)',
      );
    }

    return buffer.toString().trimRight();
  }
}

class SleepAnomaly {
  const SleepAnomaly({required this.entry, required this.reasons});

  final DailySleepEntry entry;
  final List<String> reasons;
}
