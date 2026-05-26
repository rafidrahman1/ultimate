import 'package:geolocator/geolocator.dart';

import '../../domain/entities/route_point.dart';
import '../../domain/value_objects/location_sample.dart';

/// In-memory state for an active GPS commute session.
class ActiveTripSession {
  ActiveTripSession({required this.startTime});

  final DateTime startTime;
  final List<RoutePoint> points = [];
  double distanceInMeters = 0;

  RoutePoint? _lastPoint;

  void addSample(LocationSample sample) {
    final point = RoutePoint(
      latitude: sample.latitude,
      longitude: sample.longitude,
      timestamp: sample.timestamp,
    );

    final previous = _lastPoint;
    if (previous != null) {
      distanceInMeters += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        point.latitude,
        point.longitude,
      );
    }

    points.add(point);
    _lastPoint = point;
  }

  bool get hasRoute => points.length >= 2;

  double get totalDistanceKm => distanceInMeters / 1000;
}
