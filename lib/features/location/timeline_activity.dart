import 'dart:convert';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/period_range.dart';
import 'package:personal/features/location/mobility_prompt_builder.dart';
import 'package:personal/features/location/work_arrival_stats.dart';

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

  Duration get duration => endTime.difference(startTime);
}

class TimelinePlaceVisit {
  const TimelinePlaceVisit({
    required this.startTime,
    required this.endTime,
    required this.name,
    this.address,
    this.semanticType,
  });

  final DateTime startTime;
  final DateTime endTime;
  final String name;
  final String? address;
  final String? semanticType;

  bool get isWork => semanticType?.toUpperCase() == 'TYPE_WORK';

  bool get isHome => semanticType?.toUpperCase() == 'TYPE_HOME';

  Duration get duration => endTime.difference(startTime);
}

class TransportationModeSummary {
  const TransportationModeSummary({
    required this.type,
    required this.distanceMeters,
    required this.tripCount,
  });

  final String type;
  final double distanceMeters;
  final int tripCount;
}

class FrequentPlaceSummary {
  const FrequentPlaceSummary({
    required this.name,
    this.address,
    required this.visitCount,
    required this.totalDuration,
  });

  final String name;
  final String? address;
  final int visitCount;
  final Duration totalDuration;
}

class LocationSummary {
  const LocationSummary({
    required this.activities,
    this.placeVisits = const [],
    this.fileName,
  });

  final List<TimelineActivity> activities;
  final List<TimelinePlaceVisit> placeVisits;
  final String? fileName;

  bool get hasAnyData => activities.isNotEmpty || placeVisits.isNotEmpty;

  LocationSummary forAnalysisPeriod(AnalysisPeriod period) {
    return LocationSummary(
      activities: activitiesInRange(
        period.dataMonthStart,
        period.dataMonthEnd,
      ),
      placeVisits: placeVisitsInRange(period.dataMonthStart, period.dataMonthEnd),
      fileName: fileName,
    );
  }

  List<TimelineActivity> get periodMotorcyclingActivities => activities
      .where(
        (activity) => activity.isMotorcycling && activity.distanceMeters > 0,
      )
      .toList();

  double get periodMotorcycleDistanceMeters => periodMotorcyclingActivities.fold(
    0,
    (sum, activity) => sum + activity.distanceMeters,
  );

  double get periodTotalDistanceMeters => activities.fold(
    0,
    (sum, activity) => sum + activity.distanceMeters,
  );

  Duration get periodMotorcycleTravelTime => periodMotorcyclingActivities.fold(
    Duration.zero,
    (sum, activity) => sum + activity.duration,
  );

  List<TimelineActivity> get sortedPeriodMotorcyclingActivities {
    final copy = List<TimelineActivity>.from(periodMotorcyclingActivities)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return copy;
  }

  List<TimelineActivity> periodMotorcycleActivitiesOnWeekendDays(
    List<int> weekendDays,
  ) {
    if (weekendDays.isEmpty) return const [];
    final weekendSet = weekendDays.toSet();
    return periodMotorcyclingActivities
        .where((a) => weekendSet.contains(a.startTime.toLocal().weekday))
        .toList();
  }

