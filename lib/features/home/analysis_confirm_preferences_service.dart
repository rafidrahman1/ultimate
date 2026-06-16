import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/features/home/analysis_data_preview.dart';

const _analysisConfirmPreferencesKey = 'analysis_confirm_preferences_v1';

int promptTextFingerprint(String text) => text.hashCode;

class AnalysisConfirmSourceOverride {
  const AnalysisConfirmSourceOverride({
    required this.baseFingerprint,
    required this.text,
  });

  final int baseFingerprint;
  final String text;

  Map<String, dynamic> toJson() => {
        'baseFingerprint': baseFingerprint,
        'text': text,
      };

  factory AnalysisConfirmSourceOverride.fromJson(Map<String, dynamic> json) {
    return AnalysisConfirmSourceOverride(
      baseFingerprint: json['baseFingerprint'] as int? ?? 0,
      text: json['text'] as String? ?? '',
    );
  }
}

class AnalysisConfirmPreferencesStored {
  const AnalysisConfirmPreferencesStored({
    required this.periodStart,
    this.overrides = const {},
    this.included = const {},
  });

  final DateTime periodStart;
  final Map<AnalysisDataSourceId, AnalysisConfirmSourceOverride> overrides;
  final Set<AnalysisDataSourceId> included;

  Map<String, dynamic> toJson() => {
        'periodStart': periodStart.toIso8601String(),
        'overrides': {
          for (final entry in overrides.entries)
            entry.key.name: entry.value.toJson(),
        },
        'included': included.map((id) => id.name).toList(),
      };

  factory AnalysisConfirmPreferencesStored.fromJson(Map<String, dynamic> json) {
    final overridesRaw = json['overrides'];
    final overrides = <AnalysisDataSourceId, AnalysisConfirmSourceOverride>{};
    if (overridesRaw is Map) {
      for (final entry in overridesRaw.entries) {
        final id = _parseSourceId(entry.key);
        final value = entry.value;
        if (id == null || value is! Map) continue;
        overrides[id] = AnalysisConfirmSourceOverride.fromJson(
          value.cast<String, dynamic>(),
        );
      }
    }

    final includedRaw = json['included'];
    final included = <AnalysisDataSourceId>{};
    if (includedRaw is List) {
      for (final item in includedRaw) {
        final id = _parseSourceId(item);
        if (id != null) included.add(id);
      }
    }

    final periodRaw = json['periodStart'] as String?;
    return AnalysisConfirmPreferencesStored(
      periodStart: periodRaw == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.parse(periodRaw),
      overrides: overrides,
      included: included,
    );
  }
}

class ResolvedAnalysisConfirmPreferences {
  const ResolvedAnalysisConfirmPreferences({
    this.promptOverrides = const {},
    this.included,
  });

  final Map<AnalysisDataSourceId, String> promptOverrides;
  final Set<AnalysisDataSourceId>? included;
}

ResolvedAnalysisConfirmPreferences resolveAnalysisConfirmPreferences({
  required AnalysisRunPreview preview,
  required AnalysisConfirmPreferencesStored? stored,
}) {
  if (stored == null ||
      !_sameAnalysisMonth(stored.periodStart, preview.period.dataMonthStart)) {
    return const ResolvedAnalysisConfirmPreferences();
  }

  final overrides = <AnalysisDataSourceId, String>{};
  for (final source in preview.sources) {
    final entry = stored.overrides[source.id];
    if (entry == null) continue;
    if (entry.baseFingerprint != promptTextFingerprint(source.promptText)) {
      continue;
    }
    overrides[source.id] = entry.text;
  }

  final included = stored.included.isEmpty ? null : Set.of(stored.included);
  return ResolvedAnalysisConfirmPreferences(
    promptOverrides: overrides,
    included: included,
  );
}

final analysisConfirmPreferencesProvider =
    NotifierProvider<AnalysisConfirmPreferencesNotifier,
        AnalysisConfirmPreferencesStored?>(
  AnalysisConfirmPreferencesNotifier.new,
);

