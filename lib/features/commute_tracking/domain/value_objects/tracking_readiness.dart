class TrackingReadiness {
  const TrackingReadiness({
    required this.activityPermissionGranted,
    required this.locationPermissionGranted,
    required this.locationServiceEnabled,
    this.backgroundLocationGranted = false,
  });

  final bool activityPermissionGranted;
  final bool locationPermissionGranted;
  final bool locationServiceEnabled;
  final bool backgroundLocationGranted;

  bool get isReady =>
      activityPermissionGranted &&
      locationPermissionGranted &&
      locationServiceEnabled;

  String? get blockingReason {
    if (!activityPermissionGranted) {
      return 'Activity recognition permission is required.';
    }
    if (!locationPermissionGranted) {
      return 'Location permission is required.';
    }
    if (!locationServiceEnabled) {
      return 'Enable device location services.';
    }
    return null;
  }
}
