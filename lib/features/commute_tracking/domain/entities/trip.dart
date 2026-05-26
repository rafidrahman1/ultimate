import 'route_point.dart';

/// A completed motorcycle commute logged by background tracking.
class Trip {
  const Trip({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.totalDistanceKm,
    required this.route,
  });

  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double totalDistanceKm;
  final List<RoutePoint> route;

  Duration get duration => endTime.difference(startTime);
}
