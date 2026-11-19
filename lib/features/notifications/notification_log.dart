import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';

const _logKey = 'notification_log_v1';
const _seenKey = 'notification_log_seen_v1';

/// How long a delivered notification stays in the list.
const _historyDays = 30;

/// Most delivered notifications kept, newest first.
const _historyLimit = 150;

/// How often a repeating notification fires again.
enum NotificationRepeat { weekly }

/// One notification the app has shown or scheduled.
class LoggedNotification {
  const LoggedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.channel,
    this.repeat,
  });

  factory LoggedNotification.fromJson(Map<String, dynamic> json) =>
      LoggedNotification(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
        channel: json['channel'] as String?,
        repeat: NotificationRepeat.values
            .where((r) => r.name == json['repeat'])
            .firstOrNull,
      );

  /// The platform notification id; reused by later schedules.
  final int id;
  final String title;
  final String body;

  /// When it fires (first firing for a repeating one).
  final DateTime at;

  /// Android channel id, used to label the kind of notification.
  final String? channel;
  final NotificationRepeat? repeat;

  /// Next firing at or after [now]; [at] for a one-off.
  DateTime nextAt(DateTime now) {
    if (repeat == null || !at.isBefore(now)) return at;
    const period = Duration(days: 7);
    final periods = now.difference(at).inMicroseconds ~/ period.inMicroseconds;
    var next = at.add(period * periods);
    if (next.isBefore(now)) next = next.add(period);
    return next;
  }

  /// Still to come: a repeating one always is.
  bool isUpcoming(DateTime now) => repeat != null || at.isAfter(now);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'at': at.millisecondsSinceEpoch,
    if (channel != null) 'channel': channel,
    if (repeat != null) 'repeat': repeat!.name,
  };
}

/// Replaces the upcoming entries for [owned] ids with [scheduled], keeping
/// everything already delivered as history. History older than
/// [_historyDays] or beyond [_historyLimit] is dropped.
List<LoggedNotification> mergeNotificationLog(
  List<LoggedNotification> existing, {
  required Set<int> owned,
  required List<LoggedNotification> scheduled,
  required DateTime now,
}) {
  final cutoff = now.subtract(const Duration(days: _historyDays));
  final upcoming = <LoggedNotification>[];
  final delivered = <LoggedNotification>[];
  for (final n in existing) {
    if (n.isUpcoming(now)) {
      if (!owned.contains(n.id)) upcoming.add(n);
    } else if (n.at.isAfter(cutoff)) {
      delivered.add(n);
    }
  }
  for (final n in scheduled) {
    if (n.isUpcoming(now)) {
      upcoming.add(n);
    } else if (n.at.isAfter(cutoff)) {
      // Shown immediately (e.g. a test notification).
      delivered.add(n);
    }
  }
  delivered.sort((a, b) => b.at.compareTo(a.at));
  final seen = <String>{};
  final history = [
    for (final n in delivered)
      if (seen.add('${n.id}@${n.at.millisecondsSinceEpoch}')) n,
  ].take(_historyLimit);
  return [...upcoming, ...history];
}

/// A local record of the notifications the app schedules, so they can be
/// listed in-app. The platform only reports pending notifications without
/// their times, so each reminder service reports what it schedules here.
abstract final class NotificationLog {
  static Future<void> _pending = Future.value();

  /// Delivered notifications newer than the last visit to the list.
  static Future<int> unseenCount() async {
    final seenMs = (await safePrefs())?.getInt(_seenKey) ?? 0;
    final now = clock.now();
    return (await load())
        .where(
          (n) => !n.isUpcoming(now) && n.at.millisecondsSinceEpoch > seenMs,
        )
        .length;
  }

  static Future<void> markSeen() async =>
      (await safePrefs())?.setInt(_seenKey, clock.now().millisecondsSinceEpoch);

  static Future<List<LoggedNotification>> load() async {
    final raw = (await safePrefs())?.getString(_logKey);
    if (raw == null) return const [];
    try {
      return [
        for (final e
            in (jsonDecode(raw) as List).whereType<Map<dynamic, dynamic>>())
          LoggedNotification.fromJson(e.cast<String, dynamic>()),
      ];
    } catch (error) {
      AppLog.warn('Could not read the notification log: $error');
      return const [];
    }
  }

  /// Records that the ids in [owned] now have exactly [scheduled] upcoming.
  /// Calls are serialised so concurrent services don't overwrite each other.
  static Future<void> sync({
    required Iterable<int> owned,
    required List<LoggedNotification> scheduled,
  }) {
    final ownedSet = owned.toSet();
    return _pending = _pending.then((_) async {
      try {
        final prefs = await safePrefs();
        if (prefs == null) return;
        final merged = mergeNotificationLog(
          await load(),
          owned: ownedSet,
          scheduled: scheduled,
          now: clock.now(),
        );
        await prefs.setString(
          _logKey,
          jsonEncode([for (final n in merged) n.toJson()]),
        );
      } catch (error) {
        AppLog.warn('Could not update the notification log: $error');
      }
    });
  }

  /// Forgets delivered notifications; upcoming ones stay.
  static Future<void> clearHistory() {
    return _pending = _pending.then((_) async {
      final prefs = await safePrefs();
      if (prefs == null) return;
      final now = clock.now();
      final kept = (await load()).where((n) => n.isUpcoming(now));
      await prefs.setString(
        _logKey,
        jsonEncode([for (final n in kept) n.toJson()]),
      );
    });
  }
}
