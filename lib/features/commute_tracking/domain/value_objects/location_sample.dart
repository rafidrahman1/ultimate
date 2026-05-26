class LocationSample {
  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracyMeters;
}
