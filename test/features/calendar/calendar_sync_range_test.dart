import 'package:flutter_test/flutter_test.dart';
import 'package:personal/core/period_range.dart';
import 'package:personal/features/calendar/google_calendar_client.dart';
import 'package:personal/features/location/timeline_activity.dart';

void main() {
  test('monthAndNextMonthRange covers month start through next month end', () {
    final range = monthAndNextMonthRange(DateTime(2026, 5, 15));

    expect(range.start, DateTime(2026, 5, 1));
    expect(range.end, DateTime(2026, 6, 30, 23, 59, 59, 999, 999));
  });

  test('calendarSyncRange follows location timeline month plus next month', () {
    final location = LocationSummary(
      activities: [
        TimelineActivity(
          startTime: DateTime(2026, 5, 10, 9),
          endTime: DateTime(2026, 5, 10, 10),
          type: 'WALKING',
          distanceMeters: 1200,
        ),
      ],
    );

    final range = calendarSyncRange(location: location);

    expect(range.start, DateTime(2026, 5, 1));
    expect(range.end, DateTime(2026, 6, 30, 23, 59, 59, 999, 999));
  });

  test('calendarReferenceMonth uses latest activity when current month is empty', () {
    final location = LocationSummary(
      activities: [
        TimelineActivity(
          startTime: DateTime(2026, 3, 18, 9),
          endTime: DateTime(2026, 3, 18, 10),
          type: 'MOTORCYCLING',
          distanceMeters: 5000,
        ),
      ],
    );

    expect(
      location.calendarReferenceMonth(referenceDate: DateTime(2026, 5, 30)),
      DateTime(2026, 3, 1),
    );
  });
}
