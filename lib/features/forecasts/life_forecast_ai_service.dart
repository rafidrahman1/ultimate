import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/core/prefs.dart';
import 'package:personal/features/forecasts/life_forecast_ai.dart';

const _lifeAiKey = 'life_ai_estimate_v1';

/// The last AI answers for the life forecasts, kept across launches. Only a
/// newer answer for the same forecast replaces one.
final lifeAiEstimateProvider =
    NotifierProvider<LifeAiEstimateNotifier, LifeAiEstimate?>(
      LifeAiEstimateNotifier.new,
    );

class LifeAiEstimateNotifier extends Notifier<LifeAiEstimate?> {
  static LifeAiEstimate? _memoryFallback;

  bool _saved = false;

  @override
  LifeAiEstimate? build() {
    unawaited(_hydrate());
    return _memoryFallback;
  }

  Future<void> _hydrate() async {
    final prefs = await safePrefs();
    if (prefs == null || _saved) return;
    final raw = prefs.getString(_lifeAiKey);
    if (raw == null || _saved) return;
    try {
      final loaded = LifeAiEstimate.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _memoryFallback = loaded;
      state = loaded;
    } catch (error) {
      AppLog.warn('Ignoring unreadable cached life estimate: $error');
    }
  }

  Future<void> save(LifeAiEstimate fresh) async {
    _saved = true;
    final merged = state?.mergedWith(fresh) ?? fresh;
    _memoryFallback = merged;
    state = merged;
    final prefs = await safePrefs();
    await prefs?.setString(_lifeAiKey, jsonEncode(merged.toJson()));
  }
}
