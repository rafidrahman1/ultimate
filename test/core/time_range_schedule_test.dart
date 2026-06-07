import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/core/time_range_schedule.dart';

void main() {
  test('formatTimeRange builds readable label', () {
    expect(
      formatTimeRange(const TimeOfDay(hour: 10, minute: 0), const TimeOfDay(hour: 18, minute: 0)),
      '10 AM to 6 PM',
    );
    expect(
      formatTimeRange(const TimeOfDay(hour: 9, minute: 30), const TimeOfDay(hour: 15, minute: 0)),
      '9:30 AM to 3 PM',
    );
  });

  test('parseTimeRangeLabel reads saved work hours', () {
    final range = parseTimeRangeLabel('10 AM to 6 PM');

    expect(range, isNotNull);
    expect(range!.start, const TimeOfDay(hour: 10, minute: 0));
    expect(range.end, const TimeOfDay(hour: 18, minute: 0));
    expect(formatTimeRange(range.start, range.end), '10 AM to 6 PM');
  });
}