class AnalysisConfirmPreferencesNotifier
    extends Notifier<AnalysisConfirmPreferencesStored?> {
  static AnalysisConfirmPreferencesStored? _memoryFallback;

  @override
  AnalysisConfirmPreferencesStored? build() {
    unawaited(_hydrateFromPrefs());
    return _memoryFallback;
  }

  Future<void> _hydrateFromPrefs() async {
    final prefs = await _safePrefs();
    if (prefs == null) return;

    final raw = prefs.getString(_analysisConfirmPreferencesKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final loaded = AnalysisConfirmPreferencesStored.fromJson(decoded);
      _memoryFallback = loaded;
      state = loaded;
    } catch (error) {
      AppLog.warn('Failed to load analysis confirm preferences: $error');
    }
  }

  Future<ResolvedAnalysisConfirmPreferences> resolveForPreview(
    AnalysisRunPreview preview,
  ) async {
    await _hydrateFromPrefs();
    return resolveAnalysisConfirmPreferences(
      preview: preview,
      stored: state,
    );
  }

  Future<void> savePromptOverride({
    required AnalysisRunPreview preview,
    required AnalysisDataSourceId sourceId,
    required String basePromptText,
    required String overrideText,
  }) async {
    final periodStart = preview.period.dataMonthStart;
    final current = _storedForPeriod(periodStart);
    final nextOverrides = Map<AnalysisDataSourceId, AnalysisConfirmSourceOverride>.from(
      current.overrides,
    )..[sourceId] = AnalysisConfirmSourceOverride(
        baseFingerprint: promptTextFingerprint(basePromptText),
        text: overrideText,
      );

    await _persist(
      current.copyWith(overrides: _pruneOverrides(nextOverrides, preview)),
    );
  }

  Future<void> clearPromptOverride({
    required DateTime periodStart,
    required AnalysisDataSourceId sourceId,
  }) async {
    final current = _storedForPeriod(periodStart);
    if (!current.overrides.containsKey(sourceId)) return;

    final nextOverrides = Map<AnalysisDataSourceId, AnalysisConfirmSourceOverride>.from(
      current.overrides,
    )..remove(sourceId);

    await _persist(current.copyWith(overrides: nextOverrides));
  }

  Future<void> saveIncluded({
    required DateTime periodStart,
    required Set<AnalysisDataSourceId> included,
  }) async {
    final current = _storedForPeriod(periodStart);
    await _persist(current.copyWith(included: Set.from(included)));
  }

  AnalysisConfirmPreferencesStored _storedForPeriod(DateTime periodStart) {
    final stored = state;
    if (stored != null && _sameAnalysisMonth(stored.periodStart, periodStart)) {
      return stored;
    }
    return AnalysisConfirmPreferencesStored(periodStart: periodStart);
  }

  Map<AnalysisDataSourceId, AnalysisConfirmSourceOverride> _pruneOverrides(
    Map<AnalysisDataSourceId, AnalysisConfirmSourceOverride> overrides,
    AnalysisRunPreview preview,
  ) {
    final pruned = <AnalysisDataSourceId, AnalysisConfirmSourceOverride>{};
    final promptById = {
      for (final source in preview.sources) source.id: source.promptText,
    };

    for (final entry in overrides.entries) {
      final promptText = promptById[entry.key];
      if (promptText == null) continue;
      if (entry.value.baseFingerprint != promptTextFingerprint(promptText)) {
        continue;
      }
      pruned[entry.key] = entry.value;
    }
    return pruned;
  }

  Future<void> _persist(AnalysisConfirmPreferencesStored next) async {
    final hasOverrides = next.overrides.isNotEmpty;
    final hasIncluded = next.included.isNotEmpty;
    if (!hasOverrides && !hasIncluded) {
      _memoryFallback = null;
      state = null;
      final prefs = await _safePrefs();
      await prefs?.remove(_analysisConfirmPreferencesKey);
      return;
    }

    _memoryFallback = next;
    state = next;

    final prefs = await _safePrefs();
    await prefs?.setString(
      _analysisConfirmPreferencesKey,
      jsonEncode(next.toJson()),
    );
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on PlatformException catch (error) {
      AppLog.warn('SharedPreferences channel error: $error');
      return null;
    } catch (error) {
      AppLog.warn('SharedPreferences init failed: $error');
      return null;
    }
  }
}

extension on AnalysisConfirmPreferencesStored {
  AnalysisConfirmPreferencesStored copyWith({
    DateTime? periodStart,
    Map<AnalysisDataSourceId, AnalysisConfirmSourceOverride>? overrides,
    Set<AnalysisDataSourceId>? included,
  }) {
    return AnalysisConfirmPreferencesStored(
      periodStart: periodStart ?? this.periodStart,
      overrides: overrides ?? this.overrides,
      included: included ?? this.included,
    );
  }
}

bool _sameAnalysisMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

AnalysisDataSourceId? _parseSourceId(Object? raw) {
  if (raw is! String) return null;
  for (final id in AnalysisDataSourceId.values) {
    if (id.name == raw) return id;
  }
  return null;
}
