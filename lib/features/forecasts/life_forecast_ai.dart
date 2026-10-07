import 'dart:convert';

import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// One forecast as the model worked it out from the raw rows.
class LifeAiItem {
  const LifeAiItem({
    required this.headline,
    required this.detail,
    required this.reasoning,
    required this.refinedAt,
    required this.forSignature,
    this.value,
    this.date,
  });

  factory LifeAiItem.fromJson(Map<String, dynamic> j) => LifeAiItem(
    headline: j['headline'] as String,
    detail: j['detail'] as String? ?? '',
    reasoning: j['reasoning'] as String? ?? '',
    refinedAt: DateTime.parse(j['refinedAt'] as String),
    forSignature: j['forSignature'] as String? ?? '',
    value: (j['value'] as num?)?.toDouble(),
    date: j['date'] == null ? null : DateTime.parse(j['date'] as String),
  );

  Map<String, dynamic> toJson() => {
    'headline': headline,
    'detail': detail,
    'reasoning': reasoning,
    'refinedAt': refinedAt.toIso8601String(),
    'forSignature': forSignature,
    'value': value,
    'date': date?.toIso8601String(),
  };

  final String headline;
  final String detail;
  final String reasoning;
  final DateTime refinedAt;

  /// [LifeForecast.signature] this was made for.
  final String forSignature;
  final double? value;
  final DateTime? date;

  /// Usable only while the data it read is unchanged and it is recent.
  bool isFreshFor(LifeForecast forecast, DateTime now) =>
      forSignature == forecast.signature &&
      now.difference(refinedAt).inHours < 48;
}

/// The model's answers for every forecast it has been asked about, by
/// [LifeForecastKind.name]. A newer answer replaces only its own entry.
class LifeAiEstimate {
  const LifeAiEstimate([this.items = const {}]);

  factory LifeAiEstimate.fromJson(Map<String, dynamic> j) => LifeAiEstimate({
    for (final e in j.entries)
      if (e.value is Map<String, dynamic>)
        e.key: LifeAiItem.fromJson(e.value as Map<String, dynamic>),
  });

  Map<String, dynamic> toJson() => {
    for (final e in items.entries) e.key: e.value.toJson(),
  };

  final Map<String, LifeAiItem> items;

  LifeAiEstimate mergedWith(LifeAiEstimate fresh) =>
      LifeAiEstimate({...items, ...fresh.items});

  /// The answer for [forecast], or null when missing or out of date.
  LifeAiItem? freshFor(LifeForecast forecast, DateTime now) {
    final item = items[forecast.key];
    return item != null && item.isFreshFor(forecast, now) ? item : null;
  }
}

const lifeAiSystemInstruction =
    'You are a careful personal-data analyst. You are given raw daily rows '
    'from the user\'s own sleep, health, calendar, location, gaming, spending '
    'and checklist records. For each question, do the calculation yourself '
    'from the raw rows: total, average, fit trends and compare days as needed. '
    'The app\'s baseline is only a quick cross-check; depart from it whenever '
    'the rows support a better answer, and say so briefly. Never invent data '
    'that is not in the rows. If the rows are too thin to answer, give your '
    'best estimate and say it is uncertain. Reply with one JSON object and '
    'nothing else.';

String buildLifeAiPrompt(List<LifeForecast> forecasts, DateTime now) {
  final out = StringBuffer()
    ..writeln(
      'Today: ${dateLine.format(DateTime(now.year, now.month, now.day))}',
    )
    ..writeln();
  final schema = <String>[];
  for (final f in forecasts) {
    out
      ..writeln('## ${f.key}: ${f.label}')
      ..writeln('Question: ${f.question}')
      ..writeln('App baseline (cross-check only): ${f.headline} — ${f.detail}')
      ..writeln('Raw data:')
      ..writeln(f.rawData)
      ..writeln();
    schema.add(
      '"${f.key}":{"headline":"<short result, at most 24 characters>",'
      '"detail":"<one line, at most 80 characters>","value":<number or null>,'
      '"date":"YYYY-MM-DD or null","reasoning":"<two sentences at most, '
      'including the key numbers you calculated>"}',
    );
  }
  out.writeln('Return JSON with only these keys: {${schema.join(',')}}');
  return out.toString();
}

