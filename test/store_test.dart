import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohealth/core/storage/json_file_cache.dart';
import 'package:motohealth/features/garage/currencies.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Bike bike(String id) => Bike(
  id: id,
  name: id,
  addedOn: DateTime(2026, 1, 1),
  startOdometer: 0,
  tasks: const [],
);

FuelEntry fuel(String id, String bikeId, double litres) => FuelEntry(
  id: id,
  bikeId: bikeId,
  date: DateTime(2026, 2, 1),
  litres: litres,
  cost: 100,
);

void main() {
  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('motohealth_store');
    JsonFileCache.directoryOverride = () async => dir;
    JsonFileCache.instance.resetForTests();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    JsonFileCache.directoryOverride = null;
    await dir.delete(recursive: true);
  });

  MotoStore store() => container.read(motoStoreProvider.notifier);
  MotoData data() => container.read(motoStoreProvider).requireValue;

  test('adds a new entry and replaces one with the same id', () async {
    await container.read(motoStoreProvider.future);
    await store().addBike(bike('b'));
    await store().saveFuel(fuel('f', 'b', 5));
    await store().saveFuel(fuel('g', 'b', 6));
    await store().saveFuel(fuel('f', 'b', 7));
    expect(data().fuel.map((f) => f.litres), [7, 6]);
  });

  test('deleting a bike deletes its entries and keeps the currency', () async {
    await container.read(motoStoreProvider.future);
    await store().addBike(bike('a'));
    await store().addBike(bike('b'));
    await store().saveFuel(fuel('fa', 'a', 5));
    await store().saveFuel(fuel('fb', 'b', 5));
    await store().setCurrency(const Currency('BDT', 'Bangladeshi taka', '৳'));
    await store().deleteBike('a');
    expect(data().bikes.map((b) => b.id), ['b']);
    expect(data().fuel.map((f) => f.id), ['fb']);
    expect(data().currencyCode, 'BDT');
  });

  test('data survives a restart', () async {
    await container.read(motoStoreProvider.future);
    await store().addBike(bike('b'));
    await store().saveFuel(fuel('f', 'b', 5));
    container.dispose();
    container = ProviderContainer();
    await container.read(motoStoreProvider.future);
    expect(data().fuel.single.litres, 5);
  });

  test('a corrupt data file falls back to the last good copy', () async {
    await container.read(motoStoreProvider.future);
    await store().addBike(bike('b'));
    await store().saveFuel(fuel('f', 'b', 5));
    await store().saveFuel(fuel('g', 'b', 6));
    container.dispose();

    final file = File('${dir.path}/moto_data_v1.json');
    await file.writeAsString('{ broken');
    container = ProviderContainer();
    await container.read(motoStoreProvider.future);

    // The copy taken before the last write has the first fill-up only.
    expect(data().fuel.map((f) => f.id), ['f']);
    expect(File('${file.path}.corrupt').existsSync(), isTrue);
    expect(file.existsSync(), isTrue);
  });
}
