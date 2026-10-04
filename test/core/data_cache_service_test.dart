import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/core/data_cache_service.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/timeline_profile.dart';

const _expensesKey = 'data_cache_expenses_v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('data_cache_test');
    DataCacheService.directoryOverride = () async => dir;
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  final summary = ExpensesSummary(
    transactions: [
      CashewTransaction(
        account: 'Cash',
        amount: -250,
        currency: 'BDT',
        date: DateTime(2026, 9, 3),
        isIncome: false,
        category: 'Food',
      ),
    ],
  );

  test('saves to a file and loads it back', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = DataCacheService.instance;

    await cache.saveExpenses(summary);
    final loaded = await cache.loadExpenses();

    expect(loaded?.transactions.single.amount, -250);
    expect(File('${dir.path}/$_expensesKey.json').existsSync(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_expensesKey), isFalse);
  });

  test('corrupt legacy prefs entry loads as empty and is cleared', () async {
    SharedPreferences.setMockInitialValues({_expensesKey: '{not valid json'});

    expect(await DataCacheService.instance.loadExpenses(), isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(_expensesKey), isFalse);
  });

  test('corrupt cache file loads as empty and is deleted', () async {
    SharedPreferences.setMockInitialValues({});
    final file = File('${dir.path}/$_expensesKey.json')
      ..writeAsStringSync('[1, 2');

    expect(await DataCacheService.instance.loadExpenses(), isNull);
    expect(file.existsSync(), isFalse);
  });

  group('location cache', () {
    final location = LocationSummary(
      activities: [
        TimelineActivity(
          startTime: DateTime.utc(2026, 9, 1, 4),
          endTime: DateTime.utc(2026, 9, 1, 4, 20),
          type: 'MOTORCYCLING',
          distanceMeters: 8200,
        ),
      ],
      placeVisits: [
        TimelinePlaceVisit(
          startTime: DateTime.utc(2026, 9, 1, 5),
          endTime: DateTime.utc(2026, 9, 1, 9),
          name: 'Unknown place',
          placeId: 'abc',
          point: const GeoPoint(23.8679331, 90.4053536),
          level: 1,
          probability: 0.9,
        ),
      ],
      profile: const LocationProfile(
        places: [
          ProfilePlace(
            placeId: 'home',
            point: GeoPoint(23.86, 90.4),
            label: 'HOME',
          ),
        ],
        trips: [
          FrequentTrip(
            direction: CommuteDirection.workToHome,
            weekday: DateTime.sunday,
            startMinutes: 1081,
            durationMinutes: 27,
            confidence: 0.97,
            modeShares: {'MOTORCYCLING': 0.72},
          ),
        ],
        modeAffinities: {'WALKING': 0.15},
      ),
      trips: [
        TimelineTrip(
          startTime: DateTime.utc(2026, 8, 10),
          endTime: DateTime.utc(2026, 8, 15),
          distanceFromOriginKm: 239,
          destinationPlaceIds: const ['far'],
        ),
      ],
      fileName: 'Timeline.json',
    );

    test('round-trips place ids, profile and trips', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = DataCacheService.instance;
      await cache.saveLocation(location);
      final loaded = (await cache.loadLocation())!;

      final visit = loaded.placeVisits.single;
      expect(visit.placeId, 'abc');
      expect(visit.level, 1);
      expect(visit.probability, 0.9);
      expect(visit.point!.latitude, closeTo(23.8679331, 1e-9));

      expect(loaded.profile.home, isNotNull);
      final trip = loaded.profile.trips.single;
      expect(trip.direction, CommuteDirection.workToHome);
      expect(trip.weekday, DateTime.sunday);
      expect(trip.startMinutes, 1081);
      expect(trip.modeShares['MOTORCYCLING'], 0.72);
      expect(loaded.profile.modeAffinities['WALKING'], 0.15);

      expect(loaded.trips.single.distanceFromOriginKm, 239);
      expect(loaded.trips.single.destinationPlaceIds, ['far']);
      expect(loaded.isLegacyCache, isFalse);
    });

    test('flags a cache written before place detail existed', () async {
      SharedPreferences.setMockInitialValues({});
      File('${dir.path}/data_cache_location_v1.json').writeAsStringSync(
        '{"fileName":"Timeline.json","activities":[{"startTime":"2026-09-01T04:00:00.000Z","endTime":"2026-09-01T04:20:00.000Z","type":"MOTORCYCLING","distanceMeters":8200}],"placeVisits":[]}',
      );
      final loaded = (await DataCacheService.instance.loadLocation())!;
      expect(loaded.activities, hasLength(1));
      expect(loaded.isLegacyCache, isTrue);
      expect(loaded.profile.isEmpty, isTrue);
    });
  });
}
