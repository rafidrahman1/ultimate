import '../data/datasources/trip_local_datasource.dart';
import '../data/repositories/trip_repository_impl.dart';
import '../domain/repositories/trip_repository.dart';
import '../infrastructure/activity/flutter_activity_recognition_adapter.dart';
import '../infrastructure/location/geolocator_location_adapter.dart';
import '../infrastructure/permissions/tracking_readiness_service.dart';
import '../infrastructure/tracking/background_tracking_service.dart';
import '../domain/ports/activity_recognition_port.dart';
import '../domain/ports/location_tracking_port.dart';
import '../domain/ports/tracking_readiness_port.dart';

/// Composition root for commute tracking dependencies.
class CommuteTrackingBootstrap {
  CommuteTrackingBootstrap._({
    required this.tripRepository,
    required this.backgroundTrackingService,
    required this.tripLocalDataSource,
  });

  final TripRepository tripRepository;
  final BackgroundTrackingService backgroundTrackingService;
  final TripLocalDataSource tripLocalDataSource;

  static CommuteTrackingBootstrap? _instance;

  static CommuteTrackingBootstrap get instance {
    final bootstrap = _instance;
    if (bootstrap == null) {
      throw StateError(
        'CommuteTrackingBootstrap.initialize() must be called before use.',
      );
    }
    return bootstrap;
  }

  static Future<CommuteTrackingBootstrap> initialize() async {
    if (_instance != null) return _instance!;

    final tripLocalDataSource = await TripLocalDataSource.open();
    final tripRepository = TripRepositoryImpl(tripLocalDataSource);

    final ActivityRecognitionPort activityRecognition =
        FlutterActivityRecognitionAdapter();
    final LocationTrackingPort locationTracking = GeolocatorLocationAdapter();
    final TrackingReadinessPort trackingReadiness = TrackingReadinessService(
      activityRecognition: activityRecognition,
      locationTracking: locationTracking,
    );

    final backgroundTrackingService = BackgroundTrackingService(
      activityRecognition: activityRecognition,
      locationTracking: locationTracking,
      trackingReadiness: trackingReadiness,
      tripRepository: tripRepository,
    );

    _instance = CommuteTrackingBootstrap._(
      tripRepository: tripRepository,
      backgroundTrackingService: backgroundTrackingService,
      tripLocalDataSource: tripLocalDataSource,
    );

    return _instance!;
  }
}
