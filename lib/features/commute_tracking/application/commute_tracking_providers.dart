import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/trip.dart';
import '../domain/repositories/trip_repository.dart';
import '../infrastructure/tracking/background_tracking_service.dart';
import '../infrastructure/tracking/background_tracking_status.dart';
import 'commute_tracking_bootstrap.dart';

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return CommuteTrackingBootstrap.instance.tripRepository;
});

final backgroundTrackingServiceProvider =
    Provider<BackgroundTrackingService>((ref) {
  final service = CommuteTrackingBootstrap.instance.backgroundTrackingService;
  ref.onDispose(service.dispose);
  return service;
});

final backgroundTrackingStatusProvider =
    StreamProvider<BackgroundTrackingStatus>((ref) {
  final service = ref.watch(backgroundTrackingServiceProvider);
  return service.statusStream;
});

final tripsProvider = FutureProvider<List<Trip>>((ref) async {
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getTrips();
});

final totalCommuteDistanceKmProvider = FutureProvider<double>((ref) async {
  final trips = await ref.watch(tripsProvider.future);
  return trips.fold<double>(0, (sum, trip) => sum + trip.totalDistanceKm);
});
