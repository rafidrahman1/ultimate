part of 'calendar_prompt_builder.dart';

String buildEventAnalysisText(
  List<CalendarPromptEvent> events, {
  MonthlyHealthSummary? health,
  LocationSummary? location,
  ExpensesSummary? expenses,
}) {
  if (events.isEmpty) return '';

  final hasHealth = health != null && health.sleepNightsTracked > 0;
  final eventSections = <String>[];

  for (final event in events) {
    final block = _eventAnalysisBlock(
      event,
      dailySleep: hasHealth ? health.dailySleep : const [],
      location: location,
      expenses: expenses,
      includeSleep: hasHealth,
    );
    if (block != null) eventSections.add(block);
  }

  if (eventSections.isEmpty) return '';

  return 'Event Analysis\n\n${eventSections.join('\n\n')}';
}

String? _eventAnalysisBlock(
  CalendarPromptEvent event, {
  required List<DailySleepEntry> dailySleep,
  LocationSummary? location,
  ExpensesSummary? expenses,
  required bool includeSleep,
}) {
  final eventStart = _dateOnly(event.start);
  final eventEnd = _dateOnly(event.end);
  final beforeStart = eventStart.subtract(
    const Duration(days: calendarImpactWindowDays),
  );
  final beforeEnd = eventStart.subtract(const Duration(days: 1));
  final afterStart = eventEnd.add(const Duration(days: 1));
  final afterEnd = eventEnd.add(const Duration(days: calendarImpactWindowDays));

  final sleepBefore = includeSleep
      ? _averageSleepInWakeRange(dailySleep, beforeStart, beforeEnd)
      : null;
  final sleepDuring = includeSleep
      ? _averageSleepInWakeRange(dailySleep, eventStart, eventEnd)
      : null;
  final sleepAfter = includeSleep
      ? _averageSleepInWakeRange(dailySleep, afterStart, afterEnd)
      : null;

  final spendBefore = _spendingInRange(expenses, beforeStart, beforeEnd);
  final spendDuring = _spendingInRange(expenses, eventStart, eventEnd);
  final spendAfter = _spendingInRange(expenses, afterStart, afterEnd);

  final mobilityBefore = _mobilityInRange(location, beforeStart, beforeEnd);
  final mobilityDuring = _mobilityInRange(location, eventStart, eventEnd);
  final mobilityAfter = _mobilityInRange(location, afterStart, afterEnd);

  if (!_eventQualifiesForAnalysis(
    event: event,
    sleepBefore: sleepBefore,
    sleepDuring: sleepDuring,
    spendBefore: spendBefore,
    spendDuring: spendDuring,
    spendAfter: spendAfter,
    mobilityBefore: mobilityBefore,
    mobilityDuring: mobilityDuring,
    mobilityAfter: mobilityAfter,
  )) {
    return null;
  }

  final hasSpending =
      spendBefore != null || spendDuring != null || spendAfter != null;
  final hasMobility =
      mobilityBefore != null || mobilityDuring != null || mobilityAfter != null;

  if (!includeSleep && !hasSpending && !hasMobility) return null;

  final buffer = StringBuffer(event.impactLabel);
  var wroteSection = false;
  var hasActionableInsight = hasSpending || hasMobility;

  if (includeSleep) {
    buffer
      ..writeln()
      ..writeln()
      ..writeln('Sleep:')
      ..writeln('- Before: ${_formatSleepAverage(sleepBefore)}')
      ..writeln('- During: ${_formatSleepAverage(sleepDuring)}')
      ..writeln('- After: ${_formatSleepAverage(sleepAfter)}');
    if (sleepBefore != null && sleepDuring != null) {
      final deltaMinutes = sleepDuring.inMinutes - sleepBefore.inMinutes;
      buffer
        ..writeln(
          '- Difference: ${formatSignedDurationChange(Duration(minutes: deltaMinutes))}',
        )
        ..writeln(
          '- Confidence: ${_sleepImpactConfidence(sleepBefore, sleepDuring)}',
        );
      if (_sleepSignalIsActionable(sleepBefore, sleepDuring)) {
        hasActionableInsight = true;
      }
    } else {
      buffer.writeln('- Confidence: Insufficient Evidence');
    }
    wroteSection = true;
  }

  if (hasSpending) {
    if (wroteSection) buffer.writeln();
    buffer
      ..writeln('Spending:')
      ..writeln('- Before: ${_formatSpending(spendBefore, expenses?.currency)}')
      ..writeln('- During: ${_formatSpending(spendDuring, expenses?.currency)}')
      ..writeln('- After: ${_formatSpending(spendAfter, expenses?.currency)}');
    hasActionableInsight = true;
    wroteSection = true;
  }

  if (hasMobility) {
    if (wroteSection) buffer.writeln();
    buffer
      ..writeln('Mobility:')
      ..writeln('- Before: ${_formatMobility(mobilityBefore)}')
      ..writeln('- During: ${_formatMobility(mobilityDuring)}')
      ..writeln('- After: ${_formatMobility(mobilityAfter)}');
    hasActionableInsight = true;
    wroteSection = true;
  }

  final impactLines = _impactSummaryLines(
    sleepBefore: sleepBefore,
    sleepDuring: sleepDuring,
    sleepAfter: sleepAfter,
  );
  if (impactLines.isNotEmpty) {
    if (wroteSection) buffer.writeln();
    buffer.writeln('Impact:');
    for (final line in impactLines) {
      buffer.writeln('- $line');
    }
    hasActionableInsight = true;
  }

  if (!hasActionableInsight) return null;

  return buffer.toString().trimRight();
}

