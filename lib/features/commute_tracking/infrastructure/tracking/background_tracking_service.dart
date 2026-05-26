import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/entities/trip.dart';
import '../../domain/ports/activity_recognition_port.dart';
import '../../domain/ports/location_tracking_port.dart';
import '../../domain/ports/tracking_readiness_port.dart';
import '../../domain/repositories/trip_repository.dart';
import '../../domain/value_objects/location_sample.dart';
import '../../domain/value_objects/location_tracking_config.dart';
import '../../domain/value_objects/physical_activity.dart';
import 'active_trip_session.dart';
import 'background_tracking_status.dart';

/// Orchestrates activity recognition and GPS streams for commute logging.
///
/// Activity updates drive when location tracking starts and stops; UI layers
/// should depend on [statusStream] rather than native APIs directly.
class BackgroundTrackingService {
  BackgroundTrackingService({
    required ActivityRecognitionPort activityRecognition,
    required LocationTrackingPort locationTracking,
    required TrackingReadinessPort trackingReadiness,
    required TripRepository tripRepository,
    LocationTrackingConfig locationConfig = const LocationTrackingConfig(),
    Duration stillGracePeriod = const Duration(minutes: 3),
    Uuid? uuid,
  })  : _activityRecognition = activityRecognition,
        _locationTracking = locationTracking,
        _trackingReadiness = trackingReadiness,
        _tripRepository = tripRepository,
        _locationConfig = locationConfig,
        _stillGracePeriod = stillGracePeriod,
        _uuid = uuid ?? const Uuid();

  final ActivityRecognitionPort _activityRecognition;
  final LocationTrackingPort _locationTracking;
  final TrackingReadinessPort _trackingReadiness;
  final TripRepository _tripRepository;
  final LocationTrackingConfig _locationConfig;
  final Duration _stillGracePeriod;
  final Uuid _uuid;

  static const _minTripDistanceMeters = 50.0;

  final _statusController = StreamController<BackgroundTrackingStatus>.broadcast();

  StreamSubscription<PhysicalActivity>? _activitySubscription;
  StreamSubscription<LocationSample>? _locationSubscription;
  Timer? _stillGraceTimer;

  ActiveTripSession? _activeSession;
  bool _isTrackingLocation = false;
  bool _isDisposed = false;

  Stream<BackgroundTrackingStatus> get statusStream => _statusController.stream;

  BackgroundTrackingStatus _status =
      const BackgroundTrackingStatus(phase: BackgroundTrackingPhase.idle);

  bool get isTripActive => _activeSession != null;

  BackgroundTrackingStatus get currentStatus => _status;

  Future<void> start() async {
    if (_isDisposed) return;

    final readiness = await _trackingReadiness.ensureReady();
    if (!readiness.isReady) {
      _emit(
        _status.copyWith(
          phase: BackgroundTrackingPhase.error,
          message: readiness.blockingReason ?? 'Tracking prerequisites not met.',
        ),
      );
      return;
    }

    await _activitySubscription?.cancel();
    _activitySubscription = _activityRecognition.activityUpdates().listen(
      _onPhysicalActivity,
      onError: _onStreamError,
    );

    _emit(
      const BackgroundTrackingStatus(phase: BackgroundTrackingPhase.monitoring),
    );
  }

  Future<void> stop() async {
    _cancelStillGraceTimer();
    await _stopLocationStream();
    await _activitySubscription?.cancel();
    _activitySubscription = null;
    _activeSession = null;
    _emit(const BackgroundTrackingStatus(phase: BackgroundTrackingPhase.idle));
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await stop();
    await _statusController.close();
  }

  void _onPhysicalActivity(PhysicalActivity activity) {
    if (_isDisposed) return;

    if (activity.isInVehicle && activity.isHighConfidence) {
      _cancelStillGraceTimer();
      unawaited(_startLocationStream());
      return;
    }

    if (activity.isStill) {
      _scheduleStillGraceCompletion();
      return;
    }

    _cancelStillGraceTimer();
  }

  void _scheduleStillGraceCompletion() {
    if (_stillGraceTimer?.isActive ?? false) return;
    _stillGraceTimer = Timer(_stillGracePeriod, () {
      unawaited(_completeTrip());
    });
  }

  void _cancelStillGraceTimer() {
    _stillGraceTimer?.cancel();
    _stillGraceTimer = null;
  }

  Future<void> _startLocationStream() async {
    if (_isTrackingLocation) return;

    if (!await _locationTracking.isLocationServiceEnabled()) {
      _emit(
        _status.copyWith(
          phase: BackgroundTrackingPhase.error,
          message: 'Location services are disabled.',
        ),
      );
      return;
    }

    _activeSession ??= ActiveTripSession(startTime: DateTime.now().toUtc());
    _isTrackingLocation = true;

    await _locationSubscription?.cancel();
    _locationSubscription =
        _locationTracking.positionUpdates(_locationConfig).listen(
      _onLocationSample,
      onError: _onStreamError,
      onDone: () => _isTrackingLocation = false,
    );

    _emit(
      BackgroundTrackingStatus(
        phase: BackgroundTrackingPhase.tripActive,
        activeDistanceKm: _activeSession!.totalDistanceKm,
      ),
    );
  }

  void _onLocationSample(LocationSample sample) {
    if (_isDisposed || _activeSession == null) return;
    _activeSession!.addSample(sample);
    _emit(
      BackgroundTrackingStatus(
        phase: BackgroundTrackingPhase.tripActive,
        activeDistanceKm: _activeSession!.totalDistanceKm,
      ),
    );
  }

  Future<void> _completeTrip() async {
    _cancelStillGraceTimer();
    await _stopLocationStream();

    final session = _activeSession;
    _activeSession = null;

    if (session == null || !session.hasRoute) {
      _emit(
        const BackgroundTrackingStatus(phase: BackgroundTrackingPhase.monitoring),
      );
      return;
    }

    if (session.distanceInMeters < _minTripDistanceMeters) {
      _emit(
        const BackgroundTrackingStatus(phase: BackgroundTrackingPhase.monitoring),
      );
      return;
    }

    _emit(const BackgroundTrackingStatus(phase: BackgroundTrackingPhase.saving));

    try {
      final endTime = DateTime.now().toUtc();
      final trip = Trip(
        id: _uuid.v4(),
        startTime: session.startTime,
        endTime: endTime,
        totalDistanceKm: session.totalDistanceKm,
        route: List.unmodifiable(session.points),
      );

      await _tripRepository.saveTrip(trip);

      _emit(
        BackgroundTrackingStatus(
          phase: BackgroundTrackingPhase.monitoring,
          lastSavedTripId: trip.id,
          message: 'Saved ${trip.totalDistanceKm.toStringAsFixed(1)} km commute.',
        ),
      );
    } catch (error) {
      _onStreamError(error);
    }
  }

  Future<void> _stopLocationStream() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _locationTracking.stopPositionUpdates();
    _isTrackingLocation = false;
  }

  void _onStreamError(Object error) {
    _emit(
      _status.copyWith(
        phase: BackgroundTrackingPhase.error,
        message: error.toString(),
      ),
    );
  }

  void _emit(BackgroundTrackingStatus next) {
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }
}
