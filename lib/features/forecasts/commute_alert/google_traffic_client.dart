import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:personal/features/forecasts/commute_alert/commute_estimate.dart';
import 'package:personal/features/location/data/timeline_profile.dart';

/// How you get to work, as Google's Routes API names it.
enum CommuteTravelMode {
  twoWheeler('TWO_WHEELER', 'Motorbike'),
  drive('DRIVE', 'Car');

  const CommuteTravelMode(this.apiName, this.label);

  final String apiName;
  final String label;

  static CommuteTravelMode fromName(String? name) =>
      values.where((m) => m.name == name).firstOrNull ?? twoWheeler;
}

// Sent so a key restricted to this Android app is accepted.
const _androidPackage = 'com.redpanda.personal';
const _androidCertSha1 = 'F24D43EA8E3A4350168D0EA7360D0333A38D7E79';

/// Google Maps Routes API: the trip time between two points with the traffic
/// expected at [departure].
class GoogleTrafficClient {
  GoogleTrafficClient({http.Client? client}) : _client = client;

  final http.Client? _client;

  Future<TrafficReading> tripMinutes({
    required String apiKey,
    required GeoPoint from,
    required GeoPoint to,
    required DateTime departure,
    required CommuteTravelMode mode,
  }) async {
    Map<String, dynamic> waypoint(GeoPoint p) => {
      'location': {
        'latLng': {'latitude': p.latitude, 'longitude': p.longitude},
      },
    };
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse(
              'https://routes.googleapis.com/directions/v2:computeRoutes',
            ),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'routes.duration,routes.staticDuration',
              'X-Android-Package': _androidPackage,
              'X-Android-Cert': _androidCertSha1,
            },
            body: jsonEncode({
              'origin': waypoint(from),
              'destination': waypoint(to),
              'travelMode': mode.apiName,
              'routingPreference': 'TRAFFIC_AWARE',
              'departureTime': departure.toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw FormatException(_errorMessage(response));
      }
      return parseRoutesResponse(response.body);
    } finally {
      if (_client == null) client.close();
    }
  }
}

/// Reads the first route's durations ("1234s") as whole minutes.
TrafficReading parseRoutesResponse(String body) {
  final json = jsonDecode(body) as Map<String, dynamic>;
  final routes = json['routes'] as List?;
  if (routes == null || routes.isEmpty) {
    throw const FormatException('Google found no route between home and work.');
  }
  final route = (routes.first as Map).cast<String, dynamic>();
  int minutes(Object? raw) {
    final text = raw as String? ?? '';
    final seconds = int.tryParse(text.replaceAll('s', '')) ?? 0;
    return (seconds / 60).round();
  }

  final withTraffic = minutes(route['duration']);
  if (withTraffic <= 0) {
    throw const FormatException('Google returned no trip time.');
  }
  return (
    withTraffic: withTraffic,
    withoutTraffic: minutes(route['staticDuration']),
  );
}

String _errorMessage(http.Response response) {
  try {
    final error = (jsonDecode(response.body) as Map)['error'] as Map;
    return 'Google Maps: ${error['message'] ?? response.statusCode}';
  } catch (_) {
    return 'Google Maps returned ${response.statusCode}.';
  }
}
