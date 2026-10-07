import 'dart:convert';

import 'package:intl/intl.dart';

import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/ai_ledger_text.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/fuel_forecast.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// The model's reading of the forecast, once it has weighed upcoming events
/// and recent riding.
class FuelAiEstimate {
  const FuelAiEstimate({
    required this.expectedDate,
    required this.earliestDate,
    required this.latestDate,
    required this.amount,
    required this.reasoning,
    required this.forSignature,
    required this.createdAt,
  });

  factory FuelAiEstimate.fromJson(Map<String, dynamic> json) => FuelAiEstimate(
    expectedDate: DateTime.parse(json['expectedDate'] as String),
    earliestDate: DateTime.parse(json['earliestDate'] as String),
    latestDate: DateTime.parse(json['latestDate'] as String),
    amount: (json['amount'] as num).toDouble(),
    reasoning: json['reasoning'] as String? ?? '',
    forSignature: json['forSignature'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'expectedDate': expectedDate.toIso8601String(),
    'earliestDate': earliestDate.toIso8601String(),
    'latestDate': latestDate.toIso8601String(),
    'amount': amount,
    'reasoning': reasoning,
    'forSignature': forSignature,
    'createdAt': createdAt.toIso8601String(),
  };

  final DateTime expectedDate;
  final DateTime earliestDate;
  final DateTime latestDate;
  final double amount;
  final String reasoning;

  /// [FuelForecast.signature] this was made for.
  final String forSignature;
  final DateTime createdAt;

  /// True once the data it was made from has changed, e.g. a newer refuel.
  bool isStaleFor(FuelForecast forecast) => forSignature != forecast.signature;
}

/// True when a provider is selected, has a key, and API calls are enabled.
bool canRunFuelAi(AiSettings settings) {
  if (!settings.enableApiCalls) return false;
  final key = switch (settings.provider) {
    AiProvider.openai => settings.openAiApiKey,
    AiProvider.gemini => settings.geminiApiKey,
    AiProvider.anthropic => settings.anthropicApiKey,
  };
  return key.trim().isNotEmpty;
}

const fuelAiSystemInstruction =
    'You forecast when a motorcycle rider will next buy fuel. You are given '
    'the raw refuel entries, daily riding distance and upcoming calendar '
    'events. Do the calculation yourself from those rows: work out the gaps '
    'between refuels, the usual refill amount and litres, the price per '
    'litre, how far a tank lasts, how much has been ridden since the last '
    'refuel and how fast, then when the tank runs low. The app\'s baseline '
    'is only a cross-check; depart from it whenever the rows support a '
    'better answer, and adjust for upcoming holidays or trips that change '
    'how much they ride. Reply with one JSON object and nothing else.';

String buildFuelAiPrompt({
  required FuelForecast forecast,
  required Iterable<CashewTransaction> transactions,
  required Iterable<TimelineActivity> activities,
  required Iterable<CalendarEvent> events,
  required DateTime now,
}) {
  final date = DateFormat('yyyy-MM-dd (EEE)');
  final today = DateTime(now.year, now.month, now.day);
  final out = StringBuffer()
    ..writeln('Today: ${date.format(today)}')
    ..writeln('Currency: ${forecast.currency}')
    ..writeln();

  out
    ..writeln('All fuel entries (notes may give litres or price per litre):')
    ..writeln(
      entryRows(
        transactions,
        (t) => t.isRealExpense && ExpensesSummary.isFuelExpense(t),
        limit: 80,
      ),
    )
    ..writeln();

  out
    ..writeln()
    ..writeln('App baseline (quick estimate, cross-check only):')
    ..writeln(
      '- Typical gap between refuels: '
      '${forecast.typicalIntervalDays.round()} days',
    )
    ..writeln('- Expected amount: ${forecast.typicalAmount.round()}')
    ..writeln(
      '- Date from refuel gaps alone: '
      '${date.format(forecast.dateBasedExpectedDate)}',
    );
  final litres = forecast.typicalLitres;
  final rate = forecast.lastRatePerLitre;
  if (litres != null && rate != null) {
    out.writeln(
      '- Usual refill ${litres.toStringAsFixed(1)} L; latest price '
      '${rate.toStringAsFixed(0)}/L'
      '${forecast.lastRateDate == null ? '' : ' (${date.format(forecast.lastRateDate!)})'}'
      ', so the expected amount is litres x latest price',
    );
  }
  final distance = forecast.distance;
  if (distance != null) {
    out
      ..writeln(
        '- Km ridden since last refuel: '
        '${distance.kmSinceLastRefuel.round()} '
        '(location data through ${date.format(distance.locationThrough)})',
      )
      ..writeln(
        '- A typical refill has lasted ${distance.tankRangeKm.round()} km '
        '(${distance.kmPerLitre != null ? '${distance.kmPerLitre!.toStringAsFixed(1)} km/L' : '${distance.kmPerCurrency.toStringAsFixed(3)} km per currency unit'}, '
        '${distance.gapsUsed} gaps)',
      )
      ..writeln(
        '- Recent riding: ${distance.dailyKm.toStringAsFixed(1)} km/day',
      )
      ..writeln(
        '- Date from distance and weekday riding pattern: '
        '${date.format(forecast.expectedDate)}',
      );
  } else {
    out.writeln('- No usable riding distance data; date is from gaps only.');
  }

  out
    ..writeln()
    ..writeln('Motorcycle km per day, last 120 days:')
    ..writeln(dailyKmRows(activities, now));

  final horizon = today.add(const Duration(days: 21));
  final upcoming = events.where((e) {
    final start = DateTime(e.start.year, e.start.month, e.start.day);
    return !start.isBefore(today) && !start.isAfter(horizon);
  }).toList()..sort((a, b) => a.start.compareTo(b.start));
  out
    ..writeln()
    ..writeln('Calendar events, next 21 days:');
  if (upcoming.isEmpty) {
    out.writeln('- none');
  } else {
    for (final e in upcoming.take(25)) {
      final tags = [
        if (e.isHoliday) 'holiday',
        if (e.allDay) 'all day',
        if (e.location != null && e.location!.trim().isNotEmpty)
          'at ${e.location!.trim()}',
      ];
      out.writeln(
        '- ${date.format(e.start)}: ${e.title}'
        '${tags.isEmpty ? '' : ' (${tags.join(', ')})'}',
      );
    }
  }

  out
    ..writeln()
    ..writeln(
      'Return JSON: {"expected_date":"YYYY-MM-DD","earliest_date":"YYYY-MM-DD",'
      '"latest_date":"YYYY-MM-DD","amount":<number>,'
      '"reasoning":"<two sentences at most>"}',
    );
  return out.toString();
}

/// Reads the model's JSON reply. Returns null when it can't be trusted: no
/// JSON, bad dates, or a date far outside what the data could support.
FuelAiEstimate? parseFuelAiResponse(
  String raw, {
  required FuelForecast forecast,
  required DateTime now,
}) {
  final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
  if (match == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(match.group(0)!);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;

  DateTime? parseDate(Object? value) {
    if (value is! String) return null;
    // The prompt shows "2026-10-22 (Thu)"; models often echo the weekday.
    final text = value.trim();
    final parsed = DateTime.tryParse(
      RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(text)?.group(0) ?? text,
    );
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  final today = DateTime(now.year, now.month, now.day);
  final expected = parseDate(decoded['expected_date']);
  if (expected == null ||
      expected.isBefore(today.subtract(const Duration(days: 14))) ||
      expected.isAfter(today.add(const Duration(days: 90)))) {
    return null;
  }
  var earliest = parseDate(decoded['earliest_date']) ?? expected;
  var latest = parseDate(decoded['latest_date']) ?? expected;
  if (earliest.isAfter(expected)) earliest = expected;
  if (latest.isBefore(expected)) latest = expected;

  final amount = decoded['amount'];
  final reasoning = decoded['reasoning'];
  return FuelAiEstimate(
    expectedDate: expected,
    earliestDate: earliest,
    latestDate: latest,
    amount: _fuelAmount(amount) ?? forecast.typicalAmount,
    reasoning: reasoning is String ? reasoning.trim() : '',
    forSignature: forecast.signature,
    createdAt: now,
  );
}

/// Asks the configured provider to refine [forecast]. Throws when the reply
/// can't be used, so the caller can show the baseline unchanged.
Future<FuelAiEstimate> estimateFuelWithAi({
  required AiSettings settings,
  required FuelForecast forecast,
  required Iterable<CashewTransaction> transactions,
  required Iterable<TimelineActivity> activities,
  required Iterable<CalendarEvent> events,
  DateTime? now,
  AiClient client = const AiClient(maxAttempts: 2),
}) async {
  final clock = now ?? DateTime.now();
  final reply = await client.generate(
    settings: settings,
    systemInstruction: fuelAiSystemInstruction,
    prompt: buildFuelAiPrompt(
      forecast: forecast,
      transactions: transactions,
      activities: activities,
      events: events,
      now: clock,
    ),
  );
  final estimate = parseFuelAiResponse(reply, forecast: forecast, now: clock);
  if (estimate == null) {
    throw const FormatException('The AI reply was not a usable fuel estimate.');
  }
  return estimate;
}

/// A positive amount from a number or text like "1,200".
double? _fuelAmount(Object? v) {
  final value = v is num
      ? v.toDouble()
      : v is String
      ? double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), ''))
      : null;
  return value != null && value > 0 ? value : null;
}
