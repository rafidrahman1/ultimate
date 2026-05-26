import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/commute_tracking/domain/entities/trip.dart';
import 'package:personal/features/commute_tracking/domain/ports/activity_recognition_port.dart';
import 'package:personal/features/commute_tracking/domain/ports/location_tracking_port.dart';
import 'package:personal/features/commute_tracking/domain/ports/tracking_readiness_port.dart';
import 'package:personal/features/commute_tracking/domain/repositories/trip_repository.dart';
import 'package:personal/features/commute_tracking/domain/value_objects/location_sample.dart';
import 'package:personal/features/commute_tracking/domain/value_objects/location_tracking_config.dart';
import 'package:personal/features/commute_tracking/domain/value_objects/physical_activity.dart';
import 'package:personal/features/commute_tracking/domain/value_objects/tracking_readiness.dart';
import 'package:personal/features/commute_tracking/infrastructure/tracking/background_tracking_service.dart';
import 'package:personal/features/commute_tracking/infrastructure/tracking/background_tracking_status.dart';

void main() {
  test('starts GPS on IN_VEHICLE high confidence and saves after STILL grace', () async {
    final activityController = StreamController<PhysicalActivity>.broadcast();
    final locationController = StreamController<LocationSample>.broadcast();
    final repository = _InMemoryTripRepository();

    final service = BackgroundTrackingService(
      activityRecognition: _FakeActivityRecognition(activityController.stream),
      locationTracking: _FakeLocationTracking(locationController.stream),
      trackingReadiness: _FakeReadiness(),
      tripRepository: repository,
      stillGracePeriod: const Duration(milliseconds: 100),
    );

    await service.start();

    activityController.add(
      const PhysicalActivity(
        type: PhysicalActivityType.inVehicle,
        confidence: ActivityConfidenceLevel.high,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    locationController.add(
      LocationSample(
        latitude: 23.79,
        longitude: 90.40,
        timestamp: DateTime.utc(2026, 5, 1, 8),
        accuracyMeters: 5,
      ),
    );
    locationController.add(
      LocationSample(
        latitude: 23.80,
        longitude: 90.41,
        timestamp: DateTime.utc(2026, 5, 1, 8, 5),
        accuracyMeters: 5,
      ),
    );

    activityController.add(
      const PhysicalActivity(
        type: PhysicalActivityType.still,
        confidence: ActivityConfidenceLevel.high,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(repository.savedTrips, hasLength(1));
    expect(repository.savedTrips.first.id, isNotEmpty);
    expect(repository.savedTrips.first.totalDistanceKm, greaterThan(0));

    await service.dispose();
    await activityController.close();
    await locationController.close();
  });
}

class _InMemoryTripRepository implements TripRepository {
  final savedTrips = <Trip>[];

  @override
  Future<void> deleteTrip(String id) async {
    savedTrips.removeWhere((t) => t.id == id);
  }

  @override
  Future<Trip?> getTripById(String id) async {
    for (final trip in savedTrips) {
      if (trip.id == id) return trip;
    }
    return null;
  }

  @override
  Future<List<Trip>> getTrips() async => List.unmodifiable(savedTrips);

  @override
  Future<void> saveTrip(Trip trip) async {
    savedTrips.add(trip);
  }
}

class _FakeActivityRecognition implements ActivityRecognitionPort {
  _FakeActivityRecognition(this._stream);

  final Stream<PhysicalActivity> _stream;

  @override
  Stream<PhysicalActivity> activityUpdates() => _stream;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async => true;
}

class _FakeLocationTracking implements LocationTrackingPort {
  _FakeLocationTracking(this._stream);

  final Stream<LocationSample> _stream;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Stream<LocationSample> positionUpdates(LocationTrackingConfig config) =>
      _stream;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> stopPositionUpdates() async {}
}

class _FakeReadiness implements TrackingReadinessPort {
  @override
  Future<TrackingReadiness> ensureReady() async {
    return const TrackingReadiness(
      activityPermissionGranted: true,
      locationPermissionGranted: true,
      locationServiceEnabled: true,
      backgroundLocationGranted: true,
    );
  }

  @override
  Future<TrackingReadiness> evaluate() async => ensureReady();
}
