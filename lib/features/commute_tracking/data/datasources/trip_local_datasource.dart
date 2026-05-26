import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/trip_model.dart';

/// SQLite persistence for completed commute trips.
class TripLocalDataSource {
  TripLocalDataSource(this._database);

  final Database _database;

  static const _table = 'commute_trips';

  static Future<TripLocalDataSource> open({String? databasePath}) async {
    final path = databasePath ??
        p.join(await getDatabasesPath(), 'commute_trips.db');
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            start_time TEXT NOT NULL,
            end_time TEXT NOT NULL,
            total_distance_km REAL NOT NULL,
            route_json TEXT NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX idx_commute_trips_start ON $_table(start_time DESC)',
        );
      },
    );
    return TripLocalDataSource(db);
  }

  Future<void> insertTrip(TripModel trip) async {
    await _database.insert(
      _table,
      trip.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<TripModel>> getAllTrips() async {
    final rows = await _database.query(
      _table,
      orderBy: 'start_time DESC',
    );
    return rows.map((row) => TripModel.fromMap(row)).toList();
  }

  Future<TripModel?> getTripById(String id) async {
    final rows = await _database.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TripModel.fromMap(rows.first);
  }

  Future<void> deleteTrip(String id) async {
    await _database.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() => _database.close();
}
