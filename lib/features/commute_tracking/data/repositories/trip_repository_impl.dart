import '../../domain/entities/trip.dart';
import '../../domain/repositories/trip_repository.dart';
import '../datasources/trip_local_datasource.dart';
import '../models/trip_model.dart';

class TripRepositoryImpl implements TripRepository {
  TripRepositoryImpl(this._localDataSource);

  final TripLocalDataSource _localDataSource;

  @override
  Future<void> saveTrip(Trip trip) async {
    await _localDataSource.insertTrip(TripModel.fromDomain(trip));
  }

  @override
  Future<List<Trip>> getTrips() async {
    final models = await _localDataSource.getAllTrips();
    return models.map((m) => m.toDomain()).toList();
  }

  @override
  Future<Trip?> getTripById(String id) async {
    final model = await _localDataSource.getTripById(id);
    return model?.toDomain();
  }

  @override
  Future<void> deleteTrip(String id) async {
    await _localDataSource.deleteTrip(id);
  }
}
