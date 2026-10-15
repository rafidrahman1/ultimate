import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/core/period/period_range.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/location/analysis/mobility_prompt_builder.dart';
import 'package:personal/features/location/analysis/place_stats.dart';
import 'package:personal/features/location/analysis/work_arrival_stats.dart';
import 'package:personal/features/location/data/timeline_profile.dart';

part 'timeline_export_parser.dart';

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
    this.placeId,
    this.point,
    this.level = 0,
    this.probability,
  });

  final DateTime startTime;
  final DateTime endTime;
  final String name;
  final String? address;
  final String? semanticType;

  /// Stable Google place id. On-device exports carry this instead of a name.
  final String? placeId;
  final GeoPoint? point;

  /// 0 for a top-level visit; 1 for a short stop nested inside one (e.g. a
  /// shop inside a mall). Nested visits overlap their parent in time, so
  /// dwell-time sums must skip them.
  final int level;
  final double? probability;

  bool get isNested => level > 0;

  bool get isWork => semanticType?.toUpperCase() == 'TYPE_WORK';

  bool get isHome => semanticType?.toUpperCase() == 'TYPE_HOME';

  /// Google's guess, as opposed to a place you confirmed.
  bool get isInferredWork =>
      semanticType?.toUpperCase() == 'TYPE_INFERRED_WORK';

  bool get isInferredHome =>
      semanticType?.toUpperCase() == 'TYPE_INFERRED_HOME';

  bool get isAtHome => isHome || isInferredHome;

  bool get isAtWork => isWork || isInferredWork;

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
    this.profile = LocationProfile.empty,
    this.trips = const [],
    this.insights,
    this.placeNames = const {},
    this.isLegacyCache = false,
    this.fileName,
  });

  final List<TimelineActivity> activities;
  final List<TimelinePlaceVisit> placeVisits;

  /// Routines and labelled places from the export's `userLocationProfile`.
  final LocationProfile profile;

  /// Multi-day trips Google summarised.
  final List<TimelineTrip> trips;

  /// Place insights for the period this summary was filtered to, computed
  /// against the whole export (so "new places" sees earlier months). Only set
  /// by [forAnalysisPeriod].
  final LocationInsights? insights;

  /// Names the user gave places, by place id.
  final Map<String, String> placeNames;

  /// True for a summary restored from a cache written before place ids and
  /// the profile were parsed. It works, but a re-import adds the new detail.
  final bool isLegacyCache;
  final String? fileName;

  bool get hasAnyData => activities.isNotEmpty || placeVisits.isNotEmpty;

  LocationSummary forAnalysisPeriod(
    AnalysisPeriod period, {
    Map<String, String> placeNames = const {},
  }) {
    return LocationSummary(
      activities: activitiesInRange(period.dataMonthStart, period.dataMonthEnd),
      placeVisits: placeVisitsInRange(
        period.dataMonthStart,
        period.dataMonthEnd,
      ),
      profile: profile,
      trips: trips
          .where(
            (trip) =>
                !trip.startTime.toLocal().isAfter(period.dataMonthEnd) &&
                !trip.endTime.toLocal().isBefore(period.dataMonthStart),
          )
          .toList(),
      insights: computeLocationInsights(
        this,
        period.dataMonthStart,
        period.dataMonthEnd,
      ),
      placeNames: placeNames,
      fileName: fileName,
    );
  }

  List<TimelineActivity> get periodMotorcyclingActivities => activities
      .where(
        (activity) => activity.isMotorcycling && activity.distanceMeters > 0,
      )
      .toList();

  double get periodMotorcycleDistanceMeters => periodMotorcyclingActivities
      .fold(0, (sum, activity) => sum + activity.distanceMeters);

  double get periodTotalDistanceMeters =>
      activities.fold(0, (sum, activity) => sum + activity.distanceMeters);

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

  List<FrequentPlaceSummary> frequentPlaces({int limit = 5}) {
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
    return motorcyclingActivitiesInCalendarMonth(
      monthStart,
    ).fold(0, (sum, activity) => sum + activity.distanceMeters);
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

    final latest = maxDateTime(
      activities.map((activity) => activity.startTime),
    );
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
    WorkArrivalStats? previousWorkStats,
    LocationInsights? previousInsights,
    List<DailySleepEntry> dailySleep = const [],
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
      previousWorkStats: previousWorkStats,
      previousInsights: previousInsights,
      dailySleep: dailySleep,
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
