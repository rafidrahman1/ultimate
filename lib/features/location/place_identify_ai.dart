import 'dart:convert';

import 'package:personal/features/location/place_stats.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// Most places named per request; the busiest unnamed ones come first.
const placeIdentifyLimit = 12;

const placeIdentifySystemInstruction =
    'You identify places from location-history data. Reply with JSON only, '
    'no prose and no code fences.';

bool canIdentifyPlaces(AiSettings settings) {
  if (!settings.enableApiCalls) return false;
  final key = switch (settings.provider) {
    AiProvider.openai => settings.openAiApiKey,
    AiProvider.gemini => settings.geminiApiKey,
    AiProvider.anthropic => settings.anthropicApiKey,
  };
  return key.trim().isNotEmpty;
}

/// Home/work are labelled already and named places belong to the user.
List<PlaceStat> placesToIdentify(
  Iterable<PlaceStat> places,
  Map<String, String> names,
) {
  return [
    for (final p in places)
      if (p.kind == PlaceKind.other &&
          !p.placeIds.any((id) => (names[id] ?? '').isNotEmpty))
        p,
  ].take(placeIdentifyLimit).toList();
}

String buildPlaceIdentifyPrompt({
  required List<PlaceStat> places,
  required Iterable<TimelinePlaceVisit> visits,
  String homeAddress = '',
  String workAddress = '',
}) {
  final byId = <String, List<TimelinePlaceVisit>>{};
  for (final v in visits) {
    final id = v.placeId;
    if (id != null) (byId[id] ??= []).add(v);
  }

  final b = StringBuffer()
    ..writeln(
      'Guess what each place is (e.g. "Petrol station", "Gym", '
      '"Grocery store", "Friend\'s home", "Restaurant") from its '
      'coordinates, any name/address Google recorded, and when and how long '
      'the person stays. Use a short, specific name; add the brand or area '
      'only if you are fairly sure. If you cannot tell, use a generic '
      'category rather than inventing a business name.',
    );
  if (homeAddress.trim().isNotEmpty) b.writeln('Home: ${homeAddress.trim()}');
  if (workAddress.trim().isNotEmpty) b.writeln('Work: ${workAddress.trim()}');
  b.writeln('\nPlaces:');

  for (var i = 0; i < places.length; i++) {
    final p = places[i];
    final mine = [for (final id in p.placeIds) ...?byId[id]];
    final names = {
      for (final v in mine)
        if (v.name.trim().isNotEmpty) v.name.trim(),
    }.take(3);
    final addresses = {
      for (final v in mine)
        if ((v.address ?? '').trim().isNotEmpty) v.address!.trim(),
    }.take(2);
    final types = {
      for (final v in mine)
        if ((v.semanticType ?? '').isNotEmpty) v.semanticType!,
    };
    final hours = <int, int>{};
    final days = <int, int>{};
    for (final v in mine) {
      final t = v.startTime.toLocal();
      hours[t.hour] = (hours[t.hour] ?? 0) + 1;
      days[t.weekday] = (days[t.weekday] ?? 0) + 1;
    }
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final topHours =
        (hours.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .map((e) => '${e.key}:00')
            .join(', ');
    final topDays =
        (days.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .map((e) => dayNames[e.key - 1])
            .join(', ');
    final pt = p.point;

    b.writeln('${i + 1}.');
    if (pt != null) {
      b.writeln(
        '   coordinates: ${pt.latitude.toStringAsFixed(5)}, '
        '${pt.longitude.toStringAsFixed(5)}',
      );
    }
    if (names.isNotEmpty) b.writeln('   recorded name: ${names.join(' / ')}');
    if (addresses.isNotEmpty) {
      b.writeln('   recorded address: ${addresses.join(' / ')}');
    }
    if (types.isNotEmpty) b.writeln('   Google type: ${types.join(', ')}');
    b.writeln(
      '   ${p.visits} visits, average stay ${p.averageStay.inMinutes} min, '
      'total ${p.totalDwell.inMinutes} min',
    );
    if (topHours.isNotEmpty) {
      b.writeln('   usual arrival hours: $topHours; usual days: $topDays');
    }
  }

  b.writeln(
    '\nReturn exactly: {"places":[{"n":1,"name":"...","confident":true}]} '
    'with one entry per place number. Names must be 40 characters or fewer.',
  );
  return b.toString();
}

/// Place number (1-based) → suggested name.
Map<int, String> parsePlaceIdentifyResponse(String reply, int count) {
  final start = reply.indexOf('{');
  final end = reply.lastIndexOf('}');
  if (start < 0 || end <= start) return const {};
  final Object? decoded;
  try {
    decoded = jsonDecode(reply.substring(start, end + 1));
  } on FormatException {
    return const {};
  }
  final list = decoded is Map ? decoded['places'] : null;
  if (list is! List) return const {};
  final out = <int, String>{};
  for (final item in list) {
    if (item is! Map) continue;
    final n = item['n'] is num
        ? (item['n'] as num).toInt()
        : int.tryParse('${item['n']}');
    var name = item['name'] is String ? (item['name'] as String).trim() : '';
    if (n == null || n < 1 || n > count || name.isEmpty) continue;
    if (name.length > 40) name = name.substring(0, 40).trim();
    out[n] = name;
  }
  return out;
}

/// Asks the configured provider to name [places]. Returns suggestions keyed by
/// the place; throws if the reply holds nothing usable.
Future<Map<PlaceStat, String>> identifyPlacesWithAi({
  required AiSettings settings,
  required List<PlaceStat> places,
  required Iterable<TimelinePlaceVisit> visits,
  String homeAddress = '',
  String workAddress = '',
  AiClient client = const AiClient(maxAttempts: 2),
}) async {
  final reply = await client.generate(
    settings: settings,
    systemInstruction: placeIdentifySystemInstruction,
    prompt: buildPlaceIdentifyPrompt(
      places: places,
      visits: visits,
      homeAddress: homeAddress,
      workAddress: workAddress,
    ),
  );
  final parsed = parsePlaceIdentifyResponse(reply, places.length);
  if (parsed.isEmpty) {
    throw const FormatException('The AI reply had no usable place names.');
  }
  return {for (final e in parsed.entries) places[e.key - 1]: e.value};
}