List<String> _impactSummaryLines({
  Duration? sleepBefore,
  Duration? sleepDuring,
  Duration? sleepAfter,
}) {
  final lines = <String>[];
  final disruption =
      sleepDuring != null &&
      sleepBefore != null &&
      sleepDuring.inMinutes < sleepBefore.inMinutes - 15;
  if (disruption) {
    lines.add('Sleep disruption detected');
  }

  final recovered =
      sleepAfter != null &&
      sleepBefore != null &&
      sleepAfter.inMinutes >= sleepBefore.inMinutes - 15;
  if (disruption) {
    lines.add(recovered ? 'Recovered' : 'Not recovered');
  }

  return lines;
}

bool _sleepSignalIsActionable(Duration before, Duration during) {
  final confidence = _sleepImpactConfidence(before, during);
  if (confidence == 'Moderate' || confidence == 'Strong') return true;
  return during.inMinutes < before.inMinutes - 15;
}

String _sleepImpactConfidence(Duration before, Duration during) {
  final deltaMinutes = (during.inMinutes - before.inMinutes).abs();
  if (deltaMinutes >= 60) return 'Strong';
  if (deltaMinutes >= 30) return 'Moderate';
  if (deltaMinutes >= 15) return 'Weak';
  return 'Insufficient Evidence';
}

bool _eventQualifiesForAnalysis({
  required CalendarPromptEvent event,
  Duration? sleepBefore,
  Duration? sleepDuring,
  double? spendBefore,
  double? spendDuring,
  double? spendAfter,
  ({double km, Duration time})? mobilityBefore,
  ({double km, Duration time})? mobilityDuring,
  ({double km, Duration time})? mobilityAfter,
}) {
  if (_eventDurationDays(event) > 1) return true;

  var hasMeaningfulSignal = false;

  if (sleepBefore != null &&
      sleepDuring != null &&
      _sleepSignalIsActionable(sleepBefore, sleepDuring)) {
    hasMeaningfulSignal = true;
  }

  final maxSpend = [spendBefore, spendDuring, spendAfter]
      .whereType<double>()
      .fold<double>(0, (max, value) => value > max ? value : max);
  if (maxSpend >= eventAnalysisMinSpendingBdt) hasMeaningfulSignal = true;

  final maxKm = [mobilityBefore, mobilityDuring, mobilityAfter]
      .whereType<({double km, Duration time})>()
      .fold<double>(0, (max, value) => value.km > max ? value.km : max);
  if (maxKm >= eventAnalysisMinMobilityKm) hasMeaningfulSignal = true;

  return hasMeaningfulSignal;
}

int _eventDurationDays(CalendarPromptEvent event) {
  return _dateOnly(event.end).difference(_dateOnly(event.start)).inDays + 1;
}

String buildSleepClusterCorrelationText(
  List<DailySleepEntry> dailySleep,
  List<CalendarPromptEvent> events,
) {
  final clusters = detectSleepClusters(dailySleep);
  if (clusters.isEmpty) return '';

  final sections = <String>[];
  for (final cluster in clusters) {
    CalendarPromptEvent? bestOverlap;
    var bestOverlapNights = 0;

    for (final event in events) {
      final overlapNights = _clusterNightsOverlappingEvent(
        dailySleep: dailySleep,
        clusterStart: cluster.start,
        clusterEnd: cluster.end,
        eventStart: _dateOnly(event.start),
        eventEnd: _dateOnly(event.end),
      );
      if (overlapNights > bestOverlapNights) {
        bestOverlapNights = overlapNights;
        bestOverlap = event;
      }
    }

    if (bestOverlap == null || bestOverlapNights <= 0) continue;

    sections.add(
      '''
Sleep Cluster:
${cluster.label}

Overlap:
${bestOverlap.impactLabel}

Cluster nights overlapping event:
$bestOverlapNights of ${cluster.shortCount}'''
          .trimRight(),
    );
  }

  if (sections.isEmpty) return '';
  return 'Sleep Cluster Correlation\n\n${sections.join('\n\n')}';
}

int _clusterNightsOverlappingEvent({
  required List<DailySleepEntry> dailySleep,
  required DateTime clusterStart,
  required DateTime clusterEnd,
  required DateTime eventStart,
  required DateTime eventEnd,
}) {
  return dailySleep
      .where(
        (night) =>
            night.hasData &&
            isSleepAnomalyNight(night) &&
            !_dateOnly(night.wakeDate).isBefore(clusterStart) &&
            !_dateOnly(night.wakeDate).isAfter(clusterEnd) &&
            !_dateOnly(night.wakeDate).isBefore(eventStart) &&
            !_dateOnly(night.wakeDate).isAfter(eventEnd),
      )
      .length;
}
