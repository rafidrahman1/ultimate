import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/notifications/notification_log.dart';

LoggedNotification _n(int id, DateTime at, {NotificationRepeat? repeat}) =>
    LoggedNotification(id: id, title: 't$id', body: '', at: at, repeat: repeat);

void main() {
  final now = DateTime(2026, 11, 19, 12);

  test('rescheduling replaces upcoming entries but keeps delivered ones', () {
    final existing = [
      _n(1, now.subtract(const Duration(hours: 3))), // delivered
      _n(1, now.add(const Duration(days: 1))), // old schedule
      _n(50, now.add(const Duration(days: 2))), // another service
    ];
    final merged = mergeNotificationLog(
      existing,
      owned: {1, 2},
      scheduled: [_n(2, now.add(const Duration(hours: 5)))],
      now: now,
    );
    expect(merged.map((n) => (n.id, n.at)).toSet(), {
      (50, now.add(const Duration(days: 2))),
      (2, now.add(const Duration(hours: 5))),
      (1, now.subtract(const Duration(hours: 3))),
    });
  });

  test('old history is pruned and duplicates collapse', () {
    final old = now.subtract(const Duration(days: 40));
    final recent = now.subtract(const Duration(days: 1));
    final merged = mergeNotificationLog(
      [_n(1, old), _n(2, recent), _n(2, recent)],
      owned: const {},
      scheduled: const [],
      now: now,
    );
    expect(merged.map((n) => n.id), [2]);
  });

  test('weekly notifications stay upcoming at their next firing', () {
    final first = DateTime(2026, 11, 1, 18); // a Sunday
    final weekly = _n(9, first, repeat: NotificationRepeat.weekly);
    expect(weekly.isUpcoming(now), isTrue);
    expect(weekly.nextAt(now), DateTime(2026, 11, 22, 18));
  });

  test('json round-trips', () {
    final n = LoggedNotification(
      id: 3,
      title: 'a',
      body: 'b',
      at: now,
      channel: 'check_in',
      repeat: NotificationRepeat.weekly,
    );
    final back = LoggedNotification.fromJson(n.toJson());
    expect(back.toJson(), n.toJson());
  });
}
