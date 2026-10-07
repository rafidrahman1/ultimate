import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/prefs.dart';
import 'package:personal/features/forecasts/life_forecast.dart';

const _disabledKey = 'prediction_disabled_v1';

/// One prediction the user can switch on or off.
class PredictionOption {
  const PredictionOption(this.key, this.label, this.group, this.blurb);

  final String key;
  final String label;
  final PredictionGroup group;
  final String blurb;
}

/// Every prediction, in the order the chooser lists them.
final List<PredictionOption> allPredictionOptions = [
  const PredictionOption(
    'fuel',
    'Next fuel',
    PredictionGroup.money,
    'When you will next refuel and what it costs',
  ),
  const PredictionOption(
    'bills',
    'Upcoming bills',
    PredictionGroup.money,
    'Recurring bills due in the next 30 days',
  ),
  const PredictionOption(
    'budget',
    'Budget',
    PredictionGroup.money,
    'When your monthly budget runs out',
  ),
  const PredictionOption(
    'payday',
    'Payday',
    PredictionGroup.money,
    'When your next income lands',
  ),
  const PredictionOption(
    'month',
    'Month-end spend',
    PredictionGroup.money,
    'Where this month\'s spending is heading',
  ),
  const PredictionOption(
    'bike',
    'Bike service',
    PredictionGroup.life,
    'When your bike is due for service',
  ),
  const PredictionOption(
    'oil',
    'Oil change',
    PredictionGroup.life,
    'When the engine oil is due',
  ),
  for (final k in LifeForecastKind.values)
    PredictionOption(k.name, k.label, k.group, k.blurb),
];

/// Predictions the user switched off, by key. Everything is on by default, so
/// a prediction added later shows up until it is turned off.
final predictionDisabledProvider =
    NotifierProvider<PredictionDisabledNotifier, Set<String>>(
      PredictionDisabledNotifier.new,
    );

class PredictionDisabledNotifier extends Notifier<Set<String>> {
  static Set<String> _memoryFallback = const {};

  bool _changed = false;

  @override
  Set<String> build() {
    unawaited(_hydrate());
    return _memoryFallback;
  }

  Future<void> _hydrate() async {
    final prefs = await safePrefs();
    if (prefs == null || _changed) return;
    final stored = prefs.getStringList(_disabledKey);
    if (stored == null || _changed) return;
    _memoryFallback = stored.toSet();
    state = _memoryFallback;
  }

  Future<void> _save(Set<String> next) async {
    _changed = true;
    _memoryFallback = next;
    state = next;
    final prefs = await safePrefs();
    await prefs?.setStringList(_disabledKey, next.toList());
  }

  Future<void> setEnabled(String key, bool enabled) =>
      _save(enabled ? ({...state}..remove(key)) : {...state, key});

  Future<void> setGroupEnabled(PredictionGroup group, bool enabled) {
    final keys = {
      for (final o in allPredictionOptions)
        if (o.group == group) o.key,
    };
    return _save(enabled ? state.difference(keys) : state.union(keys));
  }

  Future<void> setAllEnabled(bool enabled) => _save(
    enabled ? <String>{} : {for (final o in allPredictionOptions) o.key},
  );
}
