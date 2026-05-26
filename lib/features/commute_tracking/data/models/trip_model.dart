import '../../domain/entities/route_point.dart';
import '../../domain/entities/trip.dart';

class TripModel {
  TripModel({
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
  final List<RoutePointModel> route;

  factory TripModel.fromDomain(Trip trip) {
    return TripModel(
      id: trip.id,
      startTime: trip.startTime,
      endTime: trip.endTime,
      totalDistanceKm: trip.totalDistanceKm,
      route: trip.route.map(RoutePointModel.fromDomain).toList(),
    );
  }

  Trip toDomain() {
    return Trip(
      id: id,
      startTime: startTime,
      endTime: endTime,
      totalDistanceKm: totalDistanceKm,
      route: route.map((p) => p.toDomain()).toList(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'total_distance_km': totalDistanceKm,
      'route_json': RoutePointModel.encodeList(route),
    };
  }

  factory TripModel.fromMap(Map<String, Object?> map) {
    return TripModel(
      id: map['id']! as String,
      startTime: DateTime.parse(map['start_time']! as String),
      endTime: DateTime.parse(map['end_time']! as String),
      totalDistanceKm: (map['total_distance_km']! as num).toDouble(),
      route: RoutePointModel.decodeList(map['route_json']! as String),
    );
  }
}

class RoutePointModel {
  RoutePointModel({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;

  factory RoutePointModel.fromDomain(RoutePoint point) {
    return RoutePointModel(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: point.timestamp,
    );
  }

  RoutePoint toDomain() {
    return RoutePoint(
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
    );
  }

  Map<String, Object?> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'ts': timestamp.toUtc().toIso8601String(),
      };

  factory RoutePointModel.fromJson(Map<String, dynamic> json) {
    return RoutePointModel(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      timestamp: DateTime.parse(json['ts'] as String),
    );
  }

  static String encodeList(List<RoutePointModel> points) {
    final buffer = StringBuffer();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      if (i > 0) buffer.write('|');
      buffer
        ..write(p.latitude)
        ..write(',')
        ..write(p.longitude)
        ..write(',')
        ..write(p.timestamp.toUtc().toIso8601String());
    }
    return buffer.toString();
  }

  static List<RoutePointModel> decodeList(String raw) {
    if (raw.isEmpty) return const [];
    return raw.split('|').map((segment) {
      final parts = segment.split(',');
      return RoutePointModel(
        latitude: double.parse(parts[0]),
        longitude: double.parse(parts[1]),
        timestamp: DateTime.parse(parts[2]),
      );
    }).toList();
  }
}
