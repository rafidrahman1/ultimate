import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/app_log.dart';
import 'package:motohealth/core/storage/json_file_cache.dart';
import 'package:motohealth/features/garage/currencies.dart';
import 'package:motohealth/features/garage/moto_models.dart';

const _storeKey = 'moto_data_v1';

final motoStoreProvider = AsyncNotifierProvider<MotoStore, MotoData>(
  MotoStore.new,
);

/// The bike currently shown, or null while loading or with no bikes.
final selectedBikeProvider = Provider<Bike?>(
  (ref) => ref.watch(motoStoreProvider).valueOrNull?.selectedBike,
);

/// All data, kept on the device in one JSON file. Every change is saved at
/// once; there is no account and nothing leaves the phone.
class MotoStore extends AsyncNotifier<MotoData> {
  @override
  Future<MotoData> build() async {
    try {
      final json = await JsonFileCache.instance.read(_storeKey);
      return json == null ? const MotoData() : MotoData.fromJson(json);
    } catch (error) {
      // Not an empty start: that would let the next save overwrite the file.
      AppLog.warn('Could not read saved bike data: $error');
      rethrow;
    }
  }

  /// Throws before the data has loaded, so nothing can overwrite it.
  MotoData get _data => state.requireValue;

  Future<void> _set(MotoData next) async {
    state = AsyncData(next);
    await JsonFileCache.instance.write(_storeKey, next.toJson());
  }

  // Bikes

  Future<void> addBike(Bike bike) {
    return _set(
      _data.copyWith(bikes: [..._data.bikes, bike], selectedBikeId: bike.id),
    );
  }

  Future<void> updateBike(Bike bike) => _set(
    _data.copyWith(
      bikes: [for (final b in _data.bikes) b.id == bike.id ? bike : b],
    ),
  );

  Future<void> selectBike(String id) =>
      _set(_data.copyWith(selectedBikeId: id));

  /// Removes a bike and everything logged for it.
  Future<void> deleteBike(String id) {
    final d = _data;
    final bikes = [
      for (final b in d.bikes)
        if (b.id != id) b,
    ];
    return _set(
      MotoData(
        bikes: bikes,
        readings: [
          for (final r in d.readings)
            if (r.bikeId != id) r,
        ],
        fuel: [
          for (final r in d.fuel)
            if (r.bikeId != id) r,
        ],
        services: [
          for (final r in d.services)
            if (r.bikeId != id) r,
        ],
        expenses: [
          for (final r in d.expenses)
            if (r.bikeId != id) r,
        ],
        papers: [
          for (final r in d.papers)
            if (r.bikeId != id) r,
        ],
        selectedBikeId: d.selectedBikeId == id
            ? (bikes.isEmpty ? null : bikes.first.id)
            : d.selectedBikeId,
        currency: d.currency,
        currencyCode: d.currencyCode,
      ),
    );
  }

  /// Replaces everything with a restored backup.
  Future<void> restore(MotoData backup) => _set(backup);

  Future<void> setCurrency(Currency c) =>
      _set(_data.copyWith(currency: c.symbol, currencyCode: c.code));

  // Entries. Each `save…` adds a new item or replaces the one with its id.

  List<T> _upsert<T>(List<T> list, T item, String Function(T) idOf) {
    final id = idOf(item);
    final i = list.indexWhere((e) => idOf(e) == id);
    if (i < 0) return [...list, item];
    return [...list]..[i] = item;
  }

  Future<void> saveReading(OdometerReading r) =>
      _set(_data.copyWith(readings: _upsert(_data.readings, r, (e) => e.id)));
  Future<void> saveFuel(FuelEntry e) =>
      _set(_data.copyWith(fuel: _upsert(_data.fuel, e, (x) => x.id)));
  Future<void> saveService(ServiceEntry e) =>
      _set(_data.copyWith(services: _upsert(_data.services, e, (x) => x.id)));
  Future<void> saveExpense(Expense e) =>
      _set(_data.copyWith(expenses: _upsert(_data.expenses, e, (x) => x.id)));
  Future<void> savePaper(Paper p) =>
      _set(_data.copyWith(papers: _upsert(_data.papers, p, (x) => x.id)));

  Future<void> deleteReading(String id) => _set(
    _data.copyWith(
      readings: [
        for (final e in _data.readings)
          if (e.id != id) e,
      ],
    ),
  );
  Future<void> deleteFuel(String id) => _set(
    _data.copyWith(
      fuel: [
        for (final e in _data.fuel)
          if (e.id != id) e,
      ],
    ),
  );
  Future<void> deleteService(String id) => _set(
    _data.copyWith(
      services: [
        for (final e in _data.services)
          if (e.id != id) e,
      ],
    ),
  );
  Future<void> deleteExpense(String id) => _set(
    _data.copyWith(
      expenses: [
        for (final e in _data.expenses)
          if (e.id != id) e,
      ],
    ),
  );
  Future<void> deletePaper(String id) => _set(
    _data.copyWith(
      papers: [
        for (final e in _data.papers)
          if (e.id != id) e,
      ],
    ),
  );
}