DateTime? _date(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(v);
  final parsed = m == null ? null : DateTime.tryParse(m.group(0)!);
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

String _clip(String text, int max) {
  final t = text.trim();
  return t.length <= max ? t : '${t.substring(0, max - 1).trimRight()}…';
}

/// Keeps every answer that is usable; null when none is.
LifeAiEstimate? parseLifeAiResponse(
  String raw,
  List<LifeForecast> forecasts,
  DateTime now,
) {
  final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
  if (match == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(match.group(0)!);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final today = DateTime(now.year, now.month, now.day);
  final items = <String, LifeAiItem>{};
  for (final f in forecasts) {
    // One topic asked: models sometimes answer with the bare object.
    final entry =
        decoded[f.key] ??
        (forecasts.length == 1 && decoded.containsKey('headline')
            ? decoded
            : null);
    if (entry is! Map) continue;
    final headline = entry['headline'];
    if (headline is! String || headline.trim().isEmpty) continue;
    final value = entry['value'];
    final date = _date(entry['date']);
    items[f.key] = LifeAiItem(
      headline: _clip(headline, 28),
      detail: _clip('${entry['detail'] ?? ''}', 100),
      reasoning: _clip('${entry['reasoning'] ?? ''}', 400),
      refinedAt: now,
      forSignature: f.signature,
      value: value is num ? value.toDouble() : null,
      date:
          date != null && date.isAfter(today.subtract(const Duration(days: 30)))
          ? date
          : null,
    );
  }
  return items.isEmpty ? null : LifeAiEstimate(items);
}

/// Forecasts per request: each carries its own raw rows, so a long list is
/// split to keep every prompt a sensible size.
const lifeAiBatchSize = 5;

/// Sends the raw rows for [forecasts], a few forecasts per request. Throws
/// when nothing usable comes back, so the caller can keep the baseline; a
/// batch that fails does not discard the others.
Future<LifeAiEstimate> estimateLifeWithAi({
  required AiSettings settings,
  required List<LifeForecast> forecasts,
  DateTime? now,
  AiClient client = const AiClient(maxAttempts: 2),
}) async {
  final clock = now ?? DateTime.now();
  Future<LifeAiEstimate> batch(List<LifeForecast> group) async {
    final reply = await client.generate(
      settings: settings,
      systemInstruction: lifeAiSystemInstruction,
      prompt: buildLifeAiPrompt(group, clock),
    );
    final estimate = parseLifeAiResponse(reply, group, clock);
    if (estimate == null) {
      final seen = reply.replaceAll(RegExp(r'\s+'), ' ').trim();
      throw FormatException(
        'The AI reply was not a usable estimate. It said: "${_clip(seen, 160)}"',
      );
    }
    return estimate;
  }

  final groups = [
    for (var k = 0; k < forecasts.length; k += lifeAiBatchSize)
      forecasts.sublist(
        k,
        k + lifeAiBatchSize > forecasts.length
            ? forecasts.length
            : k + lifeAiBatchSize,
      ),
  ];
  final results = await Future.wait(
    groups.map(
      (g) => batch(g).then<(LifeAiEstimate?, Object?)>(
        (e) => (e, null),
        onError: (Object e) => (null, e),
      ),
    ),
  );
  var merged = const LifeAiEstimate();
  Object? firstError;
  for (final (estimate, error) in results) {
    if (estimate != null) merged = merged.mergedWith(estimate);
    firstError ??= error;
  }
  if (merged.items.isEmpty) {
    throw firstError ?? const FormatException('The AI gave no usable answer.');
  }
  return merged;
}
