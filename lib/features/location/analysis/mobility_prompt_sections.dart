part of 'mobility_prompt_builder.dart';

void _writeTravel(
  StringBuffer buffer,
  List<TimelineActivity> activities, {
  List<int> weekendDays = const [],
}) {
  final distanceMeters = activities.fold(
    0.0,
    (sum, activity) => sum + activity.distanceMeters,
  );
  final travelTime = activities.fold(
    Duration.zero,
    (sum, activity) => sum + activity.duration,
  );

  buffer
    ..writeln()
    ..writeln()
    ..writeln('Travel:')
    ..writeln('- Distance: ${(distanceMeters / 1000).toStringAsFixed(2)} km')
    ..writeln('- Travel Time: ${formatTravelDuration(travelTime)}');

  if (weekendDays.isEmpty) return;

  final weekendSet = weekendDays.toSet();
  final distanceByDate = <DateTime, double>{};
  for (final trip in activities) {
    if (!weekendSet.contains(trip.startTime.toLocal().weekday)) continue;
    final local = trip.startTime.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    distanceByDate[date] = (distanceByDate[date] ?? 0) + trip.distanceMeters;
  }
  if (distanceByDate.isEmpty) return;

  buffer.writeln('- Weekend motorcycle (${formatWeekdayList(weekendDays)}):');
  final sortedDates = distanceByDate.keys.toList()..sort();
  for (final date in sortedDates) {
    buffer.writeln(
      '- ${formatMobilityDate(date)}: '
      '${(distanceByDate[date]! / 1000).toStringAsFixed(2)} km',
    );
  }
}

String _hoursText(double hours) => '${hours.toStringAsFixed(1)} h';

String _clockText(int minutesAfterMidnight) =>
    '${(minutesAfterMidnight ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutesAfterMidnight % 60).toString().padLeft(2, '0')}';

/// Where time went, commute, and the places visited. Deliberately text-only:
/// no coordinates and no place ids, and unnamed places are counted rather
/// than listed, so the prompt reveals no addresses.
void _writePlacesAndTime(
  StringBuffer buffer,
  LocationInsights insights, {
  LocationInsights? previous,
  Map<String, String> names = const {},
}) {
  final split = insights.split;
  buffer
    ..writeln()
    ..writeln()
    ..writeln('Places & Time:');

  if (split.hasData) {
    buffer.writeln(
      '- Time per tracked day: home ${_hoursText(split.homeHoursPerDay)}, '
      'work ${_hoursText(split.workHoursPerDay)}, '
      'elsewhere ${_hoursText(split.elsewhereHoursPerDay)} '
      '(${split.days} days with location data)',
    );
    final awayNow = split.workHoursPerDay + split.elsewhereHoursPerDay;
    final previousSplit = previous?.split;
    if (previousSplit != null && previousSplit.hasData) {
      final awayBefore =
          previousSplit.workHoursPerDay + previousSplit.elsewhereHoursPerDay;
      buffer.writeln(
        '- Time away from home: ${_hoursText(awayNow)}/day '
        '(previous period ${_hoursText(awayBefore)}/day)',
      );
    } else {
      buffer.writeln('- Time away from home: ${_hoursText(awayNow)}/day');
    }
  }

  final newPlaces = insights.newPlaces;
  buffer.writeln(
    '- Places visited: ${insights.uniquePlaces}'
    '${newPlaces == null ? '' : ' ($newPlaces not seen in earlier months)'}',
  );

  final furthest = insights.furthestFromHomeKm;
  final furthestOn = insights.furthestOn;
  if (furthest != null && furthest >= 1 && furthestOn != null) {
    buffer.writeln(
      '- Furthest from home: ${furthest.round()} km on '
      '${formatMobilityDate(furthestOn)}',
    );
  }

  final listed = insights.places
      .where((place) => place.kind != PlaceKind.other || _isNamed(place, names))
      .take(4)
      .toList();
  if (listed.isNotEmpty) {
    buffer.writeln('- Top places by time:');
    for (final place in listed) {
      buffer.writeln(
        '  - ${placeDisplayName(place, names)}: ${place.visits} visits, '
        '${_hoursText(place.totalDwell.inMinutes / 60)} total',
      );
    }
  }
  final unnamedOthers = insights.places
      .where(
        (place) => place.kind == PlaceKind.other && !_isNamed(place, names),
      )
      .length;
  if (unnamedOthers > 0) {
    buffer.writeln('- Other (unnamed) places: $unnamedOthers');
  }

  final commute = insights.commute;
  if (commute.hasData) {
    buffer
      ..writeln()
      ..writeln('Commute (door to door, home/work visit to visit):');
    void line(String label, List<CommuteSample> samples) {
      if (samples.isEmpty) return;
      final average = CommuteStats.averageDuration(samples)!;
      final departure = CommuteStats.averageDepartureMinutes(samples)!;
      final longest = samples
          .map((s) => s.duration)
          .reduce((a, b) => a > b ? a : b);
      buffer.writeln(
        '- $label: average ${formatTravelDuration(average)} over '
        '${samples.length} days, usually leaves ${_clockText(departure)}, '
        'longest ${formatTravelDuration(longest)}',
      );
    }

    line('To work', commute.toWork);
    line('Back home', commute.toHome);
  }
}

bool _isNamed(PlaceStat place, Map<String, String> names) =>
    place.placeIds.any((id) => (names[id] ?? '').isNotEmpty);

void _writeTripsAway(StringBuffer buffer, List<TimelineTrip> trips) {
  final sorted = List<TimelineTrip>.of(trips)
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  buffer
    ..writeln()
    ..writeln()
    ..writeln('Trips away from home:');
  for (final trip in sorted) {
    final days = trip.duration.inDays.clamp(1, 9999);
    buffer.writeln(
      '- ${formatMobilityDate(trip.startTime)} to '
      '${formatMobilityDate(trip.endTime)}: up to '
      '${trip.distanceFromOriginKm} km from home ($days days)',
    );
  }
}

void _writeWorkAttendance(StringBuffer buffer, WorkArrivalStats workStats) {
  buffer
    ..writeln()
    ..writeln('Attendance Summary:')
    ..writeln('- Workdays: ${workStats.totalWorkDays}');

  if (!workStats.hasLateThreshold) return;

  buffer
    ..writeln('- Late arrivals: ${workStats.lateArrivalCount}')
    ..writeln(
      '- Late arrival rate: '
      '${_formatLateArrivalRate(workStats.lateArrivalCount, workStats.totalWorkDays)}',
    );

  final avgDelay = workStats.averageDelayMinutes;
  if (avgDelay != null) {
    buffer.writeln('- Average delay: ${avgDelay.round()} min');
  }
  final worstDelay = workStats.worstDelayMinutes;
  if (worstDelay != null) {
    buffer.writeln('- Worst delay: $worstDelay min');
  }
  if (workStats.lateArrivalCount > 0) {
    buffer.writeln('- Total late minutes: ${workStats.totalLateMinutes}');
  }
}

void _writeLateArrivals(StringBuffer buffer, WorkArrivalStats workStats) {
  buffer
    ..writeln()
    ..writeln('Late Arrival:');

  for (final arrival in workStats.lateArrivals) {
    final scheduled = arrival.scheduledArrival;
    buffer
      ..writeln('- ${formatMobilityDate(arrival.date)}')
      ..writeln(
        '  Scheduled: ${scheduled == null ? 'n/a' : formatMobilityTime(scheduled)}',
      )
      ..writeln('  Actual: ${formatMobilityTime(arrival.arrivalTime)}')
      ..writeln('  Delay: ${arrival.delayMinutes ?? 0} min');
  }
}
