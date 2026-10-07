import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/core/prefs.dart';
import 'package:personal/features/expenses/outlook_ai.dart';

const _outlookAiKey = 'outlook_ai_estimate_v1';

/// The last AI-refined bills, month, budget, payday and service estimate,
/// kept across launches. Only a newer refinement replaces it.
final outlookAiEstimateProvider =
    NotifierProvider<OutlookAiEstimateNotifier, OutlookAiEstimate?>(
      OutlookAiEstimateNotifier.new,
    );

class OutlookAiEstimateNotifier extends Notifier<OutlookAiEstimate?> {
  static OutlookAiEstimate? _memoryFallback;

  bool _saved = false;

  @override
  OutlookAiEstimate? build() {
    unawaited(_hydrate());
    return _memoryFallback;
  }

  Future<void> _hydrate() async {
    final prefs = await safePrefs();
    if (prefs == null || _saved) return;
    final raw = prefs.getString(_outlookAiKey);
    if (raw == null || _saved) return;
    try {
      final loaded = OutlookAiEstimate.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _memoryFallback = loaded;
      state = loaded;
    } catch (error) {
      AppLog.warn('Ignoring unreadable cached outlook estimate: $error');
    }
  }

  /// Stores a refinement of some sections, keeping the ones refined earlier.
  Future<void> save(OutlookAiEstimate fresh) async {
    _saved = true;
    final merged = state?.mergedWith(fresh) ?? fresh;
    _memoryFallback = merged;
    state = merged;
    final prefs = await safePrefs();
    await prefs?.setString(_outlookAiKey, jsonEncode(merged.toJson()));
  }
}
