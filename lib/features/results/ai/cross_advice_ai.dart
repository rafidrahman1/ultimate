import 'dart:convert';

import 'package:personal/features/results/ai/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// One suggestion, with when to be reminded about it (null = no reminder).
class AdviceItem {
  const AdviceItem({
    required this.text,
    this.minutes,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
  });

  factory AdviceItem.fromJson(Map<String, dynamic> j) => AdviceItem(
    text: j['text'] as String,
    minutes: (j['minutes'] as num?)?.toInt(),
    weekdays: {
      for (final d in (j['weekdays'] as List? ?? const []))
        if (d is num && d >= 1 && d <= 7) d.toInt(),
    },
  );

  Map<String, dynamic> toJson() => {
    'text': text,
    'minutes': minutes,
    'weekdays': weekdays.toList()..sort(),
  };

  final String text;

  /// Minutes after local midnight.
  final int? minutes;

  /// DateTime.monday (1) … DateTime.sunday (7).
  final Set<int> weekdays;

  String get timeLabel => minutes == null
      ? ''
      : '${(minutes! ~/ 60).toString().padLeft(2, '0')}:'
            '${(minutes! % 60).toString().padLeft(2, '0')}';
}

const crossAdviceSystemInstruction =
    'You are a blunt, practical personal coach. You get one month of the '
    'user\'s own figures (sleep, spending, riding and work arrival, gaming, '
    'screen time, calendar), statistical links between them, a day-by-day '
    'table, late arrivals with the sleep before them, and the largest '
    'expenses. Use the day table to check the links yourself and to find '
    'real habits (for example, every late day following a night under 6h, '
    'or spending piling up on certain weekdays); name the specific days or '
    'weekdays when it makes the point sharper.\n'
    'Decide yourself what is worth acting on, then give the 2 or 3 changes '
    'that would help most.\n'
    'Rules:\n'
    '- Base each point on a clear problem in the figures: a bad number, a '
    'worsening trend, or a missed target. Skip anything that is fine.\n'
    '- Use a link between sources only if it rests on 10+ days, is not '
    'contradicted by another figure, and points at something the user can '
    'change. Ignore weak, thin or odd-looking links. Never build advice on '
    'a link you doubt.\n'
    '- Ignore any source with too little data to judge.\n'
    '- Every point must differ in topic; no overlap, no generic tips '
    '("drink water", "sleep more") without a number from the data.\n'
    '- "text": at most 22 words: the problem with its key number, then one '
    'specific action with a measurable target. Do not quote exact link '
    'figures or odd thresholds (like "6h40"); round to simple targets.\n'
    '- Reminder: for each point choose the moment a nudge would actually '
    'help, from the user\'s own pattern: "time" as local 24h HH:MM (e.g. '
    'a wind-down 45 minutes before their usual bedtime; leave-home time on '
    'work days; a spending check on the weekday spending spikes) and "days" '
    'as the weekdays it applies to (mon..sun), or all seven. Use null for '
    'time when a reminder would not help.\n'
    '- If nothing needs fixing, return one item saying so, with time null.\n'
    '- Reply with JSON only, no other text: '
    '{"items":[{"text":"...","time":"HH:MM or null",'
    '"days":["mon","tue"]}]}';

String buildCrossAdvicePrompt(String facts) =>
    'Here is my data:\n\n$facts\n\nWhat should I change, and when should I '
    'be reminded?';

const _dayNames = {
  'mon': 1,
  'tue': 2,
  'wed': 3,
  'thu': 4,
  'fri': 5,
  'sat': 6,
  'sun': 7,
};

int? _minutesOf(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r'^\s*(\d{1,2}):(\d{2})').firstMatch(v);
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  return h > 23 || min > 59 ? null : h * 60 + min;
}

/// Parses the model's JSON; falls back to plain "- " lines (no reminders).
List<AdviceItem> parseCrossAdvice(String raw) {
  final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
  if (match != null) {
    try {
      final decoded = jsonDecode(match.group(0)!);
      final list = decoded is Map ? decoded['items'] : null;
      if (list is List) {
        final items = <AdviceItem>[];
        for (final e in list.whereType<Map>()) {
          final text = '${e['text'] ?? ''}'.trim();
          if (text.isEmpty) continue;
          final days = <int>{
            for (final d in (e['days'] as List? ?? const []))
              ?_dayNames[d
                  .toString()
                  .toLowerCase()
                  .padRight(3)
                  .substring(0, 3)],
          };
          items.add(
            AdviceItem(
              text: text,
              minutes: _minutesOf(e['time']),
              weekdays: days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : days,
            ),
          );
        }
        if (items.isNotEmpty) return items.take(3).toList();
      }
    } on FormatException {
      // fall through to the bullet parser
    }
  }
  final bullet = RegExp(r'^\s*([-*•]|\d+[.)])\s+');
  return [
    for (final l in raw.split('\n'))
      if (bullet.hasMatch(l) && l.replaceFirst(bullet, '').trim().isNotEmpty)
        AdviceItem(text: l.replaceFirst(bullet, '').trim()),
  ].take(3).toList();
}

/// Asks the model for the few changes that matter most, given [facts] (see
/// `buildAdviceFacts`).
Future<List<AdviceItem>> adviseFromData({
  required AiSettings settings,
  required String facts,
  AiClient client = const AiClient(maxAttempts: 2),
  AiCancelToken? cancelToken,
}) async {
  final reply = await client.generate(
    settings: settings,
    systemInstruction: crossAdviceSystemInstruction,
    prompt: buildCrossAdvicePrompt(facts),
    cancelToken: cancelToken,
  );
  final advice = parseCrossAdvice(reply);
  if (advice.isEmpty) {
    throw const FormatException('The AI gave no suggestions.');
  }
  return advice;
}
