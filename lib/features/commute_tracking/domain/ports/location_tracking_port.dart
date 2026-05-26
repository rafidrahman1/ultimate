import '../value_objects/location_sample.dart';
import '../value_objects/location_tracking_config.dart';

/// Platform-agnostic high-accuracy GPS stream.
abstract class LocationTrackingPort {
  Stream<LocationSample> positionUpdates(LocationTrackingConfig config);

  Future<void> stopPositionUpdates();

  Future<bool> isLocationServiceEnabled();

  Future<bool> hasPermission();

  Future<bool> requestPermission();
}
