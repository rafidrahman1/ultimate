import 'dart:convert';

import '../../core/period_range.dart';

class TimelineActivity {
  const TimelineActivity({
    required this.startTime,
    required this.endTime,
    required this.type,
    required this.distanceMeters,
    this.probability,
  });

  final DateTime startTime;
  final DateTime endTime;
  final String type;
  final double distanceMeters;
  final double? probability;

  bool get isMotorcycling => type.toUpperCase() == 'MOTORCYCLING';
}

class LocationSummary {
  const LocationSummary({required this.activities, this.fileName});

  final List<TimelineActivity> activities;
  final String? fileName;

  List<TimelineActivity> get monthToDateActivities => activitiesInMonthToDate();

  List<TimelineActivity> get motorcyclingActivities => monthToDateActivities
      .where(
        (activity) => activity.isMotorcycling && activity.distanceMeters > 0,
      )
      .toList();

  double get totalDistanceMeters => monthToDateActivities.fold(
    0,
    (sum, activity) => sum + activity.distanceMeters,
  );

  double get motorcycleDistanceMeters => motorcyclingActivities.fold(
    0,
    (sum, activity) => sum + activity.distanceMeters,
  );

  double get motorcycleDistanceKm => motorcycleDistanceMeters / 1000.0;

  DateTime? get periodStart =>
      minDateTime(monthToDateActivities.map((a) => a.startTime));

  DateTime? get periodEnd =>
      maxDateTime(monthToDateActivities.map((a) => a.endTime));

  String? get periodRangeLabel {
    final start = periodStart;
    final end = periodEnd;
    if (start == null || end == null) return null;
    return formatPeriodRange(start, end);
  }

  List<TimelineActivity> get sortedMotorcyclingActivities {
    final copy = List<TimelineActivity>.from(motorcyclingActivities)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return copy;
  }

  List<TimelineActivity> activitiesInMonthToDate({DateTime? referenceDate}) {
    final range = _monthToDateRange(referenceDate: referenceDate);
    return activities.where((activity) {
      final localStart = activity.startTime.toLocal();
      return !localStart.isBefore(range.start) &&
          !localStart.isAfter(range.end);
    }).toList();
  }

  List<TimelineActivity> activitiesInRange(DateTime start, DateTime end) {
    return activities.where((activity) {
      final localStart = activity.startTime.toLocal();
      return !localStart.isBefore(start) && !localStart.isAfter(end);
    }).toList();
  }

  List<TimelineActivity> activitiesInCalendarMonth(DateTime monthStart) {
    final range = calendarMonthRange(monthStart);
    return activitiesInRange(range.start, range.end);
  }

  List<TimelineActivity> motorcyclingActivitiesInCalendarMonth(
    DateTime monthStart,
  ) {
    return activitiesInCalendarMonth(monthStart)
        .where(
          (activity) => activity.isMotorcycling && activity.distanceMeters > 0,
        )
        .toList();
  }

  double motorcycleDistanceMetersInCalendarMonth(DateTime monthStart) {
    return motorcyclingActivitiesInCalendarMonth(monthStart).fold(
      0,
      (sum, activity) => sum + activity.distanceMeters,
    );
  }

  List<TimelineActivity> motorcyclingActivitiesInMonthToDate({
    DateTime? referenceDate,
  }) {
    final filtered = activitiesInMonthToDate(referenceDate: referenceDate);
    return filtered
        .where(
          (activity) => activity.isMotorcycling && activity.distanceMeters > 0,
        )
        .toList();
  }

  double motorcycleDistanceMetersInMonthToDate({DateTime? referenceDate}) {
    final rides = motorcyclingActivitiesInMonthToDate(
      referenceDate: referenceDate,
    );
    return rides.fold(0, (sum, activity) => sum + activity.distanceMeters);
  }

  String monthToDateRangeLabel({DateTime? referenceDate}) {
    final range = _monthToDateRange(referenceDate: referenceDate);
    return formatPeriodRange(range.start, range.end);
  }

