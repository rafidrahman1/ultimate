/// Domain configuration for GPS sampling (interpreted by infrastructure).
class LocationTrackingConfig {
  const LocationTrackingConfig({
    this.distanceFilterMeters = 10,
    this.highAccuracy = true,
  });

  final double distanceFilterMeters;
  final bool highAccuracy;
}
