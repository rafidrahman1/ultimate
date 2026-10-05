import 'dart:math' as math;

/// A latitude/longitude pair parsed from a Timeline export.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  /// Great-circle distance in metres.
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    final dLat = _rad(other.latitude - latitude);
    final dLng = _rad(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(latitude)) *
            math.cos(_rad(other.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
  }

  static double _rad(double degrees) => degrees * math.pi / 180;
}

final _geoPattern = RegExp(r'(-?\d+(?:\.\d+)?)°?\s*,\s*(-?\d+(?:\.\d+)?)°?');

/// Parses `"23.8679331°, 90.4053536°"` (the export's format) or a plain
/// `"23.86,90.40"`. Returns null for anything else, including out-of-range
/// values.
GeoPoint? parseGeoPoint(Object? raw) {
  if (raw is! String) return null;
  final match = _geoPattern.firstMatch(raw);
  if (match == null) return null;
  final lat = double.tryParse(match.group(1)!);
  final lng = double.tryParse(match.group(2)!);
  if (lat == null || lng == null) return null;
  if (lat.abs() > 90 || lng.abs() > 180) return null;
  return GeoPoint(lat, lng);
}

/// A place Google has learned you return to. Only HOME and WORK carry a label.
class ProfilePlace {
  const ProfilePlace({required this.placeId, required this.point, this.label});

  final String placeId;
  final GeoPoint point;
  final String? label;

  bool get isHome => label?.toUpperCase() == 'HOME';
  bool get isWork => label?.toUpperCase() == 'WORK';
}

enum CommuteDirection {
  homeToWork,
  workToHome,
  other;

  static CommuteDirection parse(Object? raw) {
    final text = raw?.toString().toUpperCase() ?? '';
    if (text.contains('HOME_TO_WORK')) return CommuteDirection.homeToWork;
    if (text.contains('WORK_TO_HOME')) return CommuteDirection.workToHome;
    return CommuteDirection.other;
  }
}

/// One of the routines Google detected, e.g. "home → work, leaves 08:05".
class FrequentTrip {
  const FrequentTrip({
    required this.direction,
    required this.weekday,
    required this.startMinutes,
    required this.durationMinutes,
    this.confidence,
    this.modeShares = const {},
  });

  final CommuteDirection direction;

  /// [DateTime.monday]..[DateTime.sunday]. The export packs the weekday and
  /// time into one number (minutes since Monday 00:00); this is the weekday.
  final int weekday;

  /// Minutes after local midnight on [weekday].
  final int startMinutes;
  final int durationMinutes;
  final double? confidence;

  /// Share of the routine spent in each mode, 0–1.
  final Map<String, double> modeShares;

  int get endMinutes => startMinutes + durationMinutes;

