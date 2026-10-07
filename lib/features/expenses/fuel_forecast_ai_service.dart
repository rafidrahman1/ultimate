import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/core/prefs.dart';
import 'package:personal/features/expenses/fuel_forecast_ai.dart';

const _fuelAiKey = 'fuel_ai_estimate_v1';

/// The last AI-refined fuel estimate, kept across launches. It is replaced
/// only by a newer refinement, never dropped when new data arrives.
final fuelAiEstimateProvider =
    NotifierProvider<FuelAiEstimateNotifier, FuelAiEstimate?>(
      FuelAiEstimateNotifier.new,
    );

class FuelAiEstimateNotifier extends Notifier<FuelAiEstimate?> {
  static FuelAiEstimate? _memoryFallback;

  // Keeps the async prefs hydration from overwriting an estimate saved while
  // it was in-flight.
  bool _saved = false;

  @override
  FuelAiEstimate? build() {
    unawaited(_hydrate());
    return _memoryFallback;
  }

  Future<void> _hydrate() async {
    final prefs = await safePrefs();
    if (prefs == null || _saved) return;
    final raw = prefs.getString(_fuelAiKey);
    if (raw == null || _saved) return;
    try {
      final loaded = FuelAiEstimate.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _memoryFallback = loaded;
      state = loaded;
    } catch (error) {
      AppLog.warn('Ignoring unreadable cached fuel estimate: $error');
    }
  }

  Future<void> save(FuelAiEstimate estimate) async {
    _saved = true;
    _memoryFallback = estimate;
    state = estimate;
    final prefs = await safePrefs();
    await prefs?.setString(_fuelAiKey, jsonEncode(estimate.toJson()));
  }
}