  /// Month anchor for calendar sync — matches month-to-date location analysis,
  /// or the month of the newest timeline segment when this month has no data.
  DateTime calendarReferenceMonth({DateTime? referenceDate}) {
    final reference = (referenceDate ?? DateTime.now()).toLocal();
    if (activities.isEmpty) {
      return DateTime(reference.year, reference.month, 1);
    }

    if (activitiesInMonthToDate(referenceDate: reference).isNotEmpty) {
      return DateTime(reference.year, reference.month, 1);
    }

    final latest = maxDateTime(activities.map((activity) => activity.startTime));
    if (latest == null) {
      return DateTime(reference.year, reference.month, 1);
    }

    final local = latest.toLocal();
    return DateTime(local.year, local.month, 1);
  }

  String toAnalysisPromptText({
    DateTime? referenceDate,
    DateTime? dataMonthStart,
    DateTime? dataMonthEnd,
  }) {
    if (activities.isEmpty) return 'No location timeline data imported.';
    final String range;
    final List<TimelineActivity> bikes;
    final double distanceMeters;
    if (dataMonthStart != null && dataMonthEnd != null) {
      range = formatPeriodRange(dataMonthStart, dataMonthEnd);
      bikes = activitiesInRange(dataMonthStart, dataMonthEnd)
          .where(
            (activity) =>
                activity.isMotorcycling && activity.distanceMeters > 0,
          )
          .toList();
      distanceMeters = bikes.fold(
        0,
        (sum, activity) => sum + activity.distanceMeters,
      );
    } else {
      range = monthToDateRangeLabel(referenceDate: referenceDate);
      bikes = motorcyclingActivitiesInMonthToDate(referenceDate: referenceDate);
      distanceMeters = motorcycleDistanceMetersInMonthToDate(
        referenceDate: referenceDate,
      );
    }
    if (bikes.isEmpty) {
      return 'Period: $range\nNo motorcycle activity found in this period.';
    }

    final totalKm = (distanceMeters / 1000).toStringAsFixed(2);
    final lines = <String>[
      'Period: $range',
      'Motorcycle total distance: $totalKm km',
    ];

    return lines.join('\n');
  }

  ({DateTime start, DateTime end}) _monthToDateRange({
    DateTime? referenceDate,
  }) {
    final now = (referenceDate ?? DateTime.now()).toLocal();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999, 999);
    return (start: start, end: end);
  }

}

List<TimelineActivity> parseTimelineJsonActivities(String rawJson) {
  final decoded = _decodeRoot(rawJson);
  final segments = decoded['semanticSegments'];
  if (segments is! List) return const [];

  final activities = <TimelineActivity>[];
  for (final item in segments) {
    if (item is! Map) continue;
    final activity = item['activity'];
    if (activity is! Map) continue;

    final startTimeRaw = item['startTime'];
    final endTimeRaw = item['endTime'];
    final distanceRaw = activity['distanceMeters'];
    final topCandidate = activity['topCandidate'];
    final typeRaw = topCandidate is Map ? topCandidate['type'] : null;
    final probabilityRaw = topCandidate is Map
        ? topCandidate['probability']
        : null;

    final startTime = _parseDate(startTimeRaw);
    final endTime = _parseDate(endTimeRaw);
    final distance = _parseDouble(distanceRaw);
    final type = typeRaw?.toString();

    if (startTime == null ||
        endTime == null ||
        distance == null ||
        distance <= 0 ||
        type == null ||
        type.isEmpty) {
      continue;
    }

    activities.add(
      TimelineActivity(
        startTime: startTime,
        endTime: endTime,
        type: type,
        distanceMeters: distance,
        probability: _parseDouble(probabilityRaw),
      ),
    );
  }
  return activities;
}

Map<String, dynamic> _decodeRoot(String rawJson) {
  final decoded = jsonDecode(rawJson);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Timeline JSON root must be an object.');
  }
  return decoded;
}

DateTime? _parseDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

double? _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
