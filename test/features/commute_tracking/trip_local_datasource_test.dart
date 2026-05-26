import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/commute_tracking/data/datasources/trip_local_datasource.dart';
import 'package:personal/features/commute_tracking/data/models/trip_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('persists and reads commute trips', () async {
    final dataSource = await TripLocalDataSource.open(
      databasePath: inMemoryDatabasePath,
    );

    final trip = TripModel(
      id: 't1',
      startTime: DateTime.utc(2026, 5, 1, 8),
      endTime: DateTime.utc(2026, 5, 1, 9),
      totalDistanceKm: 12.5,
      route: [
        RoutePointModel(
          latitude: 1,
          longitude: 2,
          timestamp: DateTime.utc(2026, 5, 1, 8),
        ),
        RoutePointModel(
          latitude: 1.01,
          longitude: 2.01,
          timestamp: DateTime.utc(2026, 5, 1, 8, 30),
        ),
      ],
    );

    await dataSource.insertTrip(trip);
    final loaded = await dataSource.getAllTrips();

    expect(loaded, hasLength(1));
    expect(loaded.first.totalDistanceKm, 12.5);
    expect(loaded.first.route, hasLength(2));

    await dataSource.close();
  });
}
