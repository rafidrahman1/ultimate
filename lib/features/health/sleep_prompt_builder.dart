import 'package:intl/intl.dart';

import 'package:personal/features/analysis/period_comparison.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';

const _shortSleep = Duration(hours: 6);
const _veryShortSleep = Duration(hours: 4);
const _lateBedtimeAfterHour = 2;
const _lateBedtimeAfterMinute = 0;
const _earlyWakeBeforeHour = 6;

String buildSleepPromptText(
  MonthlyHealthSummary summary, {
  List<DailySleepEntry>? previousNights,
}) {
  final nights = summary.dailySleep.where((d) => d.hasData).toList();
  if (nights.isEmpty) return '';

  final buffer = StringBuffer('Sleep Summary');

  final trend = buildSleepTrendText(
    currentNights: nights,
    previousNights: previousNights,
  );
  if (trend != null) {
    buffer
      ..writeln()
      ..writeln()
      ..write(trend);
  }

  _writeTypical(buffer, nights);
  _writeMonthlyMetrics(buffer, nights);
  _writeSleepDebt(buffer, nights);
  _writeConsistency(buffer, nights);
  _writeClusters(buffer, nights);
  _writeWorstNight(buffer, nights);
  _writeDailyRecords(buffer, nights);

  return buffer.toString().trimRight();
}

void _writeTypical(StringBuffer buffer, List<DailySleepEntry> nights) {
  final avgDurationMinutes =
      nights.map((n) => n.session!.duration.inMinutes).reduce((a, b) => a + b) /
      nights.length;
  final avgBedtimeMinutes = _averageBedtimeMinutes(
    nights.map((n) => n.session!.startTime),
  );
  final avgWakeMinutes = _averageClockMinutes(
    nights.map((n) => n.session!.endTime),
  );

  buffer
    ..writeln()
    ..writeln()
    ..writeln('Typical:')
    ..writeln(
      '- Average duration: '
      '${formatDurationPadded(Duration(minutes: avgDurationMinutes.round()))}',
    )
    ..writeln(
      '- Average bedtime: ${formatMinutesAsTime(avgBedtimeMinutes)}',
    )
    ..writeln(
      '- Average wake time: ${formatMinutesAsTime(avgWakeMinutes)}',
    );
}

void _writeMonthlyMetrics(StringBuffer buffer, List<DailySleepEntry> nights) {
  var shortCount = 0;
  var veryShortCount = 0;
  var lateBedtimeCount = 0;
  var earlyWakeCount = 0;

  for (final night in nights) {
    final session = night.session!;
    if (session.duration < _veryShortSleep) {
      veryShortCount++;
    }
    if (session.duration < _shortSleep) {
      shortCount++;
    }
    if (_isLateBedtime(session.startTime)) {
      lateBedtimeCount++;
    }
    if (session.endTime.hour < _earlyWakeBeforeHour) {
      earlyWakeCount++;
    }
  }

  buffer
    ..writeln()
    ..writeln('Monthly Metrics:')
    ..writeln('- Short sleep nights (<6h): $shortCount')
    ..writeln('- Very short sleep nights (<4h): $veryShortCount')
    ..writeln(
      '- Late bedtimes (>'
      '${_lateBedtimeAfterHour.toString().padLeft(2, '0')}:'
      '${_lateBedtimeAfterMinute.toString().padLeft(2, '0')}): '
      '$lateBedtimeCount',
    )
    ..writeln(
      '- Early wakes (<'
      '${_earlyWakeBeforeHour.toString().padLeft(2, '0')}:00): '
      '$earlyWakeCount',
    );
}

void _writeSleepDebt(StringBuffer buffer, List<DailySleepEntry> nights) {
  final text = buildSleepDebtText(nights);
  if (text.isEmpty) return;
  buffer
    ..writeln()
    ..writeln(text);
}

void _writeConsistency(StringBuffer buffer, List<DailySleepEntry> nights) {
  final text = buildSleepConsistencyText(nights);
  if (text.isEmpty) return;
  buffer
    ..writeln()
    ..writeln(text);
}

void _writeClusters(StringBuffer buffer, List<DailySleepEntry> nights) {
  final clusters = detectSleepClusters(nights);
  if (clusters.isEmpty) return;

  buffer
    ..writeln()
    ..writeln('Clusters:');
  for (var i = 0; i < clusters.length; i++) {
    if (i > 0) buffer.writeln();
    buffer.write(buildSleepClusterDetailText(clusters[i], nights));
  }
}

void _writeWorstNight(StringBuffer buffer, List<DailySleepEntry> nights) {
  final worst = nights.reduce(
    (a, b) => a.session!.duration <= b.session!.duration ? a : b,
  );
  final session = worst.session!;

  buffer
    ..writeln()
    ..writeln('Worst Night:')
    ..writeln('- ${formatWakeDateShort(worst.wakeDate)}')
    ..writeln('  Sleep: ${formatDuration(session.duration)}')
    ..writeln('  Bedtime: ${formatTime(session.startTime)}')
    ..writeln('  Wake: ${formatTime(session.endTime)}');
}

void _writeDailyRecords(StringBuffer buffer, List<DailySleepEntry> nights) {
  buffer
    ..writeln()
    ..writeln('Daily Records:');
  for (final night in nights) {
    final session = night.session!;
    buffer
      ..writeln('- ${formatWakeDateShort(night.wakeDate)}')
      ..writeln('  Bedtime: ${formatTime(session.startTime)}')
      ..writeln('  Wake: ${formatTime(session.endTime)}')
      ..writeln('  Sleep: ${formatDurationCompact(session.duration)}');
  }
}

bool _isLateBedtime(DateTime bedtime) {
  final hour = bedtime.hour;
  if (hour >= 18 || (hour >= 6 && hour < 18)) return false;

  final afterMinutes = _lateBedtimeAfterHour * 60 + _lateBedtimeAfterMinute;
  final bedtimeMinutes = hour * 60 + bedtime.minute;
  return bedtimeMinutes > afterMinutes;
}

int _clockMinutes(DateTime time) => time.hour * 60 + time.minute;

int _bedtimeMinutesForAverage(DateTime bedtime) {
  final minutes = _clockMinutes(bedtime);
  return bedtime.hour < 6 ? minutes + 24 * 60 : minutes;
}

int _averageBedtimeMinutes(Iterable<DateTime> bedtimes) {
  final values = bedtimes.map(_bedtimeMinutesForAverage).toList();
  if (values.isEmpty) return 0;
  final avg = values.reduce((a, b) => a + b) / values.length;
  final rounded = avg.round();
  return rounded >= 24 * 60 ? rounded - 24 * 60 : rounded;
}

int _averageClockMinutes(Iterable<DateTime> times) {
  final values = times.map(_clockMinutes).toList();
  if (values.isEmpty) return 0;
  return (values.reduce((a, b) => a + b) / values.length).round();
}

String formatWakeDateShort(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

String formatMinutesAsTime(int totalMinutes) {
  final normalized = ((totalMinutes % (24 * 60)) + 24 * 60) % (24 * 60);
  final hours = normalized ~/ 60;
  final minutes = normalized % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

String formatDurationPadded(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  return '${minutes}m';
}

String formatDurationCompact(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h${minutes}m';
  return '${minutes}m';
}
