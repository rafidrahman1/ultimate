import 'dart:convert';

import 'package:personal/features/forecasts/commute_alert/commute_estimate.dart';
import 'package:personal/features/forecasts/commute_alert/commute_profile.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';
import 'package:personal/features/results/ai/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// Furthest the AI may move the leave time from the app's own estimate.
const commuteAiMaxShift = 30;

/// True when a provider is selected, has a key, and API calls are enabled.
bool canRunCommuteAi(AiSettings settings) {
  if (!settings.enableApiCalls) return false;
  final key = switch (settings.provider) {
    AiProvider.openai => settings.openAiApiKey,
    AiProvider.gemini => settings.geminiApiKey,
    AiProvider.anthropic => settings.anthropicApiKey,
  };
  return key.trim().isNotEmpty;
}

const commuteAiSystemInstruction =
    'You decide when someone should walk out of their front door to reach '
    'work on time. You get their recent door-to-door trips from their '
    'location history, Google Maps live traffic for the ride, the weather '
    "and the app's own estimate. Weigh them yourself: how their trips on "
    'this weekday and in similar weather went, whether Google tends to be '
    'optimistic for them, and how bad today looks. Being on time matters '
    'more than a few extra minutes at home, but do not pad needlessly. '
    'Reply with one JSON object and nothing else.';

/// The prompt for [day], with the app's [baseline] as a cross-check.
String buildCommuteAiPrompt({
  required CommuteProfile profile,
  required DateTime day,
  required DateTime now,
  required LeaveEstimate baseline,
  required String travelMode,
  Map<DateTime, int> googleLog = const {},
}) {
  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} (${weekdayShort(d)})';
  final s = profile.statsFor(day);
  final t = baseline.traffic;
  final weather = profile.weatherOn(day);
  final calibration = profile.calibration;

  return [
    'Now: ${date(now)} ${clockLabel(now.hour * 60 + now.minute)}.',
    'Trip day: ${date(day)}. Must be at work by ${clockLabel(baseline.target)}.',
    'Travel: $travelMode. Walking out of the door to riding off takes '
        '${baseline.prepMinutes} min; Google times cover the ride only, the '
        'trips below are door to door.',
    if (t != null)
      'Google Maps for leaving around ${clockLabel(baseline.leaveAt)}: '
          '${t.withTraffic} min with traffic, ${t.withoutTraffic} min on '
          'clear roads.'
    else
      'Google Maps traffic: unavailable.',
    'Weather that day: ${weather?.note ?? 'unknown'}.',
    'Their trips on ${weekdayShort(day)}s: usually ${s.typical.round()} min, '
        '8 in 10 within ${s.safe.round()} min (${s.trips} trips).',
    if (calibration != null)
      'Their real trips have taken ${calibration.toStringAsFixed(2)}x '
          "Google's estimate on average (${profile.calibrationTrips} days).",
    "App's estimate: leave at ${clockLabel(baseline.leaveAt)} "
        '(${baseline.tripMinutes} min door to door'
        '${baseline.rainBuffer > 0 ? ', incl. ${baseline.rainBuffer} for rain' : ''}).',
    '',
    'Recent trips (date | left home | reached work | minutes | Google min):',
    for (final trip in profile.recentTrips)
      '${date(trip.day)} | ${clockLabel(trip.left)} | '
          '${clockLabel(trip.arrived)} | ${trip.arrived - trip.left} | '
          '${googleLog[trip.day] ?? '-'}',
    '',
    'Reply as {"leaveAt": "HH:MM", "reason": "<one short sentence for a '
        'phone notification>"}. leaveAt is when to walk out of the door.',
  ].join('\n');
}

/// The AI's leave time from [reply], or null when it is unusable or strays
/// more than [commuteAiMaxShift] minutes from [baseline]. It is also never
/// later than the target minus the bare Google ride and getting going.
LeaveEstimate? parseCommuteAiResponse(String reply, LeaveEstimate baseline) {
  final start = reply.indexOf('{');
  final end = reply.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  final Map<String, dynamic> json;
  try {
    json = (jsonDecode(reply.substring(start, end + 1)) as Map)
        .cast<String, dynamic>();
  } catch (_) {
    return null;
  }
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})$',
  ).firstMatch((json['leaveAt'] as String? ?? '').trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  final leaveAt = hour * 60 + minute;
  if ((leaveAt - baseline.leaveAt).abs() > commuteAiMaxShift) return null;
  final t = baseline.traffic;
  if (t != null &&
      leaveAt > baseline.target - t.withTraffic - baseline.prepMinutes) {
    return null;
  }
  final reason = (json['reason'] as String? ?? '').trim();
  return baseline.withAi(leaveAt: leaveAt, reason: reason);
}

/// Asks the configured provider for the leave time. Throws when the reply
/// can't be used, so the caller keeps [baseline].
Future<LeaveEstimate> refineLeaveWithAi({
  required AiSettings settings,
  required CommuteProfile profile,
  required DateTime day,
  required DateTime now,
  required LeaveEstimate baseline,
  required String travelMode,
  Map<DateTime, int> googleLog = const {},
  // Runs from a background alarm, so it must finish quickly.
  AiClient client = const AiClient(
    maxAttempts: 2,
    requestTimeout: Duration(seconds: 45),
    totalBudget: Duration(seconds: 90),
  ),
}) async {
  final reply = await client.generate(
    settings: settings,
    systemInstruction: commuteAiSystemInstruction,
    prompt: buildCommuteAiPrompt(
      profile: profile,
      day: day,
      now: now,
      baseline: baseline,
      travelMode: travelMode,
      googleLog: googleLog,
    ),
  );
  final refined = parseCommuteAiResponse(reply, baseline);
  if (refined == null) {
    throw const FormatException('The AI reply was not a usable leave time.');
  }
  return refined;
}