  List<TransportationModeSummary> get periodTransportationByType {
    final map = <String, TransportationModeSummary>{};
    for (final activity in activities) {
      if (activity.distanceMeters <= 0) continue;
      final typeKey = activity.type.toUpperCase().trim();
      final previous = map[typeKey];
      map[typeKey] = TransportationModeSummary(
        type: typeKey,
        distanceMeters:
            (previous?.distanceMeters ?? 0) + activity.distanceMeters,
        tripCount: (previous?.tripCount ?? 0) + 1,
      );
    }

    final sorted = map.values.toList()
      ..sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters));
    return sorted;
  }

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

  List<TimelinePlaceVisit> placeVisitsInRange(DateTime start, DateTime end) {
    return placeVisits.where((visit) {
      final localStart = visit.startTime.toLocal();
      return !localStart.isBefore(start) && !localStart.isAfter(end);
    }).toList();
  }

  List<FrequentPlaceSummary> frequentPlaces({
    int limit = 5,
  }) {
    final grouped = <String, FrequentPlaceSummary>{};
    for (final visit in placeVisits) {
      final key = '${visit.name}|${visit.address ?? ''}';
      final previous = grouped[key];
      grouped[key] = FrequentPlaceSummary(
        name: visit.name,
        address: visit.address,
        visitCount: (previous?.visitCount ?? 0) + 1,
        totalDuration:
            (previous?.totalDuration ?? Duration.zero) + visit.duration,
      );
    }

    final sorted = grouped.values.toList()
      ..sort((a, b) {
        final countOrder = b.visitCount.compareTo(a.visitCount);
        if (countOrder != 0) return countOrder;
        return b.totalDuration.compareTo(a.totalDuration);
      });
    if (sorted.length <= limit) return sorted;
    return sorted.take(limit).toList();
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
    String? workAddress,
    String? workHours,
    List<int> weekendDays = const [],
    MobilityFuelSummary? fuel,
  }) {
    return buildMobilityPromptText(
      summary: this,
      referenceDate: referenceDate,
      dataMonthStart: dataMonthStart,
      dataMonthEnd: dataMonthEnd,
      workAddress: workAddress ?? '',
      workHours: workHours ?? '',
      weekendDays: weekendDays,
      fuel: fuel,
    );
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

String formatTravelDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
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

List<TimelinePlaceVisit> parseTimelineJsonPlaceVisits(String rawJson) {
  final decoded = _decodeRoot(rawJson);
  final segments = decoded['semanticSegments'];
  if (segments is! List) return const [];

  final visits = <TimelinePlaceVisit>[];
  for (final item in segments) {
    if (item is! Map) continue;
    final placeVisit = item['visit'] ?? item['placeVisit'];
    if (placeVisit is! Map) continue;

    final startTime = _parseDate(item['startTime']);
    final endTime = _parseDate(item['endTime']);
    final topCandidate = placeVisit['topCandidate'];
    final location = placeVisit['location'];
    final placeNameRaw = _firstNonEmptyString([
      if (topCandidate is Map) topCandidate['name'],
      if (location is Map) location['name'],
    ]);
    final addressRaw = _firstNonEmptyString([
      if (topCandidate is Map) topCandidate['address'],
      if (location is Map) location['address'],
    ]);
    final semanticType = _normalizeSemanticType(_firstNonEmptyString([
      if (topCandidate is Map) topCandidate['semanticType'],
      if (location is Map) location['semanticType'],
      placeVisit['semanticType'],
    ]));
    final placeName = placeNameRaw?.trim();
    final address = addressRaw?.trim();

    if (startTime == null || endTime == null) continue;
    if ((placeName == null || placeName.isEmpty) && semanticType == null) {
      continue;
    }

    visits.add(
      TimelinePlaceVisit(
        startTime: startTime,
        endTime: endTime,
        name: placeName ?? _labelForSemanticType(semanticType) ?? 'Unknown place',
        address: address == null || address.isEmpty ? null : address,
        semanticType: semanticType,
      ),
    );
  }
  return visits;
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

String? _firstNonEmptyString(List<dynamic> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

String? _normalizeSemanticType(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final upper = raw.toUpperCase();
  if (upper == 'UNKNOWN' || upper == 'TYPE_UNKNOWN') return null;
  if (upper.startsWith('TYPE_')) return upper;
  return 'TYPE_$upper';
}

String? _labelForSemanticType(String? semanticType) {
  return switch (semanticType) {
    'TYPE_WORK' => 'Work',
    'TYPE_HOME' => 'Home',
    _ => null,
  };
}
