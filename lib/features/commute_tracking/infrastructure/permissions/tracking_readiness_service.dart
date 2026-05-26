import 'package:permission_handler/permission_handler.dart';

import '../../domain/ports/activity_recognition_port.dart';
import '../../domain/ports/location_tracking_port.dart';
import '../../domain/ports/tracking_readiness_port.dart';
import '../../domain/value_objects/tracking_readiness.dart';

class TrackingReadinessService implements TrackingReadinessPort {
  TrackingReadinessService({
    required ActivityRecognitionPort activityRecognition,
    required LocationTrackingPort locationTracking,
  })  : _activityRecognition = activityRecognition,
        _locationTracking = locationTracking;

  final ActivityRecognitionPort _activityRecognition;
  final LocationTrackingPort _locationTracking;

  @override
  Future<TrackingReadiness> evaluate() async {
    final activityGranted = await _activityRecognition.hasPermission();
    final locationGranted = await _locationTracking.hasPermission();
    final locationEnabled = await _locationTracking.isLocationServiceEnabled();
    final backgroundGranted = await Permission.locationAlways.isGranted;

    return TrackingReadiness(
      activityPermissionGranted: activityGranted,
      locationPermissionGranted: locationGranted,
      locationServiceEnabled: locationEnabled,
      backgroundLocationGranted: backgroundGranted,
    );
  }

  @override
  Future<TrackingReadiness> ensureReady() async {
    await _activityRecognition.requestPermission();
    await _locationTracking.requestPermission();

    if (!await Permission.locationAlways.isGranted) {
      await Permission.locationAlways.request();
    }

    return evaluate();
  }
}
