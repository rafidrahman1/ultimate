# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MotoHealth is a private, offline Flutter app (Android-primary) for tracking a motorcycle: odometer,
fuel and mileage, maintenance schedule, costs, and expiring papers. It was split from the
"Personal" app (still on `main`). There is no backend, no account and no network use.

## Commands

```bash
flutter pub get
flutter run
flutter analyze      # flutter_lints plus the extra rules in analysis_options.yaml
dart format .
flutter test
```

Run `flutter analyze` and `flutter test` before calling work done; CI runs both plus a format check.

## Architecture

```
lib/
  app/          # MaterialApp
  core/         # app_log, formatting, storage (prefs, JsonFileCache), theme. Must not import features/shell/app
  shared/       # Reusable widgets (cards, form sheets, ring gauge). Must not import features/shell
  shell/        # MainShell: bottom nav Home / Fuel / Service / Costs / Papers, FAB per tab
  features/
    garage/     # Models, store, pure logic, bike form, garage + schedule screens
    dashboard/  # Home tab and the quick odometer form
    fuel/ service/ costs/ papers/   # one tab each: screen + form
    reminders/  # Local notifications, rebuilt from the data after every change
```

`test/architecture_test.dart` enforces the layering above.

### Data

- All data is one `MotoData` document (`garage/moto_models.dart`) held by `motoStoreProvider`
  (`garage/moto_store.dart`, an `AsyncNotifier`). Every change is written at once via
  `JsonFileCache` (atomic file write) under key `moto_data_v1`. Add new fields as optional in
  `fromJson` so older saves still load.
- Entries (fuel, service, expense, paper, odometer reading) reference a bike by `bikeId`.
  Deleting a bike deletes its entries. Maintenance jobs (`ServiceTask`) live on the `Bike`.
- Service entries reset a job's countdown through `ServiceEntry.taskIds`.

### Logic

`garage/moto_logic.dart` is pure and unit-tested (`test/moto_logic_test.dart`): odometer points and
estimate, `fuelStats` (full-tank method), `taskStatuses` (due levels), paper levels, `healthScore`,
`costByCategory`. Keep screens thin and put calculations here.

### Tests

Widget tests that touch the store must read `motoStoreProvider.future` inside `tester.runAsync`
*before* `pumpWidget`, and call `SharedPreferences.setMockInitialValues({})` plus set
`JsonFileCache.directoryOverride`; otherwise real file I/O deadlocks under fake async.