  String? get dominantMode {
    if (modeShares.isEmpty) return null;
    return modeShares.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

/// What the export's `userLocationProfile` says about you.
class LocationProfile {
  const LocationProfile({
    this.places = const [],
    this.trips = const [],
    this.modeAffinities = const {},
  });

  static const empty = LocationProfile();

  final List<ProfilePlace> places;
  final List<FrequentTrip> trips;

  /// Mode → how strongly it describes you (0–1).
  final Map<String, double> modeAffinities;

  bool get isEmpty => places.isEmpty && trips.isEmpty && modeAffinities.isEmpty;

  GeoPoint? get home => _labelled((p) => p.isHome);
  GeoPoint? get work => _labelled((p) => p.isWork);

  GeoPoint? _labelled(bool Function(ProfilePlace) test) {
    for (final place in places) {
      if (test(place)) return place.point;
    }
    return null;
  }

  List<FrequentTrip> tripsFor(CommuteDirection direction) =>
      trips.where((trip) => trip.direction == direction).toList();
}

/// A multi-day trip Google summarised (`timelineMemory`), e.g. a holiday.
class TimelineTrip {
  const TimelineTrip({
    required this.startTime,
    required this.endTime,
    required this.distanceFromOriginKm,
    this.destinationPlaceIds = const [],
  });

  final DateTime startTime;
  final DateTime endTime;
  final int distanceFromOriginKm;
  final List<String> destinationPlaceIds;

  Duration get duration => endTime.difference(startTime);
}

LocationProfile parseTimelineProfile(Map<String, dynamic> root) {
  final raw = root['userLocationProfile'];
  if (raw is! Map) return LocationProfile.empty;

  final places = <ProfilePlace>[];
  final rawPlaces = raw['frequentPlaces'];
  if (rawPlaces is List) {
    for (final item in rawPlaces) {
      if (item is! Map) continue;
      final id = item['placeId']?.toString();
      final point = parseGeoPoint(item['placeLocation']);
      if (id == null || id.isEmpty || point == null) continue;
      final label = item['label']?.toString();
      places.add(
        ProfilePlace(
          placeId: id,
          point: point,
          label: label == null || label.isEmpty ? null : label,
        ),
      );
    }
  }

  final trips = <FrequentTrip>[];
  final rawTrips = raw['frequentTrips'];
  if (rawTrips is List) {
    for (final item in rawTrips) {
      if (item is! Map) continue;
      final start = (item['startTimeMinutes'] as num?)?.toInt();
      final duration = (item['durationMinutes'] as num?)?.toInt();
      if (start == null || duration == null || duration <= 0) continue;
      final shares = <String, double>{};
      final distribution = item['modeDistribution'];
      if (distribution is List) {
        for (final entry in distribution) {
          if (entry is! Map) continue;
          final mode = entry['mode']?.toString();
          final rate = (entry['rate'] as num?)?.toDouble();
          if (mode == null || rate == null) continue;
          shares[mode] = rate;
        }
      }
      // `startTimeMinutes` counts from Monday 00:00 (0 = Monday).
      trips.add(
        FrequentTrip(
          direction: CommuteDirection.parse(item['commuteDirection']),
          weekday: (start ~/ 1440) % 7 + 1,
          startMinutes: start % 1440,
          durationMinutes: duration,
          confidence: (item['confidence'] as num?)?.toDouble(),
          modeShares: shares,
        ),
      );
    }
  }

  final affinities = <String, double>{};
  final persona = raw['persona'];
  final rawAffinities = persona is Map ? persona['travelModeAffinities'] : null;
  if (rawAffinities is List) {
    for (final entry in rawAffinities) {
      if (entry is! Map) continue;
      final mode = entry['mode']?.toString();
      final value = (entry['affinity'] as num?)?.toDouble();
      if (mode == null || value == null) continue;
      affinities[mode] = value;
    }
  }

  return LocationProfile(
    places: places,
    trips: trips,
    modeAffinities: affinities,
  );
}

List<TimelineTrip> parseTimelineTrips(Map<String, dynamic> root) {
  final segments = root['semanticSegments'];
  if (segments is! List) return const [];
  final trips = <TimelineTrip>[];
  for (final item in segments) {
    if (item is! Map) continue;
    final memory = item['timelineMemory'];
    final trip = memory is Map ? memory['trip'] : null;
    if (trip is! Map) continue;
    final start = DateTime.tryParse(item['startTime']?.toString() ?? '');
    final end = DateTime.tryParse(item['endTime']?.toString() ?? '');
    final distance = (trip['distanceFromOriginKms'] as num?)?.toInt();
    if (start == null || end == null || distance == null) continue;
    final ids = <String>[];
    final destinations = trip['destinations'];
    if (destinations is List) {
      for (final destination in destinations) {
        final identifier = destination is Map
            ? destination['identifier']
            : null;
        final id = identifier is Map ? identifier['placeId']?.toString() : null;
        if (id != null && id.isNotEmpty) ids.add(id);
      }
    }
    trips.add(
      TimelineTrip(
        startTime: start,
        endTime: end,
        distanceFromOriginKm: distance,
        destinationPlaceIds: ids,
      ),
    );
  }
  return trips;
}
