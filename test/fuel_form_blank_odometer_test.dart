import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motohealth/core/storage/json_file_cache.dart';
import 'package:motohealth/features/fuel/fuel_form.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('motohealth_test');
    JsonFileCache.directoryOverride = () async => dir;
  });

  tearDown(() async {
    JsonFileCache.directoryOverride = null;
    await dir.delete(recursive: true);
  });

  // Own file: the cache singleton's pending write from another widget test
  // would stall this test's store load.
  testWidgets('saves a fill-up without an odometer', (tester) async {
    final bike = Bike(
      id: 'b',
      name: 'Daily',
      addedOn: DateTime(2026, 1, 1),
      startOdometer: 500,
      tasks: const [],
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await container.read(motoStoreProvider.future);
      await container.read(motoStoreProvider.notifier).addBike(bike);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showFuelForm(context, bike: bike),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '');
    await tester.enterText(fields.at(1), '120');
    await tester.enterText(fields.at(2), '600');
    await tester.tap(find.text('Save'));
    await tester.pump();
    // Let the file write finish before the temp directory is removed.
    await tester.runAsync(() => JsonFileCache.instance.read('moto_data_v1'));
    await tester.pumpAndSettle();
    final fuel = container.read(motoStoreProvider).requireValue.fuel;
    expect(fuel, hasLength(1));
    expect(fuel.single.odometer, isNull);
  });
}
