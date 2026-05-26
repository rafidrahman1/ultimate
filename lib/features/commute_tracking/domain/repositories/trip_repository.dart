import '../entities/trip.dart';

/// Persistence contract for logged commute trips.
abstract class TripRepository {
  Future<void> saveTrip(Trip trip);

  Future<List<Trip>> getTrips();

  Future<Trip?> getTripById(String id);

  Future<void> deleteTrip(String id);
}
