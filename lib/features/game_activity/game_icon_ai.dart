import 'dart:convert';

import 'package:personal/features/game_activity/game_icons.dart';
import 'package:personal/features/results/ai/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// Most games sent per request.
const gameIconLimit = 40;

const gameIconSystemInstruction =
    'You categorise video games. Reply with JSON only, no prose and no code '
    'fences.';

bool canPickGameIcons(AiSettings settings) {
  if (!settings.enableApiCalls) return false;
  final key = switch (settings.provider) {
    AiProvider.openai => settings.openAiApiKey,
    AiProvider.gemini => settings.geminiApiKey,
    AiProvider.anthropic => settings.anthropicApiKey,
  };
  return key.trim().isNotEmpty;
}

String buildGameIconPrompt(List<String> games) {
  final b = StringBuffer()
    ..writeln(
      'For each game, pick the one icon key that best fits its genre or '
      'subject. Allowed keys: ${gameIconCatalog.keys.join(', ')}. Use '
      '"other" only if nothing fits or you do not recognise the game.',
    )
    ..writeln('\nGames:');
  for (var i = 0; i < games.length; i++) {
    b.writeln('${i + 1}. ${games[i]}');
  }
  b.writeln(
    '\nReturn exactly: {"games":[{"n":1,"icon":"shooter"}]} with one entry '
    'per game number.',
  );
  return b.toString();
}

/// Game number (1-based) → catalog key. Unknown keys are dropped.
Map<int, String> parseGameIconResponse(String reply, int count) {
  final start = reply.indexOf('{');
  final end = reply.lastIndexOf('}');
  if (start < 0 || end <= start) return const {};
  final Object? decoded;
  try {
    decoded = jsonDecode(reply.substring(start, end + 1));
  } on FormatException {
    return const {};
  }
  final list = decoded is Map ? decoded['games'] : null;
  if (list is! List) return const {};
  final out = <int, String>{};
  for (final item in list) {
    if (item is! Map) continue;
    final n = item['n'] is num
        ? (item['n'] as num).toInt()
        : int.tryParse('${item['n']}');
    final icon = item['icon'] is String
        ? (item['icon'] as String).trim().toLowerCase()
        : '';
    if (n == null || n < 1 || n > count) continue;
    if (!gameIconCatalog.containsKey(icon)) continue;
    out[n] = icon;
  }
  return out;
}

/// Asks the configured provider to choose an icon for each of [games].
/// Returns name → catalog key; throws if the reply holds nothing usable.
Future<Map<String, String>> pickGameIconsWithAi({
  required AiSettings settings,
  required List<String> games,
  AiClient client = const AiClient(maxAttempts: 2),
}) async {
  final reply = await client.generate(
    settings: settings,
    systemInstruction: gameIconSystemInstruction,
    prompt: buildGameIconPrompt(games),
  );
  final parsed = parseGameIconResponse(reply, games.length);
  if (parsed.isEmpty) {
    throw const FormatException('The AI reply had no usable icons.');
  }
  return {for (final e in parsed.entries) games[e.key - 1]: e.value};
}
