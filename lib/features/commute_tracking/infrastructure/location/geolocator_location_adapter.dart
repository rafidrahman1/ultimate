import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../../domain/ports/location_tracking_port.dart';
import '../../domain/value_objects/location_sample.dart';
import '../../domain/value_objects/location_tracking_config.dart';

class GeolocatorLocationAdapter implements LocationTrackingPort {
  @override
  Stream<LocationSample> positionUpdates(LocationTrackingConfig config) {
    final filter = config.distanceFilterMeters.round();
    final accuracy =
        config.highAccuracy ? LocationAccuracy.high : LocationAccuracy.medium;

    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: accuracy,
        distanceFilter: filter,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Commute tracking',
          notificationText: 'Logging motorcycle commute route',
          enableWakeLock: true,
        ),
      );
    } else {
      settings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: filter,
      );
    }

    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => LocationSample(
        latitude: position.latitude,
        longitude: position.longitude,
        timestamp: position.timestamp,
        accuracyMeters: position.accuracy,
      ),
    );
  }

  @override
  Future<void> stopPositionUpdates() async {
    // Stream cancellation is owned by BackgroundTrackingService subscribers.
  }

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
