import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/forecasts/commute_alert/commute_alert_service.dart';
import 'package:personal/features/forecasts/life/life_forecast_provider.dart';
import 'package:personal/features/location/data/location_service.dart';

/// Rebuilds the leave-for-work profile from the timeline now, instead of
/// waiting for the Predictions tab to do it, once the imported timeline has
/// loaded from cache. Leaves a saved profile alone while there are no place
/// visits at all, so a timeline that is still loading never wipes it.
Future<void> refreshCommuteProfileNow(WidgetRef ref) async {
  await ref.read(importedLocationProvider.notifier).restoreFromCache();
  final inputs = ref.read(lifeInputsProvider);
  if (inputs.placeVisits.isEmpty) return;
  await CommuteAlertService.refreshProfile(inputs);
}
